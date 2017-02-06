/*
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */
#include <sys/autosnap.h>
#include <sys/dmu_objset.h>
#include <sys/dmu_send.h>
#include <sys/dmu_tx.h>
#include <sys/dsl_dir.h>
#include <sys/dsl_pool.h>
#include <sys/dsl_prop.h>
#include <sys/spa.h>
#include <zfs_fletcher.h>
#include <sys/zap.h>

#include <zfs_sendrecv.h>

#define	STRING_PROP_EL_SIZE 1
#define	UINT64_PROP_EL_SIZE 8

#define	RECV_BUFFER_SIZE (1 << 20)

extern int wbc_check_dataset(const char *name);

int zfs_send_timeout = 5;
uint64_t krrp_debug = 0;

static void dmu_krrp_work_thread(void *arg);
static void dmu_set_send_recv_error(void *krrp_task_void, int err);
static int dmu_krrp_get_buffer(void *krrp_task_void);
static int dmu_krrp_put_buffer(void *krrp_task_void);
static int dmu_krrp_validate_resume_info(nvlist_t *resume_info);

/* An element of snapshots AVL-tree of zfs_ds_collector_entry_t */
typedef struct {
	char name[MAXNAMELEN];
	uint64_t txg;
	uint64_t guid;
	dsl_dataset_t *ds;
	avl_node_t snap_node;
} zfs_snap_avl_node_t;


/*
 * Stream is a sequence of snapshots considered to be related
 * init/fini initialize and deinitialize structures which are
 * persistent for a stream.
 * Here we initialize a work-thread and all required locks.
 * The work-thread is used to execute stream-tasks, that are
 * used to process one ZFS-stream.
 */
void *
dmu_krrp_stream_init()
{
	dmu_krrp_stream_t *stream =
	    kmem_zalloc(sizeof (dmu_krrp_stream_t), KM_SLEEP);

	mutex_init(&stream->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&stream->cv, NULL, CV_DEFAULT, NULL);

	mutex_enter(&stream->mtx);
	stream->work_thread = thread_create(NULL, 32 << 10,
	    dmu_krrp_work_thread, stream, 0, &p0, TS_RUN, minclsyspri);

	while (!stream->running)
		cv_wait(&stream->cv, &stream->mtx);

	mutex_exit(&stream->mtx);

	return (stream);
}

void
dmu_krrp_stream_fini(void *handler)
{
	dmu_krrp_stream_t *stream = handler;

	if (stream == NULL)
		return;

	mutex_enter(&stream->mtx);
	stream->running = B_FALSE;
	cv_broadcast(&stream->cv);
	while (stream->work_thread != NULL)
		cv_wait(&stream->cv, &stream->mtx);

	mutex_exit(&stream->mtx);

	mutex_destroy(&stream->mtx);
	cv_destroy(&stream->cv);
	kmem_free(stream, sizeof (dmu_krrp_stream_t));
}

/*
 * Work-thread executes stream-tasks.
 */
static void
dmu_krrp_work_thread(void *arg)
{
	dmu_krrp_stream_t *stream = arg;
	dmu_krrp_task_t *task;
	void (*task_executor)(void *);

	mutex_enter(&stream->mtx);
	stream->running = B_TRUE;
	cv_broadcast(&stream->cv);

	while (stream->running) {
		if (stream->task == NULL) {
			cv_wait(&stream->cv, &stream->mtx);
			continue;
		}

		ASSERT(stream->task_executor != NULL);

		task = stream->task;
		task_executor = stream->task_executor;
		stream->task = NULL;
		stream->task_executor = NULL;

		mutex_exit(&stream->mtx);

		task_executor(task);

		mutex_enter(&stream->mtx);
	}

	stream->work_thread = NULL;
	cv_broadcast(&stream->cv);
	mutex_exit(&stream->mtx);
	thread_exit();
}

/*
 * Arc bypass is supposed to reduce amount of copying inside memory
 * Here os the main callback for krrp usage of arc bypass
 */
int
dmu_krrp_arc_bypass(void *buf, int len, void *arg)
{
	dmu_krrp_arc_bypass_t *bypass = arg;
	dmu_krrp_task_t *task = bypass->krrp_task;
	kreplication_zfs_args_t *buffer_args = &task->buffer_args;

	if (buffer_args->mem_check_cb != NULL) {
		/*
		 * ARC holds the target buffer while
		 * we read it, so to exclude deadlock need
		 * to be sure that we have enough memory to
		 * completely read the buffer without waiting
		 * for free of required memory space
		 */
		boolean_t zero_copy_ready =
		    buffer_args->mem_check_cb(len,
		    buffer_args->mem_check_cb_arg);
		if (!zero_copy_ready)
			return (ENODATA);
	}

	if (buffer_args->force_cksum)
		fletcher_4_incremental_native(buf, len, bypass->zc);
	DTRACE_PROBE(arc_bypass_send);
	return (bypass->cb(buf, len, task));
}

/*
 * KRRP-SR-INV
 * Functions used in send/recv functions to pass data to the KRRP transport
 */
int
dmu_krrp_buffer_write(void *buf, int len,
    dmu_krrp_task_t *krrp_task)
{
	int count = 0;
	int err = 0;

	while ((!err) && (count < len)) {
		if (krrp_task->buffer_state == SBS_USED) {
			kreplication_buffer_t *buffer = krrp_task->buffer;
			size_t buf_rem = buffer->buffer_size -
			    buffer->data_size;
			size_t rem = len - count;
			size_t size = MIN(rem, buf_rem);

			(void) memcpy((char *)buffer->data + buffer->data_size,
			    (char *)buf + count, size);
			count += size;
			buffer->data_size += size;

			if (buffer->data_size == buffer->buffer_size) {
				krrp_task->buffer = buffer->next;
				if (!krrp_task->buffer) {
					err = dmu_krrp_put_buffer(
					    krrp_task);
				}
			}
		} else {
			err = dmu_krrp_get_buffer(krrp_task);
		}
	}

	return (err);
}

int
dmu_krrp_buffer_read(void *buf, int len,
    dmu_krrp_task_t *krrp_task)
{
	int done = 0;
	int err = 0;

	while (!err && (done < len)) {
		if (krrp_task->buffer_state == SBS_USED) {
			kreplication_buffer_t *buffer = krrp_task->buffer;
			size_t rem = len - done;
			size_t buf_rem = buffer->data_size -
			    krrp_task->buffer_bytes_read;
			size_t size = MIN(rem, buf_rem);

			(void) memcpy((char *)buf + done,
			    (char *)buffer->data +
			    krrp_task->buffer_bytes_read, size);
			krrp_task->buffer_bytes_read += size;
			done += size;
			krrp_task->is_read = B_TRUE;

			if (krrp_task->buffer_bytes_read ==
			    buffer->data_size) {
				krrp_task->buffer = buffer->next;
				krrp_task->buffer_bytes_read = 0;
				if (!krrp_task->buffer) {
					err = dmu_krrp_put_buffer(
					    krrp_task);
				}
			}
		} else {
			err = dmu_krrp_get_buffer(krrp_task);
		}
	}

	return (err);
}

/*
 * KRRP-SEND routines
 */

/*
 * The common function that is called from
 * zfs_send_collect_snap_props and zfs_send_collect_fs_props
 * iterates over the given zap-object and adds zfs props
 * to the resulting nvlist
 */
static int
zfs_send_collect_props(objset_t *mos, uint64_t zapobj, nvlist_t *props)
{
	int err = 0;
	zap_cursor_t zc;
	zap_attribute_t za;

	ASSERT(nvlist_empty(props));

	zap_cursor_init(&zc, mos, zapobj);

	/* walk over properties' zap */
	while (zap_cursor_retrieve(&zc, &za) == 0) {
		uint64_t cnt, el;
		zfs_prop_t prop;
		const char *suffix, *prop_name;
		char buf[ZAP_MAXNAMELEN];

		suffix = strchr(za.za_name, '$');
		prop_name = za.za_name;
		if (suffix != NULL) {
			char *valstr;

			/*
			 * The following logic is similar to
			 * dsl_prop_get_all_impl()
			 * Skip props that have:
			 * - suffix ZPROP_INHERIT_SUFFIX
			 * - all unknown suffixes to be backward compatible
			 */
			if (strcmp(suffix, ZPROP_INHERIT_SUFFIX) == 0 ||
			    strcmp(suffix, ZPROP_RECVD_SUFFIX) != 0) {
				zap_cursor_advance(&zc);
				continue;
			}

			(void) strncpy(buf, za.za_name, (suffix - za.za_name));
			buf[suffix - za.za_name] = '\0';
			prop_name = buf;

			/* Skip if locally overridden. */
			err = zap_contains(mos, zapobj, prop_name);
			if (err == 0) {
				zap_cursor_advance(&zc);
				continue;
			}

			if (err != ENOENT)
				break;

			/* Skip if explicitly inherited. */
			valstr = kmem_asprintf("%s%s", prop_name,
			    ZPROP_INHERIT_SUFFIX);
			err = zap_contains(mos, zapobj, valstr);
			strfree(valstr);
			if (err == 0) {
				zap_cursor_advance(&zc);
				continue;
			}

			if (err != ENOENT)
				break;

			/*
			 * zero out to make sure ENOENT is not returned
			 * if the loop breaks in this iteration
			 */
			err = 0;
		}

		prop = zfs_name_to_prop(prop_name);

		/*
		 * This property make sense only to this dataset,
		 * so no reasons to include it into stream
		 */
		if (prop == ZFS_PROP_WBC_MODE) {
			zap_cursor_advance(&zc);
			continue;
		}

		(void) zap_length(mos, zapobj, za.za_name, &el, &cnt);

		if (el == STRING_PROP_EL_SIZE) {
			char val[ZAP_MAXVALUELEN];

			err = zap_lookup(mos, zapobj, za.za_name,
			    STRING_PROP_EL_SIZE, cnt, val);
			if (err != 0) {
				cmn_err(CE_WARN,
				    "Error while looking up a prop"
				    "zap : %d", err);
				break;
			}

			fnvlist_add_string(props, prop_name, val);
		} else if (el == UINT64_PROP_EL_SIZE) {
			fnvlist_add_uint64(props, prop_name,
			    za.za_first_integer);
		}

		zap_cursor_advance(&zc);
	}

	zap_cursor_fini(&zc);

	return (err);
}

static int
zfs_send_collect_snap_props(dsl_dataset_t *snap_ds, nvlist_t **nvsnaps_props)
{
	int err;
	nvlist_t *props;
	uint64_t zapobj;
	objset_t *mos;

	ASSERT(nvsnaps_props != NULL && *nvsnaps_props == NULL);
	ASSERT(dsl_dataset_long_held(snap_ds));
	ASSERT(snap_ds->ds_is_snapshot);

	props = fnvlist_alloc();
	mos = snap_ds->ds_dir->dd_pool->dp_meta_objset;
	zapobj = dsl_dataset_phys(snap_ds)->ds_props_obj;
	err = zfs_send_collect_props(mos, zapobj, props);
	if (err == 0)
		*nvsnaps_props = props;
	else
		fnvlist_free(props);

	return (err);
}

static int
zfs_send_collect_fs_props(dsl_dataset_t *fs_ds, nvlist_t *nvfs)
{
	int err = 0;
	uint64_t zapobj;
	objset_t *mos;
	nvlist_t *nvfsprops;

	ASSERT(dsl_dataset_long_held(fs_ds));

	nvfsprops = fnvlist_alloc();
	mos = fs_ds->ds_dir->dd_pool->dp_meta_objset;
	zapobj = dsl_dir_phys(fs_ds->ds_dir)->dd_props_zapobj;
	err = zfs_send_collect_props(mos, zapobj, nvfsprops);
	if (err == 0)
		fnvlist_add_nvlist(nvfs, "props", nvfsprops);

	fnvlist_free(nvfsprops);

	return (err);
}

/* AVL compare function for snapshots */
static int
zfs_snapshot_compare(const void *arg1, const void *arg2)
{
	const zfs_snap_avl_node_t *s1 = arg1;
	const zfs_snap_avl_node_t *s2 = arg2;

	if (s1->txg > s2->txg) {
		return (+1);
	} else if (s1->txg < s2->txg) {
		return (-1);
	} else {
		return (0);
	}
}

static zfs_snap_avl_node_t *
zfs_construct_snap_node(dsl_dataset_t *snap_ds, char *full_snap_name)
{
	zfs_snap_avl_node_t *snap_el;

	snap_el = kmem_zalloc(sizeof (zfs_snap_avl_node_t), KM_SLEEP);

	(void) strlcpy(snap_el->name, full_snap_name,
	    sizeof (snap_el->name));
	snap_el->guid = dsl_dataset_phys(snap_ds)->ds_guid;
	snap_el->txg = dsl_dataset_phys(snap_ds)->ds_creation_txg;
	snap_el->ds = snap_ds;

	return (snap_el);
}

/*
 * Collects all snapshots (txg_first < Creation TXG < txg_last)
 * for the given FS and adds them to the resulting AVL-tree
 */
static int
zfs_send_collect_interim_snaps(zfs_ds_collector_entry_t *fs_el,
    uint64_t txg_first, uint64_t txg_last, void *owner)
{
	int err;
	uint64_t ds_creation_txg;
	avl_tree_t *snapshots = &fs_el->snapshots;
	zfs_snap_avl_node_t *snap_el;
	char full_snap_name[MAXNAMELEN];
	char *snap_name;
	objset_t *os = NULL;
	dsl_dataset_t *snap_ds = NULL;
	dsl_dataset_t *ds = fs_el->ds;
	dsl_pool_t *dp = ds->ds_dir->dd_pool;
	uint64_t offp = 0, obj = 0;

	dsl_pool_config_enter(dp, FTAG);

	err = dmu_objset_from_ds(ds, &os);
	if (err != 0) {
		dsl_pool_config_exit(dp, FTAG);
		return (err);
	}

	(void) snprintf(full_snap_name, sizeof (full_snap_name),
	    "%s@", fs_el->name);
	snap_name = strchr(full_snap_name, '@') + 1;

	/* walk over snapshots and add them to the tree to sort */
	for (;;) {
		snap_ds = NULL;
		snap_name[0] = '\0';
		err = dmu_snapshot_list_next(os,
		    MAXNAMELEN - strlen(full_snap_name),
		    full_snap_name + strlen(full_snap_name),
		    &obj, &offp, NULL);
		if (err != 0) {
			if (err == ENOENT) {
				/*
				 * ENOENT in this case means no more
				 * snapshots, that is not an error
				 */
				err = 0;
			}

			break;
		}

		/* We do not want intermediate autosnapshots */
		if (autosnap_check_name(snap_name))
			continue;

		err = dsl_dataset_hold(dp, full_snap_name, owner, &snap_ds);
		if (err != 0) {
			ASSERT(err != ENOENT);
			break;
		}

		ds_creation_txg =
		    dsl_dataset_phys(snap_ds)->ds_creation_txg;

		/*
		 * We want only snapshots that are inside of
		 * our boundaries
		 * boundary snap_el already added to avl
		 */
		if (ds_creation_txg <= txg_first ||
		    ds_creation_txg >= txg_last) {
			dsl_dataset_rele(snap_ds, owner);
			continue;
		}

		snap_el = zfs_construct_snap_node(snap_ds,
		    full_snap_name);
		dsl_dataset_long_hold(snap_ds, owner);
		avl_add(snapshots, snap_el);
	}

	dsl_pool_config_exit(dp, FTAG);

	return (err);
}

/*
 * Collect snapshots of a given dataset in a given range
 * Collects interim snapshots if incl_interim_snaps == B_TRUE
 */
static int
zfs_send_collect_snaps(zfs_ds_collector_entry_t *fs_el,
    char *from_snap, char *to_snap, boolean_t incl_interim_snaps,
    void *owner)
{
	int err = 0;
	dsl_dataset_t *snap_ds = NULL;
	dsl_dataset_t *fs_ds = fs_el->ds;
	dsl_pool_t *dp = fs_ds->ds_dir->dd_pool;
	uint64_t txg_first = 0, txg_last = UINT64_MAX;
	char full_snap_name[MAXNAMELEN];
	char *snap_name;

	zfs_snap_avl_node_t *from_snap_el = NULL;
	zfs_snap_avl_node_t *to_snap_el = NULL;

	dsl_pool_config_enter(dp, FTAG);

	/* the right boundary snapshot should be exist */
	if (to_snap == NULL || to_snap[0] == '\0') {
		dsl_pool_config_exit(dp, FTAG);
		return (SET_ERROR(EINVAL));
	}

	/*
	 * Snapshots must be sorted in the ascending order by birth_txg
	 */
	avl_create(&fs_el->snapshots, zfs_snapshot_compare,
	    sizeof (zfs_snap_avl_node_t),
	    offsetof(zfs_snap_avl_node_t, snap_node));

	(void) snprintf(full_snap_name, sizeof (full_snap_name),
	    "%s@", fs_el->name);
	snap_name = strchr(full_snap_name, '@') + 1;

	snap_name[0] = '\0';
	(void) strcat(full_snap_name, to_snap);
	err = dsl_dataset_hold(dp, full_snap_name, owner, &snap_ds);
	if (err != 0) {
		dsl_pool_config_exit(dp, FTAG);

		/* This FS was created after 'to_snap' */
		if (err == ENOENT)
			err = 0;

		return (err);
	}

	to_snap_el = zfs_construct_snap_node(snap_ds,
	    full_snap_name);
	txg_last = dsl_dataset_phys(snap_ds)->ds_creation_txg;
	dsl_dataset_long_hold(to_snap_el->ds, owner);
	avl_add(&fs_el->snapshots, to_snap_el);

	/* check left boundary */
	if (from_snap != NULL && from_snap[0] != '\0') {
		snap_ds = NULL;
		snap_name[0] = '\0';
		(void) strcat(full_snap_name, from_snap);
		err = dsl_dataset_hold(dp, full_snap_name,
		    owner, &snap_ds);

		if (err == 0) {
			txg_first =
			    dsl_dataset_phys(snap_ds)->ds_creation_txg;
			from_snap_el =
			    zfs_construct_snap_node(snap_ds, full_snap_name);
			dsl_dataset_long_hold(from_snap_el->ds, owner);
			avl_add(&fs_el->snapshots, from_snap_el);
		} else {
			/*
			 * it is possible that from_snap does not exist
			 * for a child FS, because the FS was created
			 * after from_snap
			 */
			if (err == ENOENT && !fs_el->top_level_ds) {
				err = 0;
			} else {
				dsl_pool_config_exit(dp, FTAG);
				return (err);
			}
		}
	}

	/*
	 * 'FROM' snapshot cannot be created before 'TO' snapshot
	 * and
	 * 'FROM' and 'TO' snapshots cannot be the same snapshot
	 */
	if (txg_last <= txg_first) {
		dsl_pool_config_exit(dp, FTAG);
		return (SET_ERROR(EXDEV));
	}

	dsl_pool_config_exit(dp, FTAG);

	/*
	 * If 'incl_interim_snaps' flag isn't presented,
	 * only 'from' and 'to' snapshots should be in list
	 */
	if (!incl_interim_snaps)
		return (0);

	err = zfs_send_collect_interim_snaps(fs_el,
	    txg_first, txg_last, owner);

	return (err);
}

/* Collect datasets and snapshots of each dataset */
static int
zfs_send_collect_ds(char *from_ds, char *from_snap, char *to_snap,
    boolean_t incl_interim_snaps, boolean_t recursive,
    list_t *ds_to_send, void *owner)
{
	int err = 0;
	zfs_ds_collector_entry_t *fs_el;
	spa_t *spa;
	dsl_pool_t *dp;

	mutex_enter(&spa_namespace_lock);
	spa = spa_lookup(from_ds);
	mutex_exit(&spa_namespace_lock);

	if (spa == NULL)
		return (SET_ERROR(ENOENT));

	dp = spa_get_dsl(spa);

	dsl_pool_config_enter(dp, FTAG);
	while ((err = zfs_collect_ds(spa, from_ds,
	    recursive, B_TRUE, ds_to_send)) == EBUSY)
		delay(NSEC_TO_TICK(100));
	dsl_pool_config_exit(dp, FTAG);

	fs_el = list_head(ds_to_send);
	while (err == 0 && fs_el != NULL) {
		err = zfs_send_collect_snaps(fs_el, from_snap,
		    to_snap, incl_interim_snaps, owner);
		fs_el = list_next(ds_to_send, fs_el);
	}

	return (err);
}

/* Send a single dataset, mostly mimic regular send */
static int
zfs_send_one_ds(dmu_krrp_task_t *krrp_task, zfs_snap_avl_node_t *snap_el,
    zfs_snap_avl_node_t *snap_el_prev)
{
	int err = 0;
	offset_t off = 0;
	dsl_pool_t *dp = NULL;
	dsl_dataset_t *snap_ds = NULL;
	dsl_dataset_t *snap_ds_prev = NULL;
	boolean_t embedok = krrp_task->buffer_args.embedok;
	nvlist_t *resume_info = krrp_task->buffer_args.resume_info;
	uint64_t resumeobj = 0, resumeoff = 0;

	/*
	 * 'ds' of snap_ds/snap_ds_prev alredy long-held
	 * so we do not need to hold them again
	 */

	snap_ds = snap_el->ds;
	if (snap_el_prev != NULL)
		snap_ds_prev = snap_el_prev->ds;

	/*
	 * dsl_pool_config_enter() cannot be used here because
	 * dmu_send_impl() calls dsl_pool_rele()
	 *
	 * VERIFY0() is used because dsl_pool_hold() opens spa,
	 * that already is opened in our case.
	 */
	VERIFY0(dsl_pool_hold(snap_el->name, FTAG, &dp));

	if (resume_info != NULL) {
		err = nvlist_lookup_uint64(resume_info, "object", &resumeobj);
		ASSERT3U(err, !=, ENOENT);
		if (err != 0) {
			dsl_pool_rele(dp, FTAG);
			return (SET_ERROR(err));
		}

		err = nvlist_lookup_uint64(resume_info, "offset", &resumeoff);
		ASSERT3U(err, !=, ENOENT);
		if (err != 0) {
			dsl_pool_rele(dp, FTAG);
			return (SET_ERROR(err));
		}
	}

	if (krrp_debug) {
		cmn_err(CE_NOTE, "KRRP SEND INC_BASE: %s -- DS: "
		    "%s -- GUID: %llu",
		    snap_el_prev == NULL ? "<none>" : snap_el_prev->name,
		    snap_el->name,
		    (unsigned long long)dsl_dataset_phys(snap_ds)->ds_guid);
	}

	if (snap_ds_prev != NULL) {
		zfs_bookmark_phys_t zb;
		boolean_t is_clone;

		if (!dsl_dataset_is_before(snap_ds, snap_ds_prev, 0)) {
			dsl_pool_rele(dp, FTAG);
			return (SET_ERROR(EXDEV));
		}

		zb.zbm_creation_time =
		    dsl_dataset_phys(snap_ds_prev)->ds_creation_time;
		zb.zbm_creation_txg =
		    dsl_dataset_phys(snap_ds_prev)->ds_creation_txg;
		zb.zbm_guid = dsl_dataset_phys(snap_ds_prev)->ds_guid;
		is_clone = (snap_ds_prev->ds_dir != snap_ds->ds_dir);

		err = dmu_send_impl(FTAG, dp, snap_ds, &zb, is_clone,
		    embedok, B_FALSE, -1, resumeobj, resumeoff, NULL,
		    &off, krrp_task);
	} else {
		err = dmu_send_impl(FTAG, dp, snap_ds, NULL, B_FALSE,
		    embedok, B_FALSE, -1, resumeobj, resumeoff, NULL,
		    &off, krrp_task);
	}

	/*
	 * dsl_pool_rele() is not required here
	 * because dmu_send_impl() already did it
	 */

	return (err);
}

/*
 * Here we iterate over all collected FSs and
 * their SNAPs to collect props
 */
static int
zfs_prepare_compound_data(list_t *fs_list, nvlist_t **fss)
{
	zfs_ds_collector_entry_t *fs_el;
	int err = 0;
	nvlist_t *nvfss;
	uint64_t guid;
	char sguid[64];

	nvfss = fnvlist_alloc();

	/* Traverse the list of datasetss */
	fs_el = list_head(fs_list);
	while (fs_el != NULL) {
		zfs_snap_avl_node_t *snap_el;
		nvlist_t *nvfs, *nvsnaps, *nvsnaps_props;

		nvfs = fnvlist_alloc();
		fnvlist_add_string(nvfs, "name", fs_el->name);

		err = zfs_send_collect_fs_props(fs_el->ds, nvfs);
		if (err != 0) {
			fnvlist_free(nvfs);
			break;
		}

		nvsnaps = fnvlist_alloc();
		nvsnaps_props = fnvlist_alloc();

		snap_el = avl_first(&fs_el->snapshots);
		while (snap_el != NULL) {
			nvlist_t *nvsnap_props = NULL;
			char *snapname;

			snapname = strrchr(snap_el->name, '@') + 1;
			fnvlist_add_uint64(nvsnaps, snapname, snap_el->guid);

			err = zfs_send_collect_snap_props(snap_el->ds,
			    &nvsnap_props);
			if (err != 0)
				break;

			fnvlist_add_nvlist(nvsnaps_props,
			    snapname, nvsnap_props);

			snap_el = AVL_NEXT(&fs_el->snapshots, snap_el);
		}

		if (err == 0) {
			fnvlist_add_nvlist(nvfs, "snaps", nvsnaps);
			fnvlist_add_nvlist(nvfs, "snapprops",
			    nvsnaps_props);

			guid = dsl_dataset_phys(fs_el->ds)->ds_guid;
			(void) sprintf(sguid, "0x%llx",
			    (unsigned long long)guid);
			fnvlist_add_nvlist(nvfss, sguid, nvfs);
		}

		fnvlist_free(nvsnaps);
		fnvlist_free(nvsnaps_props);
		fnvlist_free(nvfs);

		if (err != 0)
			break;

		fs_el = list_next(fs_list, fs_el);
	}

	if (err != 0)
		fnvlist_free(nvfss);
	else
		*fss = nvfss;

	return (err);
}

static void
zfs_prepare_compound_hdr(dmu_krrp_task_t *krrp_task, nvlist_t **hdrnvl)
{
	nvlist_t *nvl;

	nvl = fnvlist_alloc();

	if (krrp_task->buffer_args.from_incr_base[0] != '\0') {
		fnvlist_add_string(nvl, "fromsnap",
		    krrp_task->buffer_args.from_incr_base);
	}

	fnvlist_add_string(nvl, "tosnap", krrp_task->buffer_args.from_snap);

	if (!krrp_task->buffer_args.recursive)
		fnvlist_add_boolean(nvl, "not_recursive");

	*hdrnvl = nvl;
}

static int
zfs_send_compound_stream_header(dmu_krrp_task_t *krrp_task, list_t *ds_to_send)
{
	int err;
	nvlist_t *fss = NULL;
	nvlist_t *hdrnvl = NULL;
	dmu_replay_record_t drr;
	zio_cksum_t zc = { 0 };
	char *packbuf = NULL;
	size_t buflen = 0;

	zfs_prepare_compound_hdr(krrp_task, &hdrnvl);

	err = zfs_prepare_compound_data(ds_to_send, &fss);
	if (err != 0)
		return (err);

	fnvlist_add_nvlist(hdrnvl, "fss", fss);
	fnvlist_free(fss);

	VERIFY0(nvlist_pack(hdrnvl, &packbuf, &buflen,
	    NV_ENCODE_XDR, KM_SLEEP));
	fnvlist_free(hdrnvl);

	bzero(&drr, sizeof (drr));
	drr.drr_type = DRR_BEGIN;
	drr.drr_u.drr_begin.drr_magic = DMU_BACKUP_MAGIC;
	DMU_SET_STREAM_HDRTYPE(drr.drr_u.drr_begin.drr_versioninfo,
	    DMU_COMPOUNDSTREAM);
	(void) snprintf(drr.drr_u.drr_begin.drr_toname,
	    sizeof (drr.drr_u.drr_begin.drr_toname),
	    "%s@%s", krrp_task->buffer_args.from_ds,
	    krrp_task->buffer_args.from_snap);
	drr.drr_payloadlen = buflen;
	if (krrp_task->buffer_args.force_cksum)
		fletcher_4_incremental_native(&drr, sizeof (drr), &zc);

	err = dmu_krrp_buffer_write(&drr, sizeof (drr), krrp_task);
	if (err != 0)
		goto out;

	if (buflen != 0) {
		if (krrp_task->buffer_args.force_cksum)
			fletcher_4_incremental_native(packbuf, buflen, &zc);

		err = dmu_krrp_buffer_write(packbuf, buflen, krrp_task);
		if (err != 0)
			goto out;
	}

	bzero(&drr, sizeof (drr));
	drr.drr_type = DRR_END;
	drr.drr_u.drr_end.drr_checksum = zc;

	err = dmu_krrp_buffer_write(&drr, sizeof (drr), krrp_task);

out:
	if (packbuf != NULL)
		kmem_free(packbuf, buflen);

	return (err);
}

/*
 * For every dataset there is a chain of snapshots. It may start with
 * an empty record, which means it is a non-incremental snap, after
 * that this dataset is considered to be under an incremental stream.
 * In an incremental stream, first snapshot for every dataset is
 * an incremental base. After sending, currently sent snapshot
 * becomes a base for the next one unless the next belongs to
 * another dataset or is an empty record.
 */
static int
zfs_send_snapshots(dmu_krrp_task_t *krrp_task, avl_tree_t *snapshots,
    char *resume_snap_name)
{
	int err = 0;
	char *incr_base = krrp_task->buffer_args.from_incr_base;
	zfs_snap_avl_node_t *snap_el, *snap_el_prev = NULL;

	snap_el = avl_first(snapshots);

	/*
	 * It is possible that a new FS does not yet have snapshots,
	 * because the FS was created after the right border snapshot
	 */
	if (snap_el == NULL)
		return (0);

	/*
	 * For an incemental stream need to skip
	 * the incremental base snapshot
	 */
	if (incr_base[0] != '\0') {
		char *short_snap_name = strrchr(snap_el->name, '@') + 1;
		if (strcmp(incr_base, short_snap_name) == 0) {
			snap_el_prev = snap_el;
			snap_el = AVL_NEXT(snapshots, snap_el);
		}
	}

	if (resume_snap_name != NULL) {
		while (snap_el != NULL) {
			if (strcmp(snap_el->name, resume_snap_name) == 0)
				break;

			snap_el_prev = snap_el;
			snap_el = AVL_NEXT(snapshots, snap_el);
		}
	}

	while (snap_el != NULL) {
		err = zfs_send_one_ds(krrp_task, snap_el, snap_el_prev);
		if (err != 0)
			break;

		/*
		 * We have sent resumed snap,
		 * so resume_info is not relevant anymore
		 */
		if (krrp_task->buffer_args.resume_info != NULL) {
			fnvlist_free(krrp_task->buffer_args.resume_info);
			krrp_task->buffer_args.resume_info = NULL;
		}

		snap_el_prev = snap_el;
		snap_el = AVL_NEXT(snapshots, snap_el);
	}

	return (err);
}

static int
dmu_krrp_send_resume(char *resume_token, list_t *ds_to_send,
    char **resume_fs_name, char **resume_snap_name)
{
	zfs_ds_collector_entry_t *fs_el;
	zfs_snap_avl_node_t *snap_el;
	char *at_ptr;

	at_ptr = strrchr(resume_token, '@');
	if (at_ptr == NULL) {
		cmn_err(CE_WARN, "Invalid resume_token [%s]", resume_token);
		return (SET_ERROR(ENOSR));
	}

	*at_ptr = '\0';

	/* First need to find FS that matches the given cookie */
	fs_el = list_head(ds_to_send);
	while (fs_el != NULL) {
		if (strcmp(fs_el->name, resume_token) == 0)
			break;

		fs_el = list_next(ds_to_send, fs_el);
	}

	/* There is no target FS */
	if (fs_el == NULL) {
		cmn_err(CE_WARN, "Unknown FS name [%s]", resume_token);
		return (SET_ERROR(ENOSR));
	}

	*at_ptr = '@';

	/*
	 * FS has been found, need to find SNAP that
	 * matches the given cookie
	 */
	snap_el = avl_first(&fs_el->snapshots);
	while (snap_el != NULL) {
		if (strcmp(snap_el->name, resume_token) == 0)
			break;

		snap_el = AVL_NEXT(&fs_el->snapshots, snap_el);
	}

	/* There is no target snapshot */
	if (snap_el == NULL) {
		cmn_err(CE_WARN, "Unknown SNAP name [%s]", resume_token);
		return (SET_ERROR(ENOSR));
	}

	*resume_snap_name = snap_el->name;
	*resume_fs_name = fs_el->name;

	return (0);
}

static int
zfs_send_ds(dmu_krrp_task_t *krrp_task, list_t *ds_to_send)
{
	int err = 0;
	zfs_ds_collector_entry_t *fs_el;
	char *resume_fs_name = NULL;
	char *resume_snap_name = NULL;

	fs_el = list_head(ds_to_send);

	/* Resume logic */
	if (krrp_task->buffer_args.resume_info != NULL) {
		char *toname = NULL;

		err = nvlist_lookup_string(krrp_task->buffer_args.resume_info,
		    "toname", &toname);
		ASSERT(err != ENOENT);
		if (err != 0)
			return (SET_ERROR(err));

		err = dmu_krrp_send_resume(toname, ds_to_send,
		    &resume_fs_name, &resume_snap_name);
		if (err != 0)
			return (err);

		while (fs_el != NULL) {
			if (strcmp(fs_el->name, resume_fs_name) == 0)
				break;

			fs_el = list_next(ds_to_send, fs_el);
		}
	}

	while (fs_el != NULL) {
		err = zfs_send_snapshots(krrp_task,
		    &fs_el->snapshots, resume_snap_name);
		if (err != 0)
			break;

		/*
		 * resume_snap_name needs to be NULL for the datasets,
		 * that are on the "right" side of the resume-token,
		 * because need to process all their snapshots
		 */
		if (resume_snap_name != NULL)
			resume_snap_name = NULL;

		fs_el = list_next(ds_to_send, fs_el);
	}

	return (err);
}

static void
zfs_cleanup_send_list(list_t *ds_to_send, void *owner)
{
	zfs_ds_collector_entry_t *fs_el;

	/* Walk over all collected FSs and their SNAPs to cleanup */
	while ((fs_el = list_head(ds_to_send)) != NULL) {
		zfs_snap_avl_node_t *snap_el;

		while ((snap_el = avl_first(&fs_el->snapshots)) != NULL) {
			avl_remove(&fs_el->snapshots, snap_el);
			dsl_dataset_long_rele(snap_el->ds, owner);
			dsl_dataset_rele(snap_el->ds, owner);
			kmem_free(snap_el, sizeof (zfs_snap_avl_node_t));
		}

		dsl_dataset_long_rele(fs_el->ds, NULL);
		dsl_dataset_rele(fs_el->ds, NULL);

		(void) list_remove_head(ds_to_send);
		dsl_dataset_collector_cache_free(fs_el);
	}
}

/*
 * zfs_send_thread
 * executes ONE iteration, initial or incremental, on the sender side
 * 1) validates versus WBC
 * 2) collects source datasets and its to-be-sent snapshots
 *    2.1) each source dataset is an element of list, that contains
 *    - name of dataset
 *    - avl-tree of snapshots
 *    - its guid
 *    - the corresponding long held dsl_datasets_t
 *    2.2) each snapshot is an element of avl-tree, that contains
 *    - name of snapshot
 *    - its guid
 *    - creation TXG
 *    - the corresponding long held dsl_datasets_t
 * 3) initiate send stream
 * 4) send in order, one snapshot at a time
 */
static void
zfs_send_thread(void *krrp_task_void)
{
	dmu_replay_record_t drr = { 0 };
	dmu_krrp_task_t *krrp_task = krrp_task_void;
	kreplication_zfs_args_t *buffer_args = &krrp_task->buffer_args;
	list_t ds_to_send;
	int err = 0;
	spa_t *spa;
	void *owner = krrp_task;

	ASSERT(krrp_task != NULL);

	list_create(&ds_to_send, sizeof (zfs_ds_collector_entry_t),
	    offsetof(zfs_ds_collector_entry_t, node));

	mutex_enter(&spa_namespace_lock);
	spa = spa_lookup(krrp_task->buffer_args.from_ds);
	mutex_exit(&spa_namespace_lock);

	if (spa == NULL) {
		err = SET_ERROR(ENOENT);
		goto final;
	}

	if (buffer_args->resume_info != NULL) {
		err = dmu_krrp_validate_resume_info(buffer_args->resume_info);
		if (err != 0)
			goto final;
	}

	/*
	 * Source cannot be a writecached child if
	 * the from_snapshot is an autosnap
	 */
	err = wbc_check_dataset(buffer_args->from_ds);
	if (err != 0 && err != ENOTACTIVE) {
		boolean_t from_snap_is_autosnap =
		    autosnap_check_name(buffer_args->from_snap);
		if (err != EOPNOTSUPP || from_snap_is_autosnap) {
			if (err == EOPNOTSUPP)
				err = SET_ERROR(ENOTDIR);

			goto final;
		}
	}

	err = autosnap_lock(spa, RW_READER);
	if (err != 0)
		goto final;

	err = zfs_send_collect_ds(buffer_args->from_ds,
	    buffer_args->from_incr_base, buffer_args->from_snap,
	    buffer_args->do_all, buffer_args->recursive,
	    &ds_to_send, owner);

	autosnap_unlock(spa);

	if (err != 0)
		goto final;

	/*
	 * Recursive stream, stream with properties, or complete-incremental
	 * stream have special header (DMU_COMPOUNDSTREAM)
	 */
	if (buffer_args->recursive || buffer_args->properties ||
	    buffer_args->do_all) {
		err = zfs_send_compound_stream_header(krrp_task, &ds_to_send);
		if (err != 0)
			goto final;
	}

	err = zfs_send_ds(krrp_task, &ds_to_send);

final:

	zfs_cleanup_send_list(&ds_to_send, owner);

	list_destroy(&ds_to_send);

	if (err == 0 && (buffer_args->recursive ||
	    buffer_args->properties || buffer_args->do_all)) {
		bzero(&drr, sizeof (drr));
		drr.drr_type = DRR_END;
		err = dmu_krrp_buffer_write(&drr, sizeof (drr), krrp_task);
	}

	if (err == 0)
		err = dmu_krrp_put_buffer(krrp_task);

	if (err != 0) {
		dmu_set_send_recv_error(krrp_task, err);
		cmn_err(CE_WARN, "Send thread exited with error code %d", err);
	}

	(void) dmu_krrp_fini_task(krrp_task);
}

/* KRRP-RECV routines */

/*
 * Alternate props from the received steam
 * Walk over all props from incoming nvlist "props" and
 * - replace each that is contained in nvlist "replace"
 * - remove each that is contained in nvlist "exclude"
 */
static void
zfs_recv_alter_props(nvlist_t *props, nvlist_t *exclude, nvlist_t *replace)
{
	nvpair_t *element = NULL;

	if (props != NULL && exclude != NULL) {
		while (
		    (element = nvlist_next_nvpair(exclude, element)) != NULL) {
			nvpair_t *pair;
			char *prop = nvpair_name(element);
			char *prop_recv;
			char *prop_inher;

			prop_recv =
			    kmem_asprintf("%s%s", prop, ZPROP_RECVD_SUFFIX);
			prop_inher =
			    kmem_asprintf("%s%s", prop, ZPROP_INHERIT_SUFFIX);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop_recv, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop_inher, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			strfree(prop_recv);
			strfree(prop_inher);
		}
	}

	if (props != NULL && replace != NULL) {
		while (
		    (element = nvlist_next_nvpair(replace, element)) != NULL) {
			nvpair_t *pair;
			char *prop = nvpair_name(element);
			char *prop_recv;
			char *prop_inher;

			prop_recv =
			    kmem_asprintf("%s%s", prop, ZPROP_RECVD_SUFFIX);
			prop_inher =
			    kmem_asprintf("%s%s", prop, ZPROP_INHERIT_SUFFIX);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop_recv, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			pair = NULL;
			(void) nvlist_lookup_nvpair(props, prop_inher, &pair);
			if (pair)
				fnvlist_remove_nvpair(props, pair);

			strfree(prop_recv);
			strfree(prop_inher);

			fnvlist_add_nvpair(props, element);
		}
	}
}

/* Recv a single snapshot. It is a simplified version of recv */
static int
zfs_recv_one_ds(char *ds, dmu_replay_record_t *drr, nvlist_t *fs_props,
    nvlist_t *snap_props, dmu_krrp_task_t *krrp_task)
{
	int err = 0;
	uint64_t errf = 0;
	uint64_t ahdl = 0;
	uint64_t sz = 0;
	char *tosnap;

	if (krrp_task->buffer_args.to_snap[0]) {
		tosnap = krrp_task->buffer_args.to_snap;
	} else {
		tosnap = strchr(drr->drr_u.drr_begin.drr_toname, '@') + 1;
	}

	zfs_recv_alter_props(fs_props,
	    krrp_task->buffer_args.ignore_list,
	    krrp_task->buffer_args.replace_list);

	if (krrp_debug) {
		cmn_err(CE_NOTE, "KRRP RECV INC_BASE: "
		    "%llu -- DS: %s -- TO_SNAP:%s",
		    (unsigned long long)drr->drr_u.drr_begin.drr_fromguid,
		    ds, tosnap);
	}

	/* hack to avoid adding the symnol to the libzpool export list */
#ifdef _KERNEL
	err = dmu_recv_impl(NULL, ds, tosnap, NULL, drr, B_TRUE, fs_props,
	    NULL, &errf, -1, &ahdl, &sz, krrp_task->buffer_args.force,
	    krrp_task);

	/*
	 * If receive has been successfully finished
	 * we can apply received snapshot properties
	 */
	if (err == 0 && snap_props != NULL) {
		char *full_snap_name;

		full_snap_name = kmem_asprintf("%s@%s", ds, tosnap);
		err = zfs_ioc_set_prop_impl(full_snap_name,
		    snap_props, B_TRUE, NULL);
		if (err != 0 && krrp_debug) {
			cmn_err(CE_NOTE, "KRRP RECV: failed to apply "
			    "received snapshot properties [%d]", err);
		}

		strfree(full_snap_name);
	}
#endif

	return (err);
}

/*
 * Recv one stream
 * 1) validates versus WBC
 * 2) prepares receiving paths according to the given
 * flags ('leave_tail' or 'strip_head')
 * 3) recv stream
 * 4) apply snapshot properties if they
 * are part of received stream
 * 5) To support resume-recv save to ZAP the name
 * of complettly received snapshot. After merge with illumos
 * the resume-logic need to be replaced by the more intelegent
 * logic from illumos
 *
 * The implemented "recv" supports most of userspace-recv
 * functionality.
 *
 * Large-Blocks is not supported
 */
static void
zfs_recv_thread(void *krrp_task_void)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;
	dmu_replay_record_t drr = { 0 };
	struct drr_begin *drrb = &drr.drr_u.drr_begin;
	zio_cksum_t zcksum = { 0 };
	int err;
	int baselen;
	spa_t *spa;
	char latest_snap[MAXNAMELEN] = { 0 };
	char to_ds[MAXNAMELEN];

	ASSERT(krrp_task != NULL);

	mutex_enter(&spa_namespace_lock);
	spa = spa_lookup(krrp_task->buffer_args.to_ds);
	mutex_exit(&spa_namespace_lock);

	if (spa == NULL) {
		err = SET_ERROR(ENOENT);
		goto out;
	}

	/*
	 * This option requires a functionality (similar to
	 * create_parents() from libzfs_dataset.c), that is not
	 * implemented yet
	 */
	if (krrp_task->buffer_args.strip_head) {
		err = SET_ERROR(ENOTSUP);
		goto out;
	}

	(void) strlcpy(to_ds, krrp_task->buffer_args.to_ds, sizeof (to_ds));
	if (dsl_dataset_creation_txg(to_ds) == UINT64_MAX) {
		char *p;

		/*
		 * If 'leave_tail' or 'strip_head' are define,
		 * then 'to_ds' just a prefix and must exist
		 */
		if (krrp_task->buffer_args.leave_tail ||
		    krrp_task->buffer_args.strip_head) {
			err = SET_ERROR(ENOENT);
			goto out;
		}

		/*
		 * spa found, '/' must be, becase the above
		 * check returns UINT64_MAX
		 */
		VERIFY((p = strrchr(to_ds, '/')) != NULL);
		*p = '\0';

		/*
		 * It is OK that destination does not exist,
		 * but its parent must be here
		 */
		if (dsl_dataset_creation_txg(to_ds) == UINT64_MAX) {
			err = SET_ERROR(ENOENT);
			goto out;
		}
	}

	/* destination cannot be writecached */
	err = wbc_check_dataset(to_ds);
	if (err == 0 || err == EOPNOTSUPP) {
		err = SET_ERROR(ENOTDIR);
		goto out;
	}

	/*
	 * ENOTACTIVE means WBC is not active for the DS
	 * If some another error just return
	 */
	if (err != ENOTACTIVE)
		goto out;

	/* Read leading block */
	err = dmu_krrp_buffer_read(&drr, sizeof (drr), krrp_task);
	if (err != 0)
		goto out;

	if (drr.drr_type != DRR_BEGIN ||
	    (drrb->drr_magic != DMU_BACKUP_MAGIC &&
	    drrb->drr_magic != BSWAP_64(DMU_BACKUP_MAGIC))) {
		err = SET_ERROR(EBADMSG);
		goto out;
	}

	baselen = strchr(drrb->drr_toname, '@') - drrb->drr_toname;

	/* Process passed arguments */
	if (krrp_task->buffer_args.strip_head) {
		char *pos = strchr(drrb->drr_toname, '/');
		if (pos)
			baselen = pos - drrb->drr_toname;
	}

	if (krrp_task->buffer_args.leave_tail) {
		char *pos = strrchr(drrb->drr_toname, '/');
		if (pos)
			baselen = pos - drrb->drr_toname;
	}

	if (DMU_GET_STREAM_HDRTYPE(drrb->drr_versioninfo) == DMU_SUBSTREAM) {
		/* recv a simple single snapshot */
		char full_ds[MAXNAMELEN];

		(void) strlcpy(full_ds, krrp_task->buffer_args.to_ds,
		    sizeof (full_ds));
		if (krrp_task->buffer_args.strip_head ||
		    krrp_task->buffer_args.leave_tail) {
			char *pos;
			int len = strlen(full_ds) +
			    strlen(drrb->drr_toname + baselen) + 1;
			if (len < MAXNAMELEN) {
				(void) strlcat(full_ds, "/", sizeof (full_ds));
				(void) strlcat(full_ds,
				    drrb->drr_toname + baselen,
				    sizeof (full_ds));
				pos = strchr(full_ds, '@');
				*pos = '\0';
			} else {
				err = SET_ERROR(ENAMETOOLONG);
				goto out;
			}
		}

		(void) snprintf(latest_snap, sizeof (latest_snap),
		    "%s%s", full_ds, strchr(drrb->drr_toname, '@'));
		err = zfs_recv_one_ds(full_ds, &drr, NULL, NULL, krrp_task);
	} else {
		nvlist_t *nvl = NULL, *nvfs = NULL;
		avl_tree_t *fsavl = NULL;

		if (krrp_task->buffer_args.force_cksum) {
			fletcher_4_incremental_native(&drr,
			    sizeof (drr), &zcksum);
		}

		/* Recv COMPOUND PAYLOAD */
		if (drr.drr_payloadlen > 0) {
			char *buf = kmem_alloc(drr.drr_payloadlen, KM_SLEEP);
			err = dmu_krrp_buffer_read(
			    buf, drr.drr_payloadlen, krrp_task);
			if (err != 0) {
				kmem_free(buf, drr.drr_payloadlen);
				goto out;
			}

			if (krrp_task->buffer_args.force_cksum) {
				fletcher_4_incremental_native(buf,
				    drr.drr_payloadlen, &zcksum);
			}

			err = nvlist_unpack(buf, drr.drr_payloadlen,
			    &nvl, KM_SLEEP);
			kmem_free(buf, drr.drr_payloadlen);

			if (err != 0) {
				err = SET_ERROR(EBADMSG);
				goto out;
			}

			err = nvlist_lookup_nvlist(nvl, "fss", &nvfs);
			if (err != 0) {
				err = SET_ERROR(EBADMSG);
				goto out_nvl;
			}

			err = fsavl_create(nvfs, &fsavl);
			if (err != 0) {
				err = SET_ERROR(EBADMSG);
				goto out_nvl;
			}
		}

		/* Check end of stream marker */
		err = dmu_krrp_buffer_read(&drr, sizeof (drr), krrp_task);
		if (drr.drr_type != DRR_END &&
		    drr.drr_type != BSWAP_32(DRR_END)) {
			err = SET_ERROR(EBADMSG);
			goto out_nvl;
		}

		if (err == 0 && krrp_task->buffer_args.force_cksum &&
		    !ZIO_CHECKSUM_EQUAL(drr.drr_u.drr_end.drr_checksum,
		    zcksum)) {
			err = SET_ERROR(ECKSUM);
			goto out_nvl;
		}

		/* process all substeams from stream */
		for (;;) {
			nvlist_t *fs_props = NULL, *snap_props = NULL;
			boolean_t free_fs_props = B_FALSE;
			char ds[MAXNAMELEN];
			char *at;

			err = dmu_krrp_buffer_read(&drr,
			    sizeof (drr), krrp_task);
			if (err != 0)
				break;

			if (drr.drr_type == DRR_END ||
			    drr.drr_type == BSWAP_32(DRR_END))
				break;

			if (drr.drr_type != DRR_BEGIN ||
			    (drrb->drr_magic != DMU_BACKUP_MAGIC &&
			    drrb->drr_magic != BSWAP_64(DMU_BACKUP_MAGIC))) {
				err = SET_ERROR(EBADMSG);
				break;
			}

			if (strlen(krrp_task->buffer_args.to_ds) +
			    strlen(drrb->drr_toname + baselen) >= MAXNAMELEN) {
				err = SET_ERROR(ENAMETOOLONG);
				break;
			}

			(void) snprintf(ds, sizeof (ds), "%s%s",
			    krrp_task->buffer_args.to_ds,
			    drrb->drr_toname + baselen);
			if (nvfs != NULL) {
				char *snapname;
				nvlist_t *snapprops;
				nvlist_t *fs;

				fs = fsavl_find(fsavl, drrb->drr_toguid,
				    &snapname);
				err = nvlist_lookup_nvlist(fs,
				    "props", &fs_props);
				if (err != 0) {
					if (err != ENOENT) {
						err = SET_ERROR(err);
						break;
					}

					err = 0;
					fs_props = fnvlist_alloc();
					free_fs_props = B_TRUE;
				}

				if (nvlist_lookup_nvlist(fs,
				    "snapprops", &snapprops) == 0) {
					err = nvlist_lookup_nvlist(snapprops,
					    snapname, &snap_props);
					if (err != 0) {
						err = SET_ERROR(err);
						break;
					}
				}
			}

			(void) strlcpy(latest_snap, ds, sizeof (latest_snap));
			at = strrchr(ds, '@');
			*at = '\0';
			(void) strlcpy(krrp_task->cookie, drrb->drr_toname,
			    sizeof (krrp_task->cookie));
			err = zfs_recv_one_ds(ds, &drr, fs_props,
			    snap_props, krrp_task);
			if (free_fs_props)
				fnvlist_free(fs_props);

			if (err != 0)
				break;
		}

out_nvl:
		if (nvl != NULL) {
			fsavl_destroy(fsavl);
			fnvlist_free(nvl);
		}
	}

	/* Put final block */
	if (err == 0)
		(void) dmu_krrp_put_buffer(krrp_task);

out:
	dmu_set_send_recv_error(krrp_task_void, err);
	if (err != 0) {
		cmn_err(CE_WARN, "Recv thread exited with "
		    "error code %d", err);
	}

	(void) dmu_krrp_fini_task(krrp_task);
}

/* Common send/recv entry point */
static void *
dmu_krrp_init_send_recv(void (*func)(void *), kreplication_zfs_args_t *args)
{
	dmu_krrp_task_t *krrp_task =
	    kmem_zalloc(sizeof (dmu_krrp_task_t), KM_SLEEP);
	dmu_krrp_stream_t *stream = args->stream_handler;

	krrp_task->stream_handler = stream;
	krrp_task->buffer_args = *args;
	cv_init(&krrp_task->buffer_state_cv, NULL, CV_DEFAULT, NULL);
	cv_init(&krrp_task->buffer_destroy_cv, NULL, CV_DEFAULT, NULL);
	mutex_init(&krrp_task->buffer_state_lock, NULL,
	    MUTEX_DEFAULT, NULL);

	mutex_enter(&stream->mtx);
	if (!stream->running) {
		cmn_err(CE_WARN, "Cannot dispatch send/recv task");
		mutex_destroy(&krrp_task->buffer_state_lock);
		cv_destroy(&krrp_task->buffer_state_cv);
		cv_destroy(&krrp_task->buffer_destroy_cv);
		kmem_free(krrp_task, sizeof (dmu_krrp_task_t));

		mutex_exit(&stream->mtx);
		return (NULL);
	}

	stream->task = krrp_task;
	stream->task_executor = func;
	cv_broadcast(&stream->cv);
	mutex_exit(&stream->mtx);

	return (krrp_task);
}

void *
dmu_krrp_init_send_task(void *args)
{
	kreplication_zfs_args_t *zfs_args = args;
	ASSERT(zfs_args != NULL);
	*zfs_args->to_ds = '\0';
	return (dmu_krrp_init_send_recv(zfs_send_thread, zfs_args));
}

void *
dmu_krrp_init_recv_task(void *args)
{
	kreplication_zfs_args_t *zfs_args = args;
	ASSERT(zfs_args != NULL);
	*zfs_args->from_ds = '\0';
	return (dmu_krrp_init_send_recv(zfs_recv_thread, zfs_args));
}

static void
dmu_set_send_recv_error(void *krrp_task_void, int err)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;

	ASSERT(krrp_task != NULL);

	mutex_enter(&krrp_task->buffer_state_lock);
	krrp_task->buffer_error = err;
	mutex_exit(&krrp_task->buffer_state_lock);
}

/*
 * Finalize send/recv task
 * Finalization is two step process, both sides should finalize stream in order
 * to proceed. Finalization is an execution barier - a thread which ends first
 * will wait for another
 */
int
dmu_krrp_fini_task(void *krrp_task_void)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;
	int error;

	ASSERT(krrp_task != NULL);

	mutex_enter(&krrp_task->buffer_state_lock);
	if (krrp_task->buffer_state == SBS_DESTROYED) {
		cv_signal(&krrp_task->buffer_destroy_cv);
		error = krrp_task->buffer_error;
		mutex_exit(&krrp_task->buffer_state_lock);
	} else {
		krrp_task->buffer_state = SBS_DESTROYED;
		cv_signal(&krrp_task->buffer_state_cv);
		cv_wait(&krrp_task->buffer_destroy_cv,
		    &krrp_task->buffer_state_lock);
		error = krrp_task->buffer_error;
		mutex_exit(&krrp_task->buffer_state_lock);
		mutex_destroy(&krrp_task->buffer_state_lock);
		cv_destroy(&krrp_task->buffer_state_cv);
		cv_destroy(&krrp_task->buffer_destroy_cv);
		if (krrp_task->buffer_args.resume_info != NULL)
			fnvlist_free(krrp_task->buffer_args.resume_info);

		kmem_free(krrp_task, sizeof (dmu_krrp_task_t));
	}

	return (error);
}

/* Wait for a lent buffer */
static int
dmu_krrp_get_buffer(void *krrp_task_void)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;

	ASSERT(krrp_task != NULL);

	mutex_enter(&krrp_task->buffer_state_lock);
	while (krrp_task->buffer_state != SBS_AVAIL) {
		if (krrp_task->buffer_state == SBS_DESTROYED) {
			mutex_exit(&krrp_task->buffer_state_lock);
			return (SET_ERROR(ENOMEM));
		}
		DTRACE_PROBE(wait_for_buffer);
		(void) cv_timedwait(&krrp_task->buffer_state_cv,
		    &krrp_task->buffer_state_lock,
		    ddi_get_lbolt() + zfs_send_timeout * hz);
		DTRACE_PROBE(wait_for_buffer_end);
	}
	krrp_task->buffer_state = SBS_USED;
	mutex_exit(&krrp_task->buffer_state_lock);

	return (0);
}

/* Return buffer to transport */
static int
dmu_krrp_put_buffer(void *krrp_task_void)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;

	ASSERT(krrp_task != NULL);

	mutex_enter(&krrp_task->buffer_state_lock);
	if (krrp_task->buffer_state != SBS_USED) {
		mutex_exit(&krrp_task->buffer_state_lock);
		return (0);
	}
	krrp_task->buffer_state = SBS_DONE;
	krrp_task->is_full = (krrp_task->buffer == NULL);
	krrp_task->buffer = NULL;
	cv_signal(&krrp_task->buffer_state_cv);
	mutex_exit(&krrp_task->buffer_state_lock);

	return (0);
}

/* Common entry point for lending buffer */
static int
dmu_krrp_lend_buffer(void *krrp_task_void,
    kreplication_buffer_t *buffer, boolean_t recv)
{
	dmu_krrp_task_t *krrp_task = krrp_task_void;
	boolean_t full;

	ASSERT(krrp_task != NULL);
	ASSERT(buffer != NULL);
	ASSERT(krrp_task->buffer == NULL);

	mutex_enter(&krrp_task->buffer_state_lock);
	if (krrp_task->buffer_state == SBS_DESTROYED) {
		int error = krrp_task->buffer_error;
		mutex_exit(&krrp_task->buffer_state_lock);
		if (error)
			return (error);
		if (recv)
			return (E2BIG);
		return (ENODATA);
	}
	krrp_task->buffer = buffer;
	krrp_task->buffer_state = SBS_AVAIL;
	krrp_task->buffer_bytes_read = 0;
	krrp_task->is_read = B_FALSE;
	krrp_task->is_full = B_FALSE;
	cv_signal(&krrp_task->buffer_state_cv);
	while (krrp_task->buffer_state != SBS_DONE) {
		if (krrp_task->buffer_state == SBS_DESTROYED) {
			int error = krrp_task->buffer_error;
			full = krrp_task->is_full;
			mutex_exit(&krrp_task->buffer_state_lock);
			if (error)
				return (error);
			if (recv && !krrp_task->is_read)
				return (E2BIG);
			return ((recv || full) ? 0 : ENODATA);
		}
		DTRACE_PROBE(wait_for_data);
		(void) cv_timedwait(&krrp_task->buffer_state_cv,
		    &krrp_task->buffer_state_lock,
		    ddi_get_lbolt() + zfs_send_timeout * hz);
		DTRACE_PROBE(wait_for_data_end);
	}
	krrp_task->buffer = NULL;
	full = krrp_task->is_full;
	mutex_exit(&krrp_task->buffer_state_lock);

	return ((recv || full) ? 0 : ENODATA);
}

int
dmu_krrp_lend_send_buffer(void *krrp_task_void, kreplication_buffer_t *buffer)
{
	ASSERT(buffer != NULL);
	kreplication_buffer_t *iter;
	for (iter = buffer; iter != NULL; iter = iter->next)
		iter->data_size = 0;
	return (dmu_krrp_lend_buffer(krrp_task_void, buffer, B_FALSE));
}

int
dmu_krrp_lend_recv_buffer(void *krrp_task_void, kreplication_buffer_t *buffer)
{
	ASSERT(buffer != NULL);
	return (dmu_krrp_lend_buffer(krrp_task_void, buffer, B_TRUE));
}

int
dmu_krrp_direct_arc_read(spa_t *spa, dmu_krrp_task_t *krrp_task,
    zio_cksum_t *zc, const blkptr_t *bp)
{
	int error;
	dmu_krrp_arc_bypass_t bypass = {
	    .krrp_task = krrp_task,
	    .zc = zc,
	    .cb = dmu_krrp_buffer_write,
	};

	error = arc_io_bypass(spa, bp, dmu_krrp_arc_bypass, &bypass);
	if (error == 0) {
		DTRACE_PROBE(krrp_send_arc_bypass);
	} else if (error == ENODATA) {
		DTRACE_PROBE(krrp_send_disk_read);
		return (error);
	}

	if (error != 0) {
		DTRACE_PROBE1(orig_error, int, error);
		error = SET_ERROR(EINTR);
	}

	return (error);
}

static int
dmu_krrp_validate_resume_info(nvlist_t *resume_info)
{
	char *toname = NULL;
	uint64_t resumeobj = 0, resumeoff = 0, bytes = 0, toguid = 0;

	if (nvlist_lookup_string(resume_info, "toname", &toname) != 0 ||
	    nvlist_lookup_uint64(resume_info, "object", &resumeobj) != 0 ||
	    nvlist_lookup_uint64(resume_info, "offset", &resumeoff) != 0 ||
	    nvlist_lookup_uint64(resume_info, "bytes", &bytes) != 0 ||
	    nvlist_lookup_uint64(resume_info, "toguid", &toguid) != 0)
		return (SET_ERROR(EINVAL));

	return (0);
}

int
dmu_krrp_decode_resume_token(const char *resume_token, nvlist_t **resume_info)
{
	nvlist_t *nvl = NULL;
	int err;

	err = zfs_send_resume_token_to_nvlist_impl(resume_token, &nvl);
	if (err != 0)
		return (err);

	err = dmu_krrp_validate_resume_info(nvl);
	if (err != 0)
		return (err);

	ASSERT(resume_info != NULL && *resume_info == NULL);
	*resume_info = nvl;
	return (0);
}
