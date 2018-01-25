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
 * Copyright 2017 Nexenta Systems, Inc. All rights reserved.
 */
#ifndef _SYS_AUTOSNAP_H
#define	_SYS_AUTOSNAP_H

#include <sys/dsl_pool.h>
#include <sys/dmu_tx.h>
#include <sys/dsl_dataset.h>
#include <sys/spa.h>
#include <sys/nvpair.h>
#include <sys/list.h>
#include <sys/avl.h>

#ifdef	__cplusplus
extern "C" {
#endif

typedef boolean_t (*autosnap_confirm_cb)(const char *name, boolean_t recursive,
    uint64_t txg, void *arg);
typedef boolean_t (*autosnap_notify_created_cb)(const char *name,
    boolean_t recursive, boolean_t autosnap, uint64_t txg, uint64_t etxg,
    void *arg);
typedef void (*autosnap_error_cb)(const char *name, int err,
    uint64_t txg, void *arg);

typedef enum autosnap_flags {
	AUTOSNAP_RECURSIVE	= 1 << 0,
	AUTOSNAP_CREATOR	= 1 << 1,
	AUTOSNAP_DESTROYER	= 1 << 2,
	AUTOSNAP_KRRP		= 1 << 3,
	AUTOSNAP_OWNER		= 1 << 4,
	AUTOSNAP_WBC		= 1 << 5
} autosnap_flags_t;


typedef struct autosnap_snapshot {
	avl_node_t node; /* for release */
	list_node_t dnode; /* for destroyer */
	char name[ZFS_MAX_DATASET_NAME_LEN];
	boolean_t recursive;
	boolean_t orphaned;
	uint64_t txg;
	uint64_t etxg;

	list_t ref_cnt;
} autosnap_snapshot_t;

typedef struct zfs_autosnap zfs_autosnap_t;

/* The zone lock protects the list of the listeners */
/* Pools are distinguished by dataset and prefix */
typedef struct autosnap_zone {
	list_node_t node;
	/* The name of top-level dataset */
	char dataset[ZFS_MAX_DATASET_NAME_LEN];
	autosnap_flags_t flags;
	list_t listeners;
	avl_tree_t snapshots;
	kmutex_t avl_lock;
	zfs_autosnap_t *autosnap;
	boolean_t created; /* Snap already created */
	boolean_t delayed; /* Snap delayed for some reasons */

	/*
	 * B_TRUE if this zone is related to dirty
	 * DS in the given sync-round
	 */
	boolean_t dirty;
} autosnap_zone_t;

struct zfs_autosnap {
	kmutex_t autosnap_lock;
	kcondvar_t autosnap_cv;
	krwlock_t autosnap_rwlock;
	list_t autosnap_zones;
	list_t autosnap_destroy_queue;
	kthread_t *destroyer;
	boolean_t need_stop;
	boolean_t initialized;
	boolean_t register_busy;
};

/*
 * confirm_cb - should snapshot be created
 * nc_cb - snapshot is created
 * err_cb - can't create snapshot
 * Client must not rely on confirm_cb to store
 * information about existing snapshots. This
 * callback's call can be ommited for any client
 * if autosnap decides that it has enough data or
 * in no_creation case. The only reliable way to
 * know about snapshots that are created by autosnap
 * is nc_cb. Also, releasing snapshot doesn't destroy
 * a snapshot. After all references to a snapshot are
 * dropped, it is moved to destroyer's queue and
 * destroyed asynchronously.
 */
typedef struct autosnap_handler {
	list_node_t node;
	autosnap_confirm_cb confirm_cb;
	autosnap_notify_created_cb nc_cb;
	autosnap_error_cb err_cb;
	void *cb_arg;
	uint64_t flags;
	autosnap_zone_t *zone;
} autosnap_handler_t;

void * autosnap_register_handler_impl(spa_t *spa,
    const char *name, uint64_t flags,
    autosnap_confirm_cb confirm_cb,
    autosnap_notify_created_cb nc_cb,
    autosnap_error_cb err_cb, void *cb_arg);
void *autosnap_register_handler(const char *name, uint64_t flags,
    autosnap_confirm_cb confirm_cb,
    autosnap_notify_created_cb nc_cb,
    autosnap_error_cb, void *cb_arg);
void autosnap_unregister_handler(void *opaque);
autosnap_zone_t *autosnap_find_zone(zfs_autosnap_t *autosnap,
    const char *name, boolean_t recursive);
boolean_t autosnap_has_children_zone(zfs_autosnap_t *autosnap,
    const char *name, boolean_t krrp_only);
void autosnap_exempt_snapshot(spa_t *spa, const char *name);
void autosnap_force_snap_by_name(const char *dsname,
    autosnap_zone_t *zone, boolean_t sync);
void autosnap_force_snap(void *opaque, boolean_t sync);
void autosnap_force_snap_fast(void *opaque);
boolean_t autosnap_confirm_snap(autosnap_zone_t *zone, uint64_t txg);
void autosnap_error_snap(autosnap_zone_t *zone, uint64_t txg, int err);

void autosnap_create_cb(zfs_autosnap_t *autosnap,
    dsl_dataset_t *ds, const char *snapname, uint64_t txg);
int autosnap_check_for_destroy(zfs_autosnap_t *autosnap,
    const char *name);

#define	AUTOSNAP_PREFIX ".autosnap_"
#define	AUTOSNAP_PREFIX_LEN (sizeof (AUTOSNAP_PREFIX) - 1)
#define	AUTOSNAP_NO_SNAP UINT64_MAX
#define	AUTOSNAP_LAST_SNAP (UINT64_MAX-1)
#define	AUTOSNAP_FIRST_SNAP 0x0

/*
 * No lock version should be called if and only if a
 * snapshot should be released in nc_cb context
 */
void autosnap_release_snapshots_by_txg(void *opaque,
    uint64_t from_txg, uint64_t to_txg);
void autosnap_release_snapshots_by_txg_no_lock(void *opaque,
    uint64_t from_txg, uint64_t to_txg);

nvlist_t *autosnap_get_owned_snapshots(void *opaque);

int autosnap_lock(spa_t *spa, krw_t rw);
void autosnap_unlock(spa_t *spa);

boolean_t autosnap_is_autosnap(dsl_dataset_t *ds);
boolean_t autosnap_check_name(const char *snap_name);

void autosnap_destroyer_thread_start(spa_t *spa);
void autosnap_destroyer_thread_stop(spa_t *spa);
void autosnap_init(spa_t *spa);
void autosnap_fini(spa_t *spa);

void autosnap_create_snapshot(autosnap_zone_t *azone, char *snap,
    dsl_pool_t *dp, uint64_t txg, dmu_tx_t *tx);
void autosnap_invalidate_list(dsl_pool_t *dp, nvlist_t *snapshots);

#ifdef	__cplusplus
}
#endif

#endif /* _SYS_AUTOSNAP_H */
