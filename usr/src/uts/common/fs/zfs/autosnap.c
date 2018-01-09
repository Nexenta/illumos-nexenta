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

#include <sys/spa.h>
#include <sys/autosnap.h>
#include <sys/dmu_objset.h>
#include <sys/dsl_dataset.h>
#include <sys/dsl_dir.h>
#include <sys/dsl_destroy.h>
#include <sys/unique.h>
#include <sys/ctype.h>

static void autosnap_notify_created(const char *name, uint64_t txg,
    autosnap_zone_t *zone);
static void autosnap_reject_snap(const char *name, uint64_t txg,
    zfs_autosnap_t *autosnap);

typedef struct {
	autosnap_handler_t *hdl;
	list_node_t node;
} autosnap_ref_t;

typedef struct {
	autosnap_zone_t *azone;
	dsl_sync_task_t *dst;
} autosnap_commit_cb_arg_t;

static void
autosnap_refcount_add(list_t *ref_cnt,
    autosnap_handler_t *owner)
{
	autosnap_ref_t *ref;

	ref = kmem_alloc(sizeof (autosnap_ref_t), KM_SLEEP);
	ref->hdl = owner;
	list_insert_tail(ref_cnt, ref);
}

static void
autosnap_refcount_remove(list_t *ref_cnt,
    autosnap_handler_t *owner)
{
	autosnap_ref_t *ref;

	ASSERT(!list_is_empty(ref_cnt));

	for (ref = list_head(ref_cnt); ref != NULL;
	    ref = list_next(ref_cnt, ref)) {
		if (ref->hdl == owner) {
			list_remove(ref_cnt, ref);
			kmem_free(ref, sizeof (autosnap_ref_t));

			return;
		}
	}

	/*
	 * FIXME: After merge of latest illumos code
	 * this will be removed with all autosnap_refcount_*
	 * All autosnap_refcount_*() calls will be replaced by
	 * the corresponding ref_counter_*()
	 */
	panic("No such hold %p", (void *)owner);
}

static void
autosnap_refcount_remove_all(list_t *ref_cnt)
{
	autosnap_ref_t *ref;

	while ((ref = list_head(ref_cnt)) != NULL) {
		list_remove(ref_cnt, ref);
		kmem_free(ref, sizeof (autosnap_ref_t));
	}
}

static boolean_t
autosnap_refcount_held(list_t *ref_cnt,
    autosnap_handler_t *owner)
{
	autosnap_ref_t *ref;

	for (ref = list_head(ref_cnt); ref != NULL;
	    ref = list_next(ref_cnt, ref)) {
		if (ref->hdl == owner)
			return (B_TRUE);
	}

	return (B_FALSE);
}

static boolean_t
autosnap_refcount_is_zero(list_t *ref_cnt)
{
	return (list_is_empty(ref_cnt));
}

/* AUTOSNAP-recollect routines */

static autosnap_snapshot_t *
autosnap_create_snap_node(const char *snap_name, uint64_t txg,
    uint64_t etxg, boolean_t recursive, boolean_t orphaned)
{
	autosnap_snapshot_t *snap_node;

	snap_node = kmem_zalloc(sizeof (autosnap_snapshot_t), KM_SLEEP);

	(void) strcpy(snap_node->name, snap_name);
	snap_node->recursive = recursive;
	snap_node->txg = txg;
	snap_node->etxg = etxg;
	snap_node->orphaned = orphaned;

	list_create(&snap_node->ref_cnt,
	    sizeof (autosnap_ref_t),
	    offsetof(autosnap_ref_t, node));

	return (snap_node);
}

/*
 * Callback for dmu_objset_find_dp().
 * This function is called for all DSs, but processes only
 * autosnaps.
 *
 * The constructed autosnap-structure is marked as "orphaned" and
 * placed to common AVL of autosnap
 */
/* ARGSUSED */
static int
autosnap_collect_orphaned_snapshots_cb(dsl_pool_t *dp,
    dsl_dataset_t *ds, void *arg)
{
	autosnap_zone_t *zone = arg;
	char snap_name[ZFS_MAX_DATASET_NAME_LEN];
	autosnap_snapshot_t *snap_node;
	uint64_t txg;

	if (!ds->ds_is_snapshot)
		return (0);

	dsl_dataset_name(ds, snap_name);
	if (!autosnap_check_name(strchr(snap_name, '@')))
		return (0);

	txg = dsl_dataset_phys(ds)->ds_creation_txg;
	snap_node = autosnap_create_snap_node(snap_name,
	    txg, txg, B_FALSE, B_TRUE);

	mutex_enter(&zone->avl_lock);
	avl_add(&zone->snapshots, snap_node);
	mutex_exit(&zone->avl_lock);

	return (0);
}

/*
 * Collect orphaned snapshots for given "ds_name" and all its
 * children if recursive is TRUE
 *
 * This function is called during registration of an autosnap-listener
 * The registration process can be initiated by
 *    - WBC that restores configuration when ZFS activates a pool
 *    - an user that has enabled WBC or KRRP for a dataset
 */
static void
autosnap_collect_orphaned_snapshots(spa_t *spa, autosnap_zone_t *zone)
{
	int flags = DS_FIND_SNAPSHOTS;
	dsl_pool_t *dp = spa_get_dsl(spa);
	dsl_dataset_t *ds = NULL;
	uint64_t dd_object;
	boolean_t held;


	/*
	 * If the top-level caller is ZFS that activates
	 * the given pool, then the pool's config already held
	 */
	held = dsl_pool_config_held(dp);
	if (!held)
		dsl_pool_config_enter(dp, FTAG);

	if (dsl_dataset_hold(dp, zone->dataset, FTAG, &ds) != 0)
		goto out;

	dd_object = ds->ds_dir->dd_object;
	dsl_dataset_rele(ds, FTAG);

	if ((zone->flags & AUTOSNAP_RECURSIVE) != 0)
		flags |= DS_FIND_CHILDREN;

	VERIFY0(dmu_objset_find_dp(spa_get_dsl(spa), dd_object,
	    autosnap_collect_orphaned_snapshots_cb, zone, flags));

out:
	if (!held)
		dsl_pool_config_exit(dp, FTAG);
}

/*
 * Return list of the snapshots which are owned by the caller
 * The function is used to reclaim orphaned snapshots
 */
nvlist_t *
autosnap_get_owned_snapshots(void *opaque)
{
	nvlist_t *dup;
	autosnap_snapshot_t *snap;
	autosnap_handler_t *hdl = opaque;
	autosnap_zone_t *zone = hdl->zone;
	zfs_autosnap_t *autosnap = zone->autosnap;

	if (!(hdl->flags & AUTOSNAP_OWNER))
		return (NULL);

	mutex_enter(&autosnap->autosnap_lock);

	dup = fnvlist_alloc();

	/* iterate though snapshots and find requested */
	for (snap = avl_first(&zone->snapshots);
	    snap != NULL;
	    snap = AVL_NEXT(&zone->snapshots, snap)) {
		char ds_name[MAXPATHLEN];
		uint64_t data[2];

		if (!snap->orphaned)
			continue;

		(void) strcpy(ds_name, snap->name);
		*(strchr(ds_name, '@')) = '\0';

		if (strcmp(ds_name, zone->dataset) != 0)
			continue;

		data[0] = snap->txg;
		data[1] = snap->recursive;

		fnvlist_add_uint64_array(dup, snap->name, data, 2);
		snap->orphaned = B_FALSE;
	}

	mutex_exit(&autosnap->autosnap_lock);

	return (dup);
}

/*
 * Insert owners handler to snapshots
 */
static void
autosnap_claim_orphaned_snaps(autosnap_handler_t *hdl)
{
	autosnap_zone_t *zone = hdl->zone;
	autosnap_snapshot_t *snap, *r_snap = NULL;

	ASSERT(MUTEX_HELD(&zone->autosnap->autosnap_lock));

	snap = avl_first(&zone->snapshots);

	while (snap != NULL) {
		char ds_name[ZFS_MAX_DATASET_NAME_LEN];
		autosnap_snapshot_t *next_snap =
		    AVL_NEXT(&zone->snapshots, snap);

		if (snap->orphaned) {
			(void) strcpy(ds_name, snap->name);
			*(strchr(ds_name, '@')) = '\0';

			if (strcmp(ds_name, zone->dataset) == 0) {
				autosnap_refcount_add(&snap->ref_cnt, hdl);
				r_snap = snap;
			} else if (strncmp(ds_name,
			    zone->dataset, strlen(zone->dataset)) == 0 &&
			    (hdl->flags & AUTOSNAP_RECURSIVE) &&
			    r_snap != NULL) {
				avl_remove(&zone->snapshots, snap);
				kmem_free(snap, sizeof (autosnap_snapshot_t));
				r_snap->recursive = B_TRUE;
			}
		}

		snap = next_snap;
	}
}

/* AUTOSNAP_RELE routines */

static void
autosnap_release_snapshots_by_txg_no_lock_impl(autosnap_handler_t *hdl,
    uint64_t from_txg, uint64_t to_txg, boolean_t destroy)
{
	autosnap_zone_t *zone = hdl->zone;
	zfs_autosnap_t *autosnap = zone->autosnap;
	avl_index_t where;
	int search_len;

	ASSERT(MUTEX_HELD(&autosnap->autosnap_lock));

	autosnap_snapshot_t search = { 0 };
	autosnap_snapshot_t *walker, *prev;

	search.txg = from_txg;
	(void) strcpy(search.name, zone->dataset);
	search_len = strlen(search.name);
	walker = avl_find(&zone->snapshots, &search, &where);

	if (walker == NULL) {
		walker = avl_nearest(&zone->snapshots,
		    where, AVL_AFTER);
	}

	if (walker == NULL)
		return;

	/* if we specifies only one txg then it must be present */
	if (to_txg == AUTOSNAP_NO_SNAP && walker->txg != from_txg)
		return;

	if (walker->txg < from_txg)
		walker = AVL_NEXT(&zone->snapshots, walker);

	if (walker->txg > to_txg)
		return;

	if (to_txg == AUTOSNAP_NO_SNAP)
		to_txg = from_txg;

	/* iterate over the specified range */
	do {
		boolean_t exact, pref, held = B_FALSE;

		if (strncmp(search.name, walker->name, search_len) == 0) {
			exact = (walker->name[search_len] == '@');
			pref = (walker->name[search_len] == '/');

			if (exact ||
			    (pref &&
			    (zone->flags & AUTOSNAP_RECURSIVE) != 0)) {
				held = autosnap_refcount_held(
				    &walker->ref_cnt, hdl);
			}
		}

		prev = walker;

		walker = AVL_NEXT(&zone->snapshots, walker);

		/*
		 * If client holds reference to the snapshot
		 * then remove it
		 */
		if (held) {
			autosnap_refcount_remove(&prev->ref_cnt, hdl);

			/*
			 * If it is the last reference and autosnap should
			 * not be destroyed then just free the structure.
			 * Otherwise put it on the destroyer's queue.
			 */
			if (autosnap_refcount_is_zero(&prev->ref_cnt)) {
				avl_remove(&zone->snapshots, prev);
				if (!destroy) {
					kmem_free(prev,
					    sizeof (autosnap_snapshot_t));
				} else {
					list_insert_tail(
					    &autosnap->autosnap_destroy_queue,
					    prev);
					cv_broadcast(&autosnap->autosnap_cv);
				}
			}
		}

	} while (walker != NULL && walker->txg <= to_txg);
}

/* No lock version should be used from autosnap callbacks */
void
autosnap_release_snapshots_by_txg_no_lock(void *opaque,
    uint64_t from_txg, uint64_t to_txg)
{
	autosnap_handler_t *hdl = opaque;

	autosnap_release_snapshots_by_txg_no_lock_impl(hdl,
	    from_txg, to_txg, B_TRUE);
}

/*
 * Release snapshot and remove a handler from it
 */
void
autosnap_release_snapshots_by_txg(void *opaque,
    uint64_t from_txg, uint64_t to_txg)
{
	autosnap_handler_t *hdl = opaque;
	autosnap_zone_t *zone = hdl->zone;
	mutex_enter(&zone->autosnap->autosnap_lock);
	autosnap_release_snapshots_by_txg_no_lock_impl(hdl,
	    from_txg, to_txg, B_TRUE);
	mutex_exit(&zone->autosnap->autosnap_lock);
}

static int
snapshot_txg_compare(const void *arg1, const void *arg2)
{
	const autosnap_snapshot_t *snap1 = arg1;
	const autosnap_snapshot_t *snap2 = arg2;

	if (snap1->txg < snap2->txg) {
		return (-1);
	} else if (snap1->txg == snap2->txg) {
		int res = 0;
		int l1 = strlen(snap1->name);
		int l2 = strlen(snap2->name);
		int i;

		/* we need our own strcmp to ensure depth-first order */
		for (i = 0; i <= MIN(l1, l2); i++) {
			char c1 = snap1->name[i];
			char c2 = snap2->name[i];

			if (c1 != c2) {
				if (c1 == '\0') {
					res = -1;
				} else if (c2 == '\0') {
					res = +1;
				} else if (c1 == '@') {
					res = -1;
				} else if (c2 == '@') {
					res = +1;
				} else if (c1 == '/') {
					res = -1;
				} else if (c2 == '/') {
					res = +1;
				} else if (c1 < c2) {
					res = -1;
				} else {
					res = +1;
				}
				break;
			}
		}

		if (res < 0) {
			return (-1);
		} else if (res > 0) {
			return (+1);
		} else {
			return (0);
		}
	} else {
		return (+1);
	}
}

/* AUTOSNAP-HDL routines */

void *
autosnap_register_handler_impl(spa_t *spa,
    const char *name, uint64_t flags,
    autosnap_confirm_cb confirm_cb,
    autosnap_notify_created_cb nc_cb,
    autosnap_error_cb err_cb, void *cb_arg)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);
	autosnap_handler_t *hdl = NULL;
	autosnap_zone_t *zone, *rzone;
	boolean_t children_have_zone;


	mutex_enter(&autosnap->autosnap_lock);
	while (autosnap->register_busy) {
		(void) cv_wait(&autosnap->autosnap_cv,
		    &autosnap->autosnap_lock);
	}

	zone = autosnap_find_zone(autosnap, name, B_FALSE);
	rzone = autosnap_find_zone(autosnap, name, B_TRUE);

	children_have_zone =
	    autosnap_has_children_zone(autosnap, name, B_FALSE);

	if (rzone && !zone) {
		cmn_err(CE_WARN, "AUTOSNAP: the dataset is already under"
		    " an autosnap zone [%s under %s]\n",
		    name, rzone->dataset);
		goto out;
	} else if (children_have_zone && (flags & AUTOSNAP_RECURSIVE)) {
		cmn_err(CE_WARN, "AUTOSNAP: can't register recursive zone"
		    " when there is a child under autosnap%s\n",
		    name);
		goto out;
	}

	/* Create a new zone if it is absent */
	if (zone == NULL) {
		zone = kmem_zalloc(sizeof (autosnap_zone_t), KM_SLEEP);
		(void) strcpy(zone->dataset, name);

		mutex_init(&zone->avl_lock, NULL, MUTEX_ADAPTIVE, NULL);

		list_create(&zone->listeners,
		    sizeof (autosnap_handler_t),
		    offsetof(autosnap_handler_t, node));

		avl_create(&zone->snapshots,
		    snapshot_txg_compare,
		    sizeof (autosnap_snapshot_t),
		    offsetof(autosnap_snapshot_t, node));

		zone->flags = flags;
		zone->autosnap = autosnap;

		/*
		 * This is a new zone and we need to collect orphaned
		 * snapshots for it. It is safe to drop autosnap_lock,
		 * because the zone is not on the list of available
		 * zones.
		 * Disallow registering a handler until the process
		 * is finished.
		 */
		autosnap->register_busy = B_TRUE;
		mutex_exit(&autosnap->autosnap_lock);

		autosnap_collect_orphaned_snapshots(spa, zone);

		mutex_enter(&autosnap->autosnap_lock);
		cv_broadcast(&autosnap->autosnap_cv);
		autosnap->register_busy = B_FALSE;

		list_insert_tail(&autosnap->autosnap_zones, zone);
	} else {
		if ((list_head(&zone->listeners) != NULL) &&
		    ((flags & AUTOSNAP_CREATOR) ^
		    (zone->flags & AUTOSNAP_CREATOR))) {
			cmn_err(CE_WARN,
			    "AUTOSNAP: can't register two different"
			    " modes for the same autosnap zone %s %s\n",
			    name, flags & AUTOSNAP_RECURSIVE ? "[r]" : "");
			goto out;
		} else if ((list_head(&zone->listeners) != NULL) &&
		    ((flags & AUTOSNAP_RECURSIVE) ^
		    (zone->flags & AUTOSNAP_RECURSIVE))) {
			cmn_err(CE_WARN,
			    "AUTOSNAP: can't register two different"
			    " recursion modes for the same autosnap zone "
			    "%s %s\n",
			    name, flags & AUTOSNAP_RECURSIVE ? "[r]" : "");
			goto out;
		}

		zone->flags |= flags;
	}

	hdl = kmem_zalloc(sizeof (autosnap_handler_t), KM_SLEEP);

	hdl->confirm_cb = confirm_cb;
	hdl->nc_cb = nc_cb;
	hdl->err_cb = err_cb;
	hdl->cb_arg = cb_arg;
	hdl->zone = zone;
	hdl->flags = flags;

	list_insert_tail(&zone->listeners, hdl);

	if (flags & AUTOSNAP_OWNER)
		autosnap_claim_orphaned_snaps(hdl);

out:
	mutex_exit(&autosnap->autosnap_lock);

	return (hdl);
}

void *
autosnap_register_handler(const char *name, uint64_t flags,
    autosnap_confirm_cb confirm_cb,
    autosnap_notify_created_cb nc_cb,
    autosnap_error_cb err_cb, void *cb_arg)
{
	spa_t *spa;
	autosnap_handler_t *hdl = NULL;
	boolean_t namespace_alteration = B_TRUE;

	if (nc_cb == NULL)
		return (NULL);

	/* special case for unregistering on deletion */
	if (!MUTEX_HELD(&spa_namespace_lock)) {
		mutex_enter(&spa_namespace_lock);
		namespace_alteration = B_FALSE;
	}

	spa = spa_lookup(name);
	if (spa != NULL)
		spa_open_ref(spa, FTAG);

	if (!namespace_alteration)
		mutex_exit(&spa_namespace_lock);

	if (spa == NULL)
		return (NULL);

	hdl = autosnap_register_handler_impl(spa,
	    name, flags, confirm_cb, nc_cb, err_cb, cb_arg);

	spa_close(spa, FTAG);

	return (hdl);
}

void
autosnap_unregister_handler(void *opaque)
{
	spa_t *spa;
	autosnap_handler_t *hdl = opaque;
	autosnap_zone_t *zone = hdl->zone;
	zfs_autosnap_t *autosnap = NULL;
	boolean_t namespace_alteration = B_TRUE;

	/* special case for unregistering on deletion */
	if (!MUTEX_HELD(&spa_namespace_lock)) {
		mutex_enter(&spa_namespace_lock);
		namespace_alteration = B_FALSE;
	}

	spa = spa_lookup(zone->dataset);
	if (spa != NULL)
		spa_open_ref(spa, FTAG);

	if (!namespace_alteration)
		mutex_exit(&spa_namespace_lock);

	/* if zone is absent, then just destroy handler */
	if (spa == NULL)
		goto free_hdl;

	autosnap = spa_get_autosnap(spa);

	mutex_enter(&autosnap->autosnap_lock);

	autosnap_release_snapshots_by_txg_no_lock_impl(hdl,
	    AUTOSNAP_FIRST_SNAP, AUTOSNAP_LAST_SNAP, B_FALSE);

	/*
	 * Remove the client from zone. If it is a last client
	 * then destroy the zone.
	 */
	if (zone != NULL) {
		list_remove(&zone->listeners, hdl);

		if (list_head(&zone->listeners) == NULL) {
			void *cookie = NULL;
			autosnap_snapshot_t *snap;

			while ((snap = avl_destroy_nodes(&zone->snapshots,
			    &cookie)) != NULL) {
				/*
				 * Only orphans can be in
				 * the AVL-tree at this stage
				 */
				VERIFY(snap->orphaned);
				VERIFY(autosnap_refcount_is_zero(
				    &snap->ref_cnt));
				kmem_free(snap, sizeof (autosnap_snapshot_t));
			}

			avl_destroy(&zone->snapshots);
			mutex_destroy(&zone->avl_lock);
			list_remove(&autosnap->autosnap_zones, zone);
			list_destroy(&zone->listeners);
			kmem_free(zone, sizeof (autosnap_zone_t));
		} else {
			autosnap_handler_t *walk;
			boolean_t drop_owner_flag = B_TRUE;
			boolean_t drop_krrp_flag = B_TRUE;

			for (walk = list_head(&zone->listeners);
			    walk != NULL;
			    walk = list_next(&zone->listeners, walk)) {
				if ((walk->flags & AUTOSNAP_OWNER) != 0)
					drop_owner_flag = B_FALSE;

				if ((walk->flags & AUTOSNAP_KRRP) != 0)
					drop_krrp_flag = B_FALSE;
			}

			if (drop_owner_flag)
				zone->flags &= ~AUTOSNAP_OWNER;

			if (drop_krrp_flag)
				zone->flags &= ~AUTOSNAP_KRRP;
		}
	}

free_hdl:
	kmem_free(hdl, sizeof (autosnap_handler_t));

out:
	if (spa != NULL) {
		spa_close(spa, FTAG);
		mutex_exit(&autosnap->autosnap_lock);
	}
}

int
autosnap_check_for_destroy(zfs_autosnap_t *autosnap, const char *name)
{
	autosnap_zone_t *rzone, *zone;
	boolean_t children_have_zone;

	mutex_enter(&autosnap->autosnap_lock);
	zone = autosnap_find_zone(autosnap, name, B_FALSE);
	rzone = autosnap_find_zone(autosnap, name, B_TRUE);
	children_have_zone =
	    autosnap_has_children_zone(autosnap, name, B_TRUE);
	mutex_exit(&autosnap->autosnap_lock);

	if (zone != NULL && (zone->flags & AUTOSNAP_KRRP) != 0)
		return (EBUSY);

	if (children_have_zone)
		return (ECHILD);

	if (rzone != NULL && (rzone->flags & AUTOSNAP_KRRP) != 0)
		return (EUSERS);

	return (0);
}

boolean_t
autosnap_has_children_zone(zfs_autosnap_t *autosnap,
    const char *name, boolean_t krrp_only)
{
	autosnap_zone_t *zone;
	char dataset[MAXPATHLEN];
	char *snapshot;
	size_t ds_name_len;

	ASSERT(MUTEX_HELD(&autosnap->autosnap_lock));

	(void) strcpy(dataset, name);
	if ((snapshot = strchr(dataset, '@')) != NULL)
		*snapshot++ = '\0';

	ds_name_len = strlen(dataset);
	zone = list_head(&autosnap->autosnap_zones);
	while (zone != NULL) {
		int cmp = strncmp(dataset,
		    zone->dataset, ds_name_len);
		boolean_t skip =
		    krrp_only && ((zone->flags & AUTOSNAP_KRRP) == 0);
		if (cmp == 0 && zone->dataset[ds_name_len] == '/' &&
		    !skip)
			return (B_TRUE);

		zone = list_next(&autosnap->autosnap_zones, zone);
	}

	return (B_FALSE);
}

autosnap_zone_t *
autosnap_find_zone(zfs_autosnap_t *autosnap,
    const char *name, boolean_t recursive)
{
	char dataset[MAXPATHLEN];
	char *snapshot;
	autosnap_zone_t *zone;

	ASSERT(MUTEX_HELD(&autosnap->autosnap_lock));

	(void) strcpy(dataset, name);
	if ((snapshot = strchr(dataset, '@')) != NULL)
		*snapshot++ = '\0';

	zone = list_head(&autosnap->autosnap_zones);
	while (zone != NULL) {
		if (strcmp(dataset, zone->dataset) == 0) {
			return (zone);
		} else if (recursive) {
			size_t ds_name_len = strlen(zone->dataset);
			int cmp = strncmp(dataset, zone->dataset,
			    ds_name_len);
			boolean_t zone_is_recursive =
			    zone->flags & AUTOSNAP_RECURSIVE;
			if (cmp == 0 && zone_is_recursive &&
			    dataset[ds_name_len] == '/')
				return (zone);
		}

		zone = list_next(&autosnap->autosnap_zones, zone);
	}

	return (NULL);
}

/* AUTOSNAP-LOCK routines */

/*
 * This function is used to serialize atomically-destroy
 * and start a KRRP replication session (send side).
 *
 * Atomically-destroy logic allows a DS and nested DSs
 * to be destroyed in one TXG.
 *
 * This function uses RW_LOCK, so multiple KRRP replication
 * sessions may start in parallel. However atomically-destroy
 * is a writer, so KRRP replication sessions will wait until it
 * finished.
 *
 * if pool export or destroy are in process then the function
 * will not hold anything and return ENOLCK.
 *
 * In case of receiving kill-signal (if the function was called
 * from an ioctl handler) the function returns EINTR.
 */
int
autosnap_lock(spa_t *spa, krw_t rw)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);
	int err = 0;
	int locked = 0;

	mutex_enter(&autosnap->autosnap_lock);

	locked = rw_tryenter(&autosnap->autosnap_rwlock, rw);
	while (locked == 0 && !autosnap->need_stop) {
#ifdef _KERNEL
		int rc = cv_wait_sig(&autosnap->autosnap_cv,
		    &autosnap->autosnap_lock);
		if (rc == 0)
			break;
#else
		(void) cv_wait(&autosnap->autosnap_cv,
		    &autosnap->autosnap_lock);
#endif

		locked = rw_tryenter(&autosnap->autosnap_rwlock, rw);
	}

	if (autosnap->need_stop) {
		err = SET_ERROR(ENOLCK);
		if (locked != 0)
			rw_exit(&autosnap->autosnap_rwlock);
	} else if (locked == 0) {
		err = SET_ERROR(EINTR);
	}

	cv_broadcast(&autosnap->autosnap_cv);
	mutex_exit(&autosnap->autosnap_lock);

	return (err);
}

void
autosnap_unlock(spa_t *spa)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);

	rw_exit(&autosnap->autosnap_rwlock);
}

/* AUTOSNAP-FSNAP routines */

void
autosnap_exempt_snapshot(spa_t *spa, const char *name)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);
	autosnap_zone_t *zone;
	uint64_t txg;
	int err;
	dsl_dataset_t *ds;
	autosnap_snapshot_t search = { 0 }, *found;
	char *atpos;

	err = dsl_dataset_hold(spa_get_dsl(spa), name, FTAG, &ds);
	if (err != 0)
		return;

	txg = dsl_dataset_phys(ds)->ds_creation_txg;
	dsl_dataset_rele(ds, FTAG);

	mutex_enter(&autosnap->autosnap_lock);

	(void) strcpy(search.name, name);
	atpos = strchr(search.name, '@');
	*atpos = '\0';

	zone = autosnap_find_zone(autosnap, search.name, B_TRUE);
	if (zone != NULL) {
		*atpos = '@';
		search.txg = txg;

		found = avl_find(&zone->snapshots, &search, NULL);
		if (found != NULL) {
			avl_remove(&zone->snapshots, found);
			autosnap_refcount_remove_all(&found->ref_cnt);
			kmem_free(found, sizeof (autosnap_snapshot_t));
		}
	}

	mutex_exit(&autosnap->autosnap_lock);
}

void
autosnap_force_snap_by_name(const char *dsname, autosnap_zone_t *zone,
    boolean_t sync)
{
	dsl_pool_t *dp;
	dsl_dataset_t *ds;
	objset_t *os;
	uint64_t txg = 0;
	zfs_autosnap_t *autosnap;
	int error;

	error = dsl_pool_hold(dsname, FTAG, &dp);
	if (error)
		return;

	autosnap = spa_get_autosnap(dp->dp_spa);
	if (!autosnap) {
		dsl_pool_rele(dp, FTAG);
		return;
	}

	mutex_enter(&autosnap->autosnap_lock);
	if (zone == NULL) {
		zone = autosnap_find_zone(autosnap, dsname, B_TRUE);
		if (zone == NULL) {
			mutex_exit(&autosnap->autosnap_lock);
			dsl_pool_rele(dp, FTAG);
			return;
		}
	}

	error = dsl_dataset_hold(dp, dsname, FTAG, &ds);
	if (error) {
		mutex_exit(&autosnap->autosnap_lock);
		dsl_pool_rele(dp, FTAG);
		return;
	}
	error = dmu_objset_from_ds(ds, &os);
	if (error) {
		dsl_dataset_rele(ds, FTAG);
		mutex_exit(&autosnap->autosnap_lock);
		dsl_pool_rele(dp, FTAG);
		return;
	}
	if (dmu_objset_is_snapshot(os)) {
		dsl_dataset_rele(ds, FTAG);
		mutex_exit(&autosnap->autosnap_lock);
		dsl_pool_rele(dp, FTAG);
		return;
	}

	dsl_pool_rele(dp, FTAG);

	if (zone->flags & AUTOSNAP_CREATOR) {
		dmu_tx_t *tx = dmu_tx_create(os);

		error = dmu_tx_assign(tx, TXG_NOWAIT);

		if (error) {
			dmu_tx_abort(tx);
			dsl_dataset_rele(ds, FTAG);
			mutex_exit(&autosnap->autosnap_lock);
			return;
		}

		txg = dmu_tx_get_txg(tx);
		dsl_dataset_dirty(ds, tx);
		dmu_tx_commit(tx);
	}

	dsl_dataset_rele(ds, FTAG);
	mutex_exit(&autosnap->autosnap_lock);

	if (sync)
		txg_wait_synced(dp, txg);
}

/* Force creation of an autosnap */
void
autosnap_force_snap(void *opaque, boolean_t sync)
{
	autosnap_handler_t *hdl;
	autosnap_zone_t *zone;

	if (!opaque)
		return;

	hdl = opaque;
	zone = hdl->zone;

	autosnap_force_snap_by_name(zone->dataset, zone, sync);
}

/*
 * This function is called when the caller wants snapshot ASAP
 */
void
autosnap_force_snap_fast(void *opaque)
{
	autosnap_handler_t *hdl = opaque;
	autosnap_zone_t *zone = hdl->zone;

	mutex_enter(&zone->autosnap->autosnap_lock);

	/*
	 * Mark this autosnap zone as "delayed", so that autosnap
	 * for this zone is created in the next TXG sync
	 */
	zone->delayed = B_TRUE;

	mutex_exit(&zone->autosnap->autosnap_lock);
}

/* AUTOSNAP-NOTIFIER routines */

/* iterate through handlers and call its confirm callbacks */
boolean_t
autosnap_confirm_snap(autosnap_zone_t *zone, uint64_t txg)
{
	autosnap_handler_t *hdl;
	boolean_t confirmation = B_FALSE;

	if ((zone->flags & AUTOSNAP_CREATOR) == 0)
		return (B_FALSE);

	for (hdl = list_head(&zone->listeners);
	    hdl != NULL;
	    hdl = list_next(&zone->listeners, hdl)) {
		confirmation |=
		    hdl->confirm_cb == NULL ? B_TRUE :
		    hdl->confirm_cb(zone->dataset,
		    !!(zone->flags & AUTOSNAP_RECURSIVE),
		    txg, hdl->cb_arg);
	}

	return (confirmation);
}

/* iterate through handlers and call its error callbacks */
void
autosnap_error_snap(autosnap_zone_t *zone, uint64_t txg, int err)
{
	autosnap_handler_t *hdl;

	ASSERT(MUTEX_HELD(&zone->autosnap->autosnap_lock));

	for (hdl = list_head(&zone->listeners);
	    hdl != NULL;
	    hdl = list_next(&zone->listeners, hdl)) {
		if (hdl->err_cb)
			hdl->err_cb(zone->dataset, err, txg, hdl->cb_arg);
	}
}

/* iterate through handlers and call its notify callbacks */
static void
autosnap_notify_listeners(autosnap_zone_t *zone,
    autosnap_snapshot_t *snap)
{
	autosnap_handler_t *hdl;

	for (hdl = list_head(&zone->listeners);
	    hdl != NULL;
	    hdl = list_next(&zone->listeners, hdl)) {
		if (hdl->nc_cb(snap->name,
		    !!(zone->flags & AUTOSNAP_RECURSIVE),
		    B_TRUE, snap->txg, snap->etxg, hdl->cb_arg))
			autosnap_refcount_add(&snap->ref_cnt, hdl);
	}
}

/*
 * With no WBC and a dataset which is either a standalone or root of
 * recursion, just notify about creation
 * With no WBC and dataset not being a part of any zone, just reject it
 */
void
autosnap_create_cb(zfs_autosnap_t *autosnap,
    dsl_dataset_t *ds, const char *snapname, uint64_t txg)
{
	autosnap_zone_t *zone, *rzone;
	char fullname[MAXNAMELEN];

	dsl_dataset_name(ds, fullname);

	mutex_enter(&autosnap->autosnap_lock);
	zone = autosnap_find_zone(autosnap, fullname, B_FALSE);
	rzone = autosnap_find_zone(autosnap, fullname, B_TRUE);

	(void) strcat(fullname, "@");
	(void) strcat(fullname, snapname);

	if (zone != NULL) {
		/*
		 * Some listeners subscribed for this datasets.
		 * So need to notify them about new snapshot
		 */
		autosnap_notify_created(fullname, txg, zone);
	} else if (!rzone) {
		/*
		 * There are no listeners for this datasets
		 * and its children. So this snapshot is not
		 * needed anymore.
		 */
		autosnap_reject_snap(fullname, txg, autosnap);
	}

	mutex_exit(&autosnap->autosnap_lock);
}

/* Notify listeners about an autosnapshot */
static void
autosnap_notify_created(const char *name, uint64_t txg,
    autosnap_zone_t *zone)
{
	autosnap_snapshot_t *snapshot = NULL, search;
	avl_index_t where = NULL;
	boolean_t found = B_TRUE;

	ASSERT(MUTEX_HELD(&zone->autosnap->autosnap_lock));

#ifdef ZFS_DEBUG
	VERIFY(autosnap_check_name(strchr(name, '@')));
#endif

	search.txg = txg;
	(void) strcpy(search.name, name);
	snapshot = avl_find(&zone->snapshots, &search, &where);
	if (snapshot == NULL) {
		found = B_FALSE;
		snapshot = autosnap_create_snap_node(name, txg, txg,
		    !!(zone->flags & AUTOSNAP_RECURSIVE), B_FALSE);
	}

	autosnap_notify_listeners(zone, snapshot);

	if ((zone->flags & AUTOSNAP_DESTROYER) != 0) {
		if (list_is_empty(&snapshot->ref_cnt)) {
			list_insert_tail(
			    &zone->autosnap->autosnap_destroy_queue, snapshot);
			cv_broadcast(&zone->autosnap->autosnap_cv);
		} else if (!found) {
			avl_insert(&zone->snapshots, snapshot, where);
		}
	} else if (!found) {
		kmem_free(snapshot, sizeof (autosnap_snapshot_t));
	}
}

/* Reject a creation of an autosnapshot */
static void
autosnap_reject_snap(const char *name, uint64_t txg, zfs_autosnap_t *autosnap)
{
	autosnap_snapshot_t *snapshot = NULL;

	ASSERT(MUTEX_HELD(&autosnap->autosnap_lock));

#ifdef ZFS_DEBUG
	VERIFY(autosnap_check_name(strchr(name, '@')));
#endif

	snapshot = autosnap_create_snap_node(name, txg, txg, B_FALSE, B_FALSE);

	list_insert_tail(&autosnap->autosnap_destroy_queue, snapshot);
	cv_broadcast(&autosnap->autosnap_cv);
}

/* AUTOSNAP-DESTROYER routines */

/* Collect snapshots for destroy */
static int
dsl_pool_collect_ds_for_autodestroy(spa_t *spa, const char *root_ds,
    const char *snap_name, boolean_t recursive, nvlist_t *nv_auto)
{
	list_t ds_to_send;
	zfs_ds_collector_entry_t *el;
	dsl_pool_t *dp = spa_get_dsl(spa);
	int err;

	list_create(&ds_to_send, sizeof (zfs_ds_collector_entry_t),
	    offsetof(zfs_ds_collector_entry_t, node));

	dsl_pool_config_enter(dp, FTAG);
	err = zfs_collect_ds(spa, root_ds, recursive, B_FALSE, &ds_to_send);
	dsl_pool_config_exit(dp, FTAG);

	for (el = list_head(&ds_to_send);
	    err == 0 && el != NULL;
	    el = list_head(&ds_to_send)) {
		if (!err) {
			(void) strcat(el->name, "@");
			(void) strcat(el->name, snap_name);

			err = nvlist_add_boolean(nv_auto, el->name);
		}

		(void) list_remove_head(&ds_to_send);
		dsl_dataset_collector_cache_free(el);
	}
	list_destroy(&ds_to_send);

	return (err);
}

void
autosnap_destroyer_thread(void *void_spa)
{
	spa_t *spa = void_spa;
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);

	mutex_enter(&autosnap->autosnap_lock);
	while (!autosnap->need_stop) {
		nvlist_t *nvl, *errlist;
		autosnap_snapshot_t *snapshot;
		char ds[ZFS_MAX_DATASET_NAME_LEN];
		char *snap;
		int err;

		snapshot = list_head(&autosnap->autosnap_destroy_queue);
		if (snapshot == NULL) {
			cv_wait(&autosnap->autosnap_cv,
			    &autosnap->autosnap_lock);
			continue;
		}

		(void) strlcpy(ds, snapshot->name, sizeof (ds));
		snap = strchr(ds, '@');
		VERIFY(snap != NULL);
		*snap++ = '\0';

		mutex_exit(&autosnap->autosnap_lock);

		nvl = fnvlist_alloc();
		err = dsl_pool_collect_ds_for_autodestroy(spa, ds, snap,
		    snapshot->recursive, nvl);

		mutex_enter(&autosnap->autosnap_lock);
		if (err != 0) {
			fnvlist_free(nvl);
			continue;
		}

		/*
		 * remove it from the queue for now.
		 * will add it back to the tail of the queue
		 * if destroy fails
		 */
		list_remove(&autosnap->autosnap_destroy_queue, snapshot);
		mutex_exit(&autosnap->autosnap_lock);

		errlist = fnvlist_alloc();
		err = dsl_destroy_snapshots_nvl(nvl, B_TRUE, errlist);
		fnvlist_free(errlist);
		fnvlist_free(nvl);

		if (err == 0)
			kmem_free(snapshot, sizeof (autosnap_snapshot_t));

		mutex_enter(&autosnap->autosnap_lock);

		if (err != 0) {
			list_insert_tail(&autosnap->autosnap_destroy_queue,
			    snapshot);
		}
	}

	autosnap->destroyer = NULL;
	cv_broadcast(&autosnap->autosnap_cv);
	mutex_exit(&autosnap->autosnap_lock);
}

void
autosnap_destroyer_thread_start(spa_t *spa)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);

	mutex_enter(&autosnap->autosnap_lock);
	autosnap->need_stop = B_FALSE;
	cv_broadcast(&autosnap->autosnap_cv);
	mutex_exit(&autosnap->autosnap_lock);

	autosnap->destroyer = thread_create(NULL, 32 << 10,
	    autosnap_destroyer_thread, spa, 0, &p0,
	    TS_RUN, minclsyspri);
}

void
autosnap_destroyer_thread_stop(spa_t *spa)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);

	if (!autosnap->initialized)
		return;

	mutex_enter(&autosnap->autosnap_lock);
	if (autosnap->need_stop || autosnap->destroyer == NULL) {
		mutex_exit(&autosnap->autosnap_lock);
		return;
	}

	autosnap->need_stop = B_TRUE;
	cv_broadcast(&autosnap->autosnap_cv);
	while (autosnap->destroyer != NULL)
		cv_wait(&autosnap->autosnap_cv, &autosnap->autosnap_lock);

	mutex_exit(&autosnap->autosnap_lock);
}

/* AUTOSNAP-INIT routines */

void
autosnap_init(spa_t *spa)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);
	mutex_init(&autosnap->autosnap_lock, NULL, MUTEX_ADAPTIVE, NULL);
	cv_init(&autosnap->autosnap_cv, NULL, CV_DEFAULT, NULL);
	rw_init(&autosnap->autosnap_rwlock, NULL, RW_DEFAULT, NULL);
	list_create(&autosnap->autosnap_zones, sizeof (autosnap_zone_t),
	    offsetof(autosnap_zone_t, node));
	list_create(&autosnap->autosnap_destroy_queue,
	    sizeof (autosnap_snapshot_t),
	    offsetof(autosnap_snapshot_t, dnode));
	autosnap->need_stop = B_FALSE;

#ifdef _KERNEL
	autosnap_destroyer_thread_start(spa);
#endif

	autosnap->initialized = B_TRUE;
}

void
autosnap_fini(spa_t *spa)
{
	zfs_autosnap_t *autosnap = spa_get_autosnap(spa);
	autosnap_zone_t *zone;
	autosnap_handler_t *hdl;
	autosnap_snapshot_t *snap;

	if (!autosnap->initialized)
		return;

	rw_enter(&autosnap->autosnap_rwlock, RW_WRITER);

	if (autosnap->destroyer)
		autosnap_destroyer_thread_stop(spa);

	autosnap->initialized = B_FALSE;

	while ((zone = list_head(&autosnap->autosnap_zones)) != NULL) {
		while ((hdl = list_head(&zone->listeners)) != NULL)
			autosnap_unregister_handler(hdl);
	}

	while ((snap =
	    list_remove_head(&autosnap->autosnap_destroy_queue)) != NULL)
		kmem_free(snap, sizeof (*snap));
	list_destroy(&autosnap->autosnap_destroy_queue);
	list_destroy(&autosnap->autosnap_zones);

	rw_exit(&autosnap->autosnap_rwlock);
	rw_destroy(&autosnap->autosnap_rwlock);
	mutex_destroy(&autosnap->autosnap_lock);
	cv_destroy(&autosnap->autosnap_cv);
}

boolean_t
autosnap_is_autosnap(dsl_dataset_t *ds)
{
	char ds_name[MAXNAMELEN];

	ASSERT(ds != NULL && ds->ds_is_snapshot);

	dsl_dataset_name(ds, ds_name);
	return (autosnap_check_name(strchr(ds_name, '@')));
}

/*
 * Returns B_TRUE if the given name is the name of an autosnap
 * otherwise B_FASLE
 *
 * the name of an autosnap matches the following regexp:
 *
 * /^@?AUTOSNAP_PREFIX\d+$/
 */
boolean_t
autosnap_check_name(const char *snap_name)
{
	size_t len, i = AUTOSNAP_PREFIX_LEN;

	ASSERT(snap_name != NULL);

	if (snap_name[0] == '@')
		snap_name++;

	len = strlen(snap_name);
	if (AUTOSNAP_PREFIX_LEN > len ||
	    strncmp(snap_name, AUTOSNAP_PREFIX,
	    AUTOSNAP_PREFIX_LEN) != 0)
		return (B_FALSE);

	while (i < len) {
		if (!isdigit(snap_name[i]))
			return (B_FALSE);

		i++;
	}

	return (B_TRUE);
}

/*
 * This function will called upon TX-group commit.
 * Here we free allocated structures and notify
 * the listeners of the corresponding autosnap-zone
 * about error
 */
static void
autosnap_commit_cb(void *dcb_data, int error)
{
	autosnap_commit_cb_arg_t *cb_arg = dcb_data;
	autosnap_zone_t *azone = cb_arg->azone;
	zfs_autosnap_t *autosnap = azone->autosnap;
	dsl_sync_task_t *dst = cb_arg->dst;
	dsl_dataset_snapshot_arg_t *ddsa = dst->dst_arg;

	VERIFY(ddsa->ddsa_autosnap);

	/*
	 * TX-group was processed, but some error
	 * occured on check-stage. This means that
	 * the requested autosnaps were not created
	 * and we need inform listeners about this
	 */
	if (error == 0 && dst->dst_error != 0) {
		mutex_enter(&autosnap->autosnap_lock);
		autosnap_error_snap(azone, dst->dst_txg, dst->dst_error);
		mutex_exit(&autosnap->autosnap_lock);
	}

	spa_close(dst->dst_pool->dp_spa, cb_arg);

	nvlist_free(ddsa->ddsa_snaps);
	kmem_free(ddsa, sizeof (dsl_dataset_snapshot_arg_t));
	kmem_free(dst, sizeof (dsl_sync_task_t));
	kmem_free(cb_arg, sizeof (autosnap_commit_cb_arg_t));
}

/* Collect datasets with a given param and create a snapshoting synctask */
#define	AUTOSNAP_COLLECTOR_BUSY_LIMIT (1000)
static int
dsl_pool_collect_ds_for_autosnap(dsl_pool_t *dp, uint64_t txg,
    const char *root_ds, const char *snap_name, boolean_t recursive,
    dmu_tx_t *tx, dsl_sync_task_t **dst_res)
{
	spa_t *spa = dp->dp_spa;
	dsl_dataset_t *ds;
	list_t ds_to_send;
	zfs_ds_collector_entry_t *el;
	nvlist_t *nv_auto;
	int err;
	int busy_counter = 0;

	nv_auto = fnvlist_alloc();

	list_create(&ds_to_send, sizeof (zfs_ds_collector_entry_t),
	    offsetof(zfs_ds_collector_entry_t, node));

	while ((err = zfs_collect_ds(spa, root_ds, recursive,
	    B_FALSE, &ds_to_send)) == EBUSY &&
	    busy_counter++ < AUTOSNAP_COLLECTOR_BUSY_LIMIT)
		delay(NSEC_TO_TICK(100));

	if (err != 0) {
		list_destroy(&ds_to_send);
		nvlist_free(nv_auto);
		return (err);
	}

	while ((el = list_head(&ds_to_send)) != NULL) {
		boolean_t len_ok =
		    (strlen(el->name) + strlen(snap_name) + 1) < MAXNAMELEN;
		if (err == 0 && !len_ok)
			err = ENAMETOOLONG;

		if (err == 0)
			err = dsl_dataset_hold(dp, el->name, FTAG, &ds);

		if (err == 0) {
			err = dsl_dataset_snapshot_check_impl(ds,
			    snap_name, tx, B_FALSE, 0, NULL);
			dsl_dataset_rele(ds, FTAG);
		}

		if (err == 0) {
			(void) strcat(el->name, "@");
			(void) strcat(el->name, snap_name);

			fnvlist_add_boolean(nv_auto, el->name);
		}

		(void) list_remove_head(&ds_to_send);
		dsl_dataset_collector_cache_free(el);
	}

	list_destroy(&ds_to_send);

	if (err == 0) {
		dsl_sync_task_t *dst =
		    kmem_zalloc(sizeof (dsl_sync_task_t), KM_SLEEP);
		dsl_dataset_snapshot_arg_t *ddsa =
		    kmem_zalloc(sizeof (dsl_dataset_snapshot_arg_t), KM_SLEEP);
		ddsa->ddsa_autosnap = B_TRUE;
		ddsa->ddsa_snaps = nv_auto;
		ddsa->ddsa_cr = CRED();
		dst->dst_pool = dp;
		dst->dst_txg = txg;
		dst->dst_space = 3 << DST_AVG_BLKSHIFT;
		dst->dst_checkfunc = dsl_dataset_snapshot_check;
		dst->dst_syncfunc = dsl_dataset_snapshot_sync;
		dst->dst_arg = ddsa;
		dst->dst_error = 0;
		dst->dst_nowaiter = B_FALSE;
		VERIFY(txg_list_add_tail(&dp->dp_sync_tasks,
		    dst, dst->dst_txg));
		*dst_res = dst;
	} else {
		nvlist_free(nv_auto);
	}

	return (err);
}

/*
 * This function is called from dsl_pool_sync() during
 * the walking autosnap-zone that have confirmed the creation
 * of autosnapshot.
 * Here we try to create autosnap for the given autosnap-zone
 * and notify the listeners of the zone in case of an error
 */
void
autosnap_create_snapshot(autosnap_zone_t *azone, char *snap,
    dsl_pool_t *dp, uint64_t txg, dmu_tx_t *tx)
{
	int err;
	boolean_t recurs;
	dsl_sync_task_t *dst = NULL;

	ASSERT(MUTEX_HELD(&azone->autosnap->autosnap_lock));

	ASSERT(!azone->created);

	recurs = !!(azone->flags & AUTOSNAP_RECURSIVE);
	err = dsl_pool_collect_ds_for_autosnap(dp, txg,
	    azone->dataset, snap, recurs, tx, &dst);
	if (err == 0) {
		autosnap_commit_cb_arg_t *cb_arg;

		azone->created = B_TRUE;
		azone->delayed = B_FALSE;
		azone->dirty = B_FALSE;

		/*
		 * Autosnap service works asynchronously, so to free
		 * allocated memory and delivery sync-task errors we register
		 * TX-callback that will be called after sync of the whole
		 * TX-group
		 */
		cb_arg = kmem_alloc(sizeof (autosnap_commit_cb_arg_t),
		    KM_SLEEP);
		cb_arg->azone = azone;
		cb_arg->dst = dst;
		dmu_tx_callback_register(tx, autosnap_commit_cb, cb_arg);

		/*
		 * To avoid early spa_fini increase spa_refcount,
		 * because TX-commit callbacks are executed asynchronously.
		 */
		spa_open_ref(dp->dp_spa, cb_arg);
	} else {
		autosnap_error_snap(azone, txg, err);
	}
}

/*
 * This function is called from dsl_dataset_snapshot_check() before
 * any other checks.
 *
 * It is possible to destroy datasets and attempt to create recursive
 * autosnapshots for the destroyed datasets in the same TXG. In such cases
 * autosnap sync-task will fail. To avoid this, the function puts a hold
 * on the datasets used for autosnapshots. The datasets names to be held
 * are derived from the nvlist of autosnapshots passed into the function.
 * If the hold fails due to ENOENT, the corresponding nvpair is removed
 * from the nvlist.
 */
void
autosnap_invalidate_list(dsl_pool_t *dp, nvlist_t *snapshots)
{
	nvpair_t *pair, *prev;
	int rc;

	pair = nvlist_next_nvpair(snapshots, NULL);
	while (pair != NULL) {
		dsl_dataset_t *ds = NULL;
		char *nvp_name, *atp;
		char dsname[ZFS_MAX_DATASET_NAME_LEN];

		nvp_name = nvpair_name(pair);
		atp = strchr(nvp_name, '@');
		prev = pair;
		pair = nvlist_next_nvpair(snapshots, pair);

		if (atp == NULL || (atp - nvp_name) >= sizeof (dsname))
			continue;

		(void) strlcpy(dsname, nvp_name, atp - nvp_name + 1);
		rc = dsl_dataset_hold(dp, dsname, FTAG, &ds);
		if (rc == 0)
			dsl_dataset_rele(ds, FTAG);
		else if (rc == ENOENT)
			fnvlist_remove_nvpair(snapshots, prev);
	}
}
