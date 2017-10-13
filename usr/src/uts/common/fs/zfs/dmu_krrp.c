/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

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

/* Used by zfs_lookup_origin_snapshot() */
typedef struct {
	char *origin_name;
	uint64_t guid;
} zfs_los_cb_arg_t;

/* An element of snapshots AVL-tree of zfs_ds_node_t */
typedef struct {
	char name[ZFS_MAX_DATASET_NAME_LEN];
	uint64_t txg;
	uint64_t guid;
	dsl_dataset_t *ds;
	avl_node_t avl_node;
	boolean_t origin;
} zfs_snap_avl_node_t;

typedef struct zfs_ds_node zfs_ds_node_t;
struct zfs_ds_node {
	char name[ZFS_MAX_DATASET_NAME_LEN];
	char origin_name[ZFS_MAX_DATASET_NAME_LEN];
	uint64_t origin_guid;
	uint64_t creation_txg;
	boolean_t is_root;
	boolean_t is_clone;

	zfs_ds_node_t *origin;
	dsl_dataset_t *ds;

	list_node_t list_node;
	avl_node_t avl_node;

	avl_tree_t snapshots;
};

typedef struct {
	list_t *datasets;
	avl_tree_t clones_avl;
	void *owner;
	uint64_t root_ds_object;
} zfs_collect_cb_arg_t;


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
		(void) fletcher_4_incremental_native(buf, len, bypass->zc);
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
 * zfs_collect_snap_props and zfs_collect_fs_props
 * iterates over the given zap-object and adds zfs props
 * to the resulting nvlist
 */
static int
zfs_collect_props(objset_t *mos, uint64_t zapobj, nvlist_t *props)
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
zfs_collect_snap_props(dsl_dataset_t *snap_ds, nvlist_t **nvsnaps_props)
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
	err = zfs_collect_props(mos, zapobj, props);
	if (err == 0)
		*nvsnaps_props = props;
	else
		fnvlist_free(props);

	return (err);
}

static int
zfs_collect_fs_props(dsl_dataset_t *fs_ds, nvlist_t *nvfs)
{
	int err = 0;
	uint64_t zapobj;
	objset_t *mos;
	nvlist_t *nvfsprops;

	ASSERT(dsl_dataset_long_held(fs_ds));

	nvfsprops = fnvlist_alloc();
	mos = fs_ds->ds_dir->dd_pool->dp_meta_objset;
	zapobj = dsl_dir_phys(fs_ds->ds_dir)->dd_props_zapobj;
	err = zfs_collect_props(mos, zapobj, nvfsprops);
	if (err == 0)
		fnvlist_add_nvlist(nvfs, "props", nvfsprops);

	fnvlist_free(nvfsprops);

	return (err);
}

/* AVL compare function for snapshots */
static int
zfs_snapshot_txg_compare(const void *arg1, const void *arg2)
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
 * This function is used to make decision about include
 * the given snap_ds into stream or not.
 *
 * Returns B_TRUE if the given snapshot has the given
 * prop_name and its value is not equal to the given prop_val,
 * otherwise returns B_FALSE
 */
static boolean_t
zfs_skip_check(dsl_dataset_t *snap_ds,
    const char *prop_name, const char *prop_val)
{
	uint64_t zapobj;
	objset_t *mos;
	char val[ZAP_MAXVALUELEN];
	uint64_t cnt = 0, el = 0;

	if (prop_name == NULL || prop_val == NULL)
		return (B_FALSE);

	mos = snap_ds->ds_dir->dd_pool->dp_meta_objset;
	zapobj = dsl_dataset_phys(snap_ds)->ds_props_obj;

	if (zap_length(mos, zapobj, prop_name, &el, &cnt) == 0) {
		if (zap_lookup(mos, zapobj, prop_name,
			STRING_PROP_EL_SIZE, cnt, val) != 0)
			return (B_FALSE);

		if (strcmp(prop_val, val) != 0)
			return (B_TRUE);
	}

	return (B_FALSE);
}

/*
 * Collects all snapshots (txg_first < Creation TXG < txg_last)
 * for the given FS and adds them to the resulting AVL-tree
 */
static int
zfs_collect_interim_snaps(dmu_krrp_task_t *krrp_task,
    zfs_ds_node_t *fs_el, uint64_t txg_first,
    uint64_t txg_last)
{
	int err;
	uint64_t ds_creation_txg;
	avl_tree_t *snapshots = &fs_el->snapshots;
	zfs_snap_avl_node_t *snap_el;
	char full_snap_name[ZFS_MAX_DATASET_NAME_LEN];
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
		    sizeof (full_snap_name) - strlen(full_snap_name),
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

		err = dsl_dataset_hold(dp, full_snap_name, krrp_task, &snap_ds);
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
			dsl_dataset_rele(snap_ds, krrp_task);
			continue;
		}

		if (zfs_skip_check(snap_ds,
		    krrp_task->buffer_args.skip_snaps_prop_name,
		    krrp_task->buffer_args.skip_snaps_prop_val)) {
			dsl_dataset_rele(snap_ds, krrp_task);
			continue;
		}

		snap_el = zfs_construct_snap_node(snap_ds,
		    full_snap_name);
		dsl_dataset_long_hold(snap_ds, krrp_task);
		avl_add(snapshots, snap_el);
	}

	dsl_pool_config_exit(dp, FTAG);

	return (err);
}

/*
 * Collect snapshots of a given dataset in a given range, where
 *     'to_snap'   - the right boundary
 *     'from_snap' - the left boundary
 * Collects interim snapshots if incl_interim_snaps == B_TRUE
 */
static int
zfs_collect_snaps(dmu_krrp_task_t *krrp_task,
    zfs_ds_node_t *fs_el, char *from_snap,
    char *to_snap, boolean_t incl_interim_snaps)
{
	int err = 0;
	dsl_dataset_t *snap_ds = NULL;
	dsl_dataset_t *fs_ds = fs_el->ds;
	dsl_pool_t *dp = fs_ds->ds_dir->dd_pool;
	uint64_t txg_first = 0, txg_last = UINT64_MAX;
	char full_snap_name[ZFS_MAX_DATASET_NAME_LEN];
	char *snap_name;
	boolean_t no_from_snap = B_TRUE;

	zfs_snap_avl_node_t *from_snap_el = NULL;
	zfs_snap_avl_node_t *to_snap_el = NULL;

	/* the right boundary snapshot should be exist */
	if (to_snap == NULL || to_snap[0] == '\0')
		return (SET_ERROR(EINVAL));

	dsl_pool_config_enter(dp, FTAG);

	/*
	 * Snapshots must be sorted in the ascending order by birth_txg
	 */
	avl_create(&fs_el->snapshots, zfs_snapshot_txg_compare,
	    sizeof (zfs_snap_avl_node_t),
	    offsetof(zfs_snap_avl_node_t, avl_node));

	(void) snprintf(full_snap_name, sizeof (full_snap_name),
	    "%s@%s", fs_el->name, to_snap);
	snap_name = strchr(full_snap_name, '@') + 1;

	err = dsl_dataset_hold(dp, full_snap_name, krrp_task, &snap_ds);
	if (err != 0) {
		dsl_pool_config_exit(dp, FTAG);

		/*
		 * This FS was created after 'to_snap',
		 * so skip it at this time
		 */
		if (err == ENOENT)
			err = 0;

		return (err);
	}

	to_snap_el = zfs_construct_snap_node(snap_ds,
	    full_snap_name);
	txg_last = dsl_dataset_phys(snap_ds)->ds_creation_txg;
	dsl_dataset_long_hold(to_snap_el->ds, krrp_task);
	avl_add(&fs_el->snapshots, to_snap_el);

	/* check left boundary */
	if (from_snap != NULL && from_snap[0] != '\0') {
		snap_ds = NULL;
		snap_name[0] = '\0';
		(void) strcat(full_snap_name, from_snap);
		err = dsl_dataset_hold(dp, full_snap_name,
		    krrp_task, &snap_ds);

		if (err == 0) {
			txg_first =
			    dsl_dataset_phys(snap_ds)->ds_creation_txg;
			from_snap_el =
			    zfs_construct_snap_node(snap_ds, full_snap_name);
			dsl_dataset_long_hold(from_snap_el->ds, krrp_task);
			avl_add(&fs_el->snapshots, from_snap_el);
			no_from_snap = B_FALSE;
		} else {
			/*
			 * it is possible that from_snap does not exist
			 * for a child FS, because the FS was created
			 * after from_snap
			 */
			if (err != ENOENT || fs_el->is_root) {
				dsl_pool_config_exit(dp, FTAG);
				return (err);
			}

			err = 0;
		}
	}

	/*
	 * For cloned DS that doesn't have from_snap
	 * need to  igin_snap as from_snap
	 * The owner of the held origin will be fs_el
	 */
	if (no_from_snap && fs_el->origin_name[0] != '\0') {
		snap_ds = NULL;
		err = dsl_dataset_hold(dp, fs_el->origin_name,
		    fs_el, &snap_ds);
		if (err != 0) {
			dsl_pool_config_exit(dp, FTAG);
			return (err);
		}

		/*
		 * Need to be sure that origin's name doesn't
		 * match the skip_mask. If origin was not/will
		 * not be replicated to the destination, then
		 * its clone will be replicated as a regular DS.
		 */
		if (zfs_skip_check(snap_ds,
		    krrp_task->buffer_args.skip_snaps_prop_name,
		    krrp_task->buffer_args.skip_snaps_prop_val)) {
			dsl_dataset_rele(snap_ds, fs_el);
		} else {
			dsl_dataset_long_hold(snap_ds, fs_el);
			from_snap_el = zfs_construct_snap_node(snap_ds,
			    fs_el->origin_name);
			from_snap_el->origin = B_TRUE;
			avl_add(&fs_el->snapshots, from_snap_el);
		}
	}

	dsl_pool_config_exit(dp, FTAG);

	/*
	 * 'FROM' snapshot cannot be created before 'TO' snapshot
	 * and
	 * 'FROM' and 'TO' snapshots cannot be the same snapshot
	 */
	if (txg_last <= txg_first)
		return (SET_ERROR(EXDEV));

	/*
	 * If 'incl_interim_snaps' flag isn't presented,
	 * only 'from' and 'to' snapshots should be in list
	 */
	if (!incl_interim_snaps)
		return (0);

	err = zfs_collect_interim_snaps(krrp_task, fs_el,
	    txg_first, txg_last);

	return (err);
}

static boolean_t
zfs_is_snapshot_belong(const char *ds_name, const char *snap_name)
{
	char *at;

	ASSERT(strchr(ds_name, '@') == NULL);
	VERIFY((at = strrchr(snap_name, '@')) != NULL);

	return (strncmp(ds_name, snap_name, at - snap_name + 1) == 0);
}

/*
 * AVL compare function for cloned datasets
 * To be sure that a cloned dataset will be replicated
 * after its origin this functions does 2-stage compare.
 * At the first stage it compares origin_name and name
 * of both nodes to check that either s1 is clone of s2
 * or vise versa.
 * If s1 and s2 don't have dependencies, then at the second
 * stage this function compares their TXG.
 */
static int
zfs_cloned_ds_compare(const void *arg1, const void *arg2)
{
	const zfs_ds_node_t *s1 = arg1;
	const zfs_ds_node_t *s2 = arg2;

	/* s1 is clone of s2, so s1 needs to be placed after s2 */
	if (zfs_is_snapshot_belong(s2->name, s1->origin_name))
		return (+1);

	/* s2 is clone of s1, so s2 needs to be placed after s1 */
	if (zfs_is_snapshot_belong(s1->name, s2->origin_name))
		return (-1);

	if (s1->creation_txg > s2->creation_txg)
		return (+1);

	if (s1->creation_txg < s2->creation_txg)
		return (-1);

	return (0);
}

/*
 * This function retrieves the name and
 * the guid of origin snapshot for the given clone
 */
static int
zfs_populate_clone_info(zfs_ds_node_t *node)
{
	int err;
	dsl_dataset_t *ds_origin = NULL;
	dsl_dir_t *ds_dir = node->ds->ds_dir;
	dsl_pool_t *dp = ds_dir->dd_pool;

	err = dsl_dataset_hold_obj(dp,
	    dsl_dir_phys(ds_dir)->dd_origin_obj, FTAG, &ds_origin);
	if (err != 0)
		return (err);

	ASSERT(ds_origin->ds_is_snapshot);
	dsl_dataset_name(ds_origin, node->origin_name);
	ASSERT(strchr(node->origin_name, '@') != NULL);
	node->origin_guid = dsl_dataset_phys(ds_origin)->ds_guid;
	dsl_dataset_rele(ds_origin, FTAG);

	return (0);
}

/*
 * This function is used to lookup a node in the given list,
 * that points to the parent of origin snapshot for the given
 * clone_node. The last one is not a part of the list.
 *
 * If the list doesn't have required node, then NULL is returned.
 */
static zfs_ds_node_t *
zfs_lookup_origin_node(list_t *ds_to_send, zfs_ds_node_t *clone_node)
{
	char *at;
	zfs_ds_node_t *node;

	at = strchr(clone_node->origin_name, '@');
	*at = '\0';

	node = list_head(ds_to_send);
	while (node != NULL) {
		if (strcmp(node->name, clone_node->origin_name) == 0)
			break;

		node = list_next(ds_to_send, node);
	}

	*at = '@';
	return (node);
}

/*
 * This function is used to lookup a node in the given list,
 * that points to the parent of the tnode. The last one
 * is not a part of the list.
 *
 * If the list doesn't have required node, then NULL is returned.
 */
static zfs_ds_node_t *
zfs_lookup_parent_node(list_t *ds_list, zfs_ds_node_t *tnode,
    zfs_ds_node_t  *start_node)
{
	char *final_slash;
	zfs_ds_node_t *node;

	final_slash = strrchr(tnode->name, '/');
	if (final_slash == NULL)
		return (NULL);

	*final_slash = '\0';

	node = (start_node == NULL) ? list_head(ds_list) : start_node;
	while (node != NULL) {
		if (strcmp(node->name, tnode->name) == 0)
			break;

		node = list_next(ds_list, node);
	}

	*final_slash = '/';
	return (node);
}

static int
zfs_construct_ds_node(dsl_pool_t *dp, uint64_t ds_object,
    void *owner, zfs_ds_node_t **result)
{
	zfs_ds_node_t *node;
	int err;

	ASSERT(result != NULL && *result == NULL);

	node = kmem_zalloc(sizeof (zfs_ds_node_t), KM_SLEEP);

	/* We need our own "hold" on the dataset */
	err = dsl_dataset_hold_obj(dp, ds_object,
	    owner, &node->ds);
	if (err != 0) {
		kmem_free(node, sizeof (zfs_ds_node_t));
		return (err);
	}

	dsl_dataset_long_hold(node->ds, owner);

	dsl_dataset_name(node->ds, node->name);
	node->creation_txg = dsl_dataset_phys(node->ds)->ds_creation_txg;

	node->is_clone = dsl_dir_is_clone(node->ds->ds_dir);
	if (node->is_clone) {
		err = zfs_populate_clone_info(node);
		if (err != 0) {
			dsl_dataset_long_rele(node->ds, owner);
			dsl_dataset_rele(node->ds, owner);
			kmem_free(node, sizeof (zfs_ds_node_t));
			return (err);
		}
	}

	*result = node;
	return (0);
}

/*
 * This function walks only next-level children (depth = 1)
 * and puts them into the given list.
 * Clones also are placed into the given AVL.
 */
static int
zfs_collect_children(dmu_krrp_task_t *krrp_task, dsl_pool_t *dp,
    zfs_ds_node_t *parent_node, list_t *ds_list, avl_tree_t *clones)
{
	zap_cursor_t zc;
	zap_attribute_t attr;
	int err;
	objset_t *mos = dp->dp_meta_objset;
	uint64_t dd_child_dir_zapobj =
	    dsl_dir_phys(parent_node->ds->ds_dir)->dd_child_dir_zapobj;

	zap_cursor_init(&zc, mos, dd_child_dir_zapobj);
	while (zap_cursor_retrieve(&zc, &attr) == 0) {
		dsl_dir_t *dd = NULL;
		zfs_ds_node_t *node = NULL;

		ASSERT3U(attr.za_integer_length, ==,
			sizeof (uint64_t));
		ASSERT3U(attr.za_num_integers, ==, 1);

		err = dsl_dir_hold_obj(dp, attr.za_first_integer,
		    attr.za_name, FTAG, &dd);
		if (err != 0)
			break;

		err = zfs_construct_ds_node(dp,
		    dsl_dir_phys(dd)->dd_head_dataset_obj,
		    krrp_task, &node);
		dsl_dir_rele(dd, FTAG);
		if (err != 0) {
			break;
		}

		list_insert_tail(ds_list, node);
		if (node->is_clone)
			avl_add(clones, node);

		(void) zap_cursor_advance(&zc);
	}

	zap_cursor_fini(&zc);

	return (err);
}

/*
 * Collect datasets and snapshots of each dataset.
 *
 * This function walks ZFS-tree of datasets by using
 * breadth-first search (BFS) method to avoid misordering
 * in case of existing cloned datasets.
 */
static int
zfs_collect_ds(dmu_krrp_task_t *krrp_task, spa_t *spa, list_t *ds_list)
{
	int err = 0;
	dsl_pool_t *dp;
	dsl_dataset_t *ds = NULL;
	uint64_t root_ds_object;
	zfs_ds_node_t *clone_node, *node, *parent_node;
	void *cookie = NULL;
	avl_tree_t clones;

	char *from_ds = krrp_task->buffer_args.from_ds;
	char *from_snap = krrp_task->buffer_args.from_incr_base;
	char *to_snap = krrp_task->buffer_args.from_snap;
	boolean_t incl_interim_snaps = krrp_task->buffer_args.do_all;
	boolean_t recursive = krrp_task->buffer_args.recursive;

	dp = spa_get_dsl(spa);

	dsl_pool_config_enter(dp, FTAG);

	err = dsl_dataset_hold(dp, from_ds, FTAG, &ds);
	if (err != 0) {
		dsl_pool_config_exit(dp, FTAG);
		return (err);
	}

	root_ds_object = ds->ds_object;
	dsl_dataset_rele(ds, FTAG);

	node = NULL;
	err = zfs_construct_ds_node(dp, root_ds_object,
	    krrp_task, &node);
	if (err != 0) {
		dsl_pool_config_exit(dp, FTAG);
		return (err);
	}

	node->is_root = B_TRUE;
	list_insert_head(ds_list, node);

	avl_create(&clones, zfs_cloned_ds_compare,
	    sizeof (zfs_ds_node_t), offsetof(zfs_ds_node_t, avl_node));

	if (recursive) {
		/*
		 * The following loop walk over the list,
		 * that is populated by zfs_collect_children(),
		 * that always puts new items to the tail.
		 *
		 */
		while (node != NULL) {
			err = zfs_collect_children(krrp_task,
			    dp, node, ds_list, &clones);
			if (err != 0)
				break;

			node = list_next(ds_list, node);
		}
	}

	dsl_pool_config_exit(dp, FTAG);

	if (err != 0) {
		while ((node = avl_destroy_nodes(&clones, &cookie)) != NULL);
		avl_destroy(&clones);
		return (err);
	}

	/*
	 * We've collected all required datasets.
	 *
	 * Now need to do additional resort to place cloned datasets
	 * to the correct position. And there are 2 cases:
	 *  (1) parent is located before the origin DS
	 *  (2) parent is located after the origin DS
	 * In the first case need to place clone rigth after origin,
	 * in the second after parent.
	 *
	 * avl_destroy_nodes() cannot be used here, because it
	 * travels AVL from the end.
	 */
	while ((clone_node = avl_first(&clones)) != NULL) {
		avl_remove(&clones, clone_node);
		list_remove(ds_list, clone_node);

		clone_node->origin =
		    zfs_lookup_origin_node(ds_list, clone_node);

		if (clone_node->origin == NULL) {
#ifdef ZFS_DEBUG
			panic("zfs_lookup_origin_node() fails: [%p] [%p] [%p]",
			    (void *)clone_node, (void *)&clones, (void *)ds_list);
#endif
			return (SET_ERROR(ENOLINK));
		}

		/*
		 * We are looking for parent starting from origin,
		 * because cannot place clone before its origin.
		 *
		 * parent_node == NULL means that it is located
		 * in the list before origin, so we can just put
		 * it rigth after the origin.
		 */
		parent_node = zfs_lookup_parent_node(ds_list,
		    clone_node, clone_node->origin);
		if (parent_node == NULL) {
			list_insert_after(ds_list,
			    clone_node->origin, clone_node);
		} else {
			list_insert_after(ds_list,
			    parent_node, clone_node);
		}
	}

	avl_destroy(&clones);

	node = list_head(ds_list);
	while (err == 0 && node != NULL) {
		err = zfs_collect_snaps(krrp_task, node,
		    from_snap, to_snap, incl_interim_snaps);
		node = list_next(ds_list, node);
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
	boolean_t compressok = krrp_task->buffer_args.compressok;
	boolean_t large_block_ok = krrp_task->buffer_args.large_block_ok;
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
	 * that already is opened in our case, so it cannot fail
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
		    embedok, large_block_ok, compressok, -1, resumeobj, resumeoff, NULL,
		    &off, krrp_task);
	} else {
		err = dmu_send_impl(FTAG, dp, snap_ds, NULL, B_FALSE,
		    embedok, large_block_ok, compressok, -1, resumeobj, resumeoff, NULL,
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
	zfs_ds_node_t *fs_el;
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
		char *at;

		nvfs = fnvlist_alloc();
		fnvlist_add_string(nvfs, "name", fs_el->name);

		if (fs_el->origin_name[0] != '\0') {
			fnvlist_add_uint64(nvfs,
		        "origin", fs_el->origin_guid);
			VERIFY((at = strchr(fs_el->origin_name, '@')) != NULL);
			*at = '\0';
			fnvlist_add_string(nvfs,
		        "origin_fsname", fs_el->origin_name);
			*at = '@';
		}

		err = zfs_collect_fs_props(fs_el->ds, nvfs);
		if (err != 0) {
			fnvlist_free(nvfs);
			break;
		}

		nvsnaps = fnvlist_alloc();
		nvsnaps_props = fnvlist_alloc();

		snap_el = avl_first(&fs_el->snapshots);
		while (snap_el != NULL) {
			nvlist_t *nvsnap_props = NULL;
			char *snapname, *at;

			at = strrchr(snap_el->name, '@');
			ASSERT(at != NULL);
			if (at == NULL) {
				err = SET_ERROR(EILSEQ);
				break;
			}

			err = zfs_collect_snap_props(snap_el->ds,
			    &nvsnap_props);
			if (err != 0)
				break;

			snapname = at + 1;
			fnvlist_add_uint64(nvsnaps, snapname, snap_el->guid);
			fnvlist_add_nvlist(nvsnaps_props,
			    snapname, nvsnap_props);
			fnvlist_free(nvsnap_props);

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
		(void) fletcher_4_incremental_native(&drr, sizeof (drr), &zc);

	err = dmu_krrp_buffer_write(&drr, sizeof (drr), krrp_task);
	if (err != 0)
		goto out;

	if (buflen != 0) {
		if (krrp_task->buffer_args.force_cksum)
			(void) fletcher_4_incremental_native(packbuf, buflen, &zc);

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

	/*
	 * Origin snapshot is here not to sent it,
	 * it is used to define start point
	 */
	if (snap_el != NULL && snap_el->origin) {
		snap_el_prev = snap_el;
		snap_el = AVL_NEXT(snapshots, snap_el);
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
	zfs_ds_node_t *fs_el;
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
	zfs_ds_node_t *fs_el;
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
zfs_cleanup_send_list(dmu_krrp_task_t *krrp_task, list_t *ds_list)
{
	zfs_ds_node_t *fs_el;

	/* Walk over all collected FSs and their SNAPs to cleanup */
	while ((fs_el = list_remove_head(ds_list)) != NULL) {
		zfs_snap_avl_node_t *snap_el;
		void *cookie = NULL;

		while ((snap_el = avl_destroy_nodes(&fs_el->snapshots,
		    &cookie)) != NULL) {
			if (snap_el->origin) {
				dsl_dataset_long_rele(snap_el->ds, fs_el);
				dsl_dataset_rele(snap_el->ds, fs_el);
			} else {
				dsl_dataset_long_rele(snap_el->ds, krrp_task);
				dsl_dataset_rele(snap_el->ds, krrp_task);
			}

			kmem_free(snap_el, sizeof (zfs_snap_avl_node_t));
		}

		dsl_dataset_long_rele(fs_el->ds, krrp_task);
		dsl_dataset_rele(fs_el->ds, krrp_task);

		kmem_free(fs_el, sizeof (zfs_ds_node_t));
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
	spa_t *spa = NULL;

	boolean_t compound_stream = buffer_args->recursive ||
	    buffer_args->properties || buffer_args->do_all;

	ASSERT(krrp_task != NULL);

	err = spa_open(krrp_task->buffer_args.from_ds, &spa, krrp_task);
	if (err != 0)
		goto early_error;

	if (buffer_args->resume_info != NULL) {
		err = dmu_krrp_validate_resume_info(buffer_args->resume_info);
		if (err != 0)
			goto early_error;
	}

	list_create(&ds_to_send, sizeof (zfs_ds_node_t),
	    offsetof(zfs_ds_node_t, list_node));

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

	err = zfs_collect_ds(krrp_task, spa, &ds_to_send);

	autosnap_unlock(spa);

	if (err != 0)
		goto final;

	/*
	 * Recursive stream, stream with properties, or complete-incremental
	 * stream have special header (DMU_COMPOUNDSTREAM)
	 */
	if (compound_stream) {
		err = zfs_send_compound_stream_header(krrp_task, &ds_to_send);
		if (err != 0)
			goto final;
	}

	err = zfs_send_ds(krrp_task, &ds_to_send);

final:

	zfs_cleanup_send_list(krrp_task, &ds_to_send);

	list_destroy(&ds_to_send);

	if (err == 0 && compound_stream) {
		bzero(&drr, sizeof (drr));
		drr.drr_type = DRR_END;
		err = dmu_krrp_buffer_write(&drr, sizeof (drr), krrp_task);
	}

	if (err == 0)
		err = dmu_krrp_put_buffer(krrp_task);

early_error:
	if (err != 0) {
		dmu_set_send_recv_error(krrp_task, err);
		cmn_err(CE_WARN, "Send thread exited with error code %d", err);
	}

	if (spa != NULL)
		spa_close(spa, krrp_task);

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

/*
 * Callback for dmu_objset_find_dp()
 * Checks only snapshots. If a snapshot is matched 'guid',
 * that is passed over the cb_arg, then the snapshot is
 * our target origin. So that we store its name and return
 * EINTR to speed up finalization of dmu_objset_find_dp()
 */
/* ARGSUSED */
static int
zfs_lookup_origin_snapshot_cb(dsl_pool_t *dp,
    dsl_dataset_t *ds, void *arg)
{
	zfs_los_cb_arg_t *cb_arg = arg;

	if (!ds->ds_is_snapshot)
		return (0);


	if (dsl_dataset_phys(ds)->ds_guid == cb_arg->guid) {
		dsl_dataset_name(ds, cb_arg->origin_name);
		return (EINTR);
	}

	return (0);
}

/*
 * FIXME: needs to be optimized
 * TODO: no reason to walk over the already walked datasets
 */
static int
zfs_lookup_origin_snapshot(spa_t *spa, const char *clone_name,
    uint64_t guid, char *result)
{
	char start[ZFS_MAX_DATASET_NAME_LEN];
	char *cp;
	dsl_pool_t *dp = spa_get_dsl(spa);
	zfs_los_cb_arg_t cb_arg = {result, guid};

	ASSERT(result != NULL);

	*result = '\0';

	(void) strlcpy(start, clone_name, sizeof (start));
	cp = strrchr(start, '/');
	if (cp == NULL)
		cp = strchr(start, '\0');

	for (; cp != NULL; cp = strrchr(start, '/')) {
		dsl_dataset_t *ds = NULL;
		int err;
		uint64_t dd_object;

		*cp = '\0';

		dsl_pool_config_enter(dp, FTAG);

		err = dsl_dataset_hold(dp, start, FTAG, &ds);
		if (err != 0) {
			dsl_pool_config_exit(dp, FTAG);
			break;
		}

		dd_object = ds->ds_dir->dd_object;
		dsl_dataset_rele(ds, FTAG);

		err = dmu_objset_find_dp(dp, dd_object,
		    zfs_lookup_origin_snapshot_cb, &cb_arg,
		    DS_FIND_CHILDREN | DS_FIND_SNAPSHOTS);

		dsl_pool_config_exit(dp, FTAG);

		if (*result != '\0' || err != 0)
			break;
	}

	return ((*result == '\0') ? -1 : 0);
}

/* Recv a single snapshot. It is a simplified version of recv */
static int
zfs_recv_one_ds(spa_t *spa, char *ds, dmu_replay_record_t *drr,
    nvlist_t *fs_props, nvlist_t *snap_props, dmu_krrp_task_t *krrp_task)
{
	int err = 0;
	uint64_t errf = 0;
	uint64_t ahdl = 0;
	uint64_t sz = 0;
	char *tosnap;
	char origin[ZFS_MAX_DATASET_NAME_LEN];
	char *originp = NULL;
	struct drr_begin *drrb = &drr->drr_u.drr_begin;

	if (krrp_task->buffer_args.to_snap[0]) {
		tosnap = krrp_task->buffer_args.to_snap;
	} else {
		tosnap = strchr(drrb->drr_toname, '@') + 1;
	}

	/* To recv cloned DS need to find its origin snapshot */
	if ((drrb->drr_flags & DRR_FLAG_CLONE) != 0) {
		err = zfs_lookup_origin_snapshot(spa, ds,
		    drrb->drr_fromguid, origin);
		if (err != 0) {
			if (krrp_debug) {
				cmn_err(CE_WARN, "Origin snapshot "
				    "(guid: %llu) does not exist",
				    (unsigned long long)drrb->drr_fromguid);
			}

			return (SET_ERROR(EINVAL));
		}

		originp = origin;
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
	err = dmu_recv_impl(NULL, ds, tosnap, originp, drr, B_TRUE, fs_props,
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
 * Dedup-stream is not supported
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
	spa_t *spa = NULL;
	char latest_snap[ZFS_MAX_DATASET_NAME_LEN] = { 0 };
	char to_ds[ZFS_MAX_DATASET_NAME_LEN];
	int hdrtype;
	uint64_t featureflags;

	ASSERT(krrp_task != NULL);

	err = spa_open(krrp_task->buffer_args.to_ds, &spa, krrp_task);
	if (err != NULL)
		goto out;

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

	featureflags = DMU_GET_FEATUREFLAGS(drrb->drr_versioninfo);
	hdrtype = DMU_GET_STREAM_HDRTYPE(drrb->drr_versioninfo);
	if (!DMU_STREAM_SUPPORTED(featureflags) ||
	    (hdrtype != DMU_SUBSTREAM && hdrtype != DMU_COMPOUNDSTREAM)) {
		err = SET_ERROR(EBADMSG);
		goto out;
	}

	if (hdrtype == DMU_SUBSTREAM) {
		/* recv a simple single snapshot */
		char full_ds[ZFS_MAX_DATASET_NAME_LEN];

		(void) strlcpy(full_ds, krrp_task->buffer_args.to_ds,
		    sizeof (full_ds));
		if (krrp_task->buffer_args.strip_head ||
		    krrp_task->buffer_args.leave_tail) {
			char *pos;
			int len = strlen(full_ds) +
			    strlen(drrb->drr_toname + baselen) + 1;
			if (len < sizeof (full_ds)) {
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
		err = zfs_recv_one_ds(spa, full_ds, &drr, NULL, NULL, krrp_task);
	} else {
		nvlist_t *nvl = NULL, *nvfs = NULL;
		avl_tree_t *fsavl = NULL;

		if (krrp_task->buffer_args.force_cksum) {
			(void) fletcher_4_incremental_native(&drr,
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
				(void) fletcher_4_incremental_native(buf,
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
			char ds[ZFS_MAX_DATASET_NAME_LEN];
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
			    strlen(drrb->drr_toname + baselen) >= sizeof (ds)) {
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
			err = zfs_recv_one_ds(spa, ds, &drr, fs_props,
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

	if (spa != NULL)
		spa_close(spa, krrp_task);

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

/*
 * FIXME: Temporary disabled because this logic
 * needs to be adjusted according to ARC-Compression changes
 */
/* ARGSUSED */
int
dmu_krrp_direct_arc_read(spa_t *spa, dmu_krrp_task_t *krrp_task,
    zio_cksum_t *zc, const blkptr_t *bp)
{
	return (ENODATA);

#if 0
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
#endif
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
