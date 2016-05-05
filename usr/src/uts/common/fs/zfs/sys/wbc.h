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
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef	_SYS_WRCACHE_H
#define	_SYS_WRCACHE_H

#include <sys/zfs_context.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/fs/zfs.h>
#include <sys/spa.h>
#include <sys/dmu.h>
#include <sys/dmu_traverse.h>
#include <sys/dsl_dataset.h>
#include <sys/dsl_pool.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * field 'blk_prop' of wbc_block_t
 *
 * 64              48               32              16              0
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *  |      RESERVED    |D(1)|comp(7)|  PSIZE(16)    |     LSIZE(16) |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *
 * Legend:
 * D			deleted
 * comp			compression function of payload
 * PSIZE		size of payload after compression, in bytes
 * LSIZE		logical size of payload, in bytes
 *
 * Deleted block is a block whos dva was freed,
 * so this block must not be used by wbc_move_logic
 * and after move has been finished need to free only block-structure
 */
#define	WBCBP_GET_LSIZE(bp)	\
	BF64_GET_SB((bp)->blk_prop, 0, SPA_LSIZEBITS, SPA_MINBLOCKSHIFT, 1)
#define	WBCBP_SET_LSIZE(bp, x)	do { \
	BF64_SET_SB((bp)->blk_prop, \
	    0, SPA_LSIZEBITS, SPA_MINBLOCKSHIFT, 1, x); \
_NOTE(CONSTCOND) } while (0)

#define	WBCBP_GET_PSIZE(bp)	\
	BF64_GET_SB((bp)->blk_prop, 16, SPA_PSIZEBITS, SPA_MINBLOCKSHIFT, 1)
#define	WBCBP_SET_PSIZE(bp, x)	do { \
	BF64_SET_SB((bp)->blk_prop, \
	    16, SPA_PSIZEBITS, SPA_MINBLOCKSHIFT, 1, x); \
_NOTE(CONSTCOND) } while (0)

#define	WBCBP_GET_COMPRESS(bp)		BF64_GET((bp)->blk_prop, 32, 7)
#define	WBCBP_SET_COMPRESS(bp, x)	BF64_SET((bp)->blk_prop, 32, 7, x)

#define	WBCBP_IS_DELETED(wbcbp)		BF64_GET((wbcbp)->blk_prop, 39, 1)
#define	WBCBP_MARK_DELETED(wbcbp)	BF64_SET((wbcbp)->blk_prop, 39, 1, 1)

typedef struct wbc_data wbc_data_t;

/*
 * WBC Instance is a dataset (DS) and
 * all the children DSs of that DS.
 */
typedef struct wbc_instance {
	avl_node_t	node;

	wbc_data_t	*wbc_data;
	void		*wbc_autosnap_hdl;
	char		ds_name[MAXNAMELEN];

	/* copy of dsl_dataset_t->ds_object */
	uint64_t	ds_object;

	/*
	 * TXG of the right boundary WBC-window
	 * can be 0 if this instance is 'idle'
	 */
	uint64_t	txg_to_rele;

	/*
	 * txg of the specific TXG sync that
	 * executed 'off' on this instance
	 */
	uint64_t	txg_off;

	boolean_t	fini_migration;
	boolean_t	fini_done;
} wbc_instance_t;

/*
 * WBC statistics
 */
typedef struct wbc_stat {
	uint64_t	wbc_spa_util;		/* spa average utilization */
	clock_t		wbc_stat_lbolt;		/* last statistics update */
	boolean_t	wbc_stat_update;	/* statstics update flag */
} wbc_stat_t;

/*
 * wbc_data is a global per ZFS pool structure contains all
 * information associated with write cache and
 * is attached to spa structure.
 */
struct wbc_data {
	kthread_t	*wbc_init_thread;
	kthread_t	*wbc_thread;		/* move thread */
	kthread_t	*wbc_walk_thread;	/* collector thread */

	kmutex_t	wbc_lock;
	kcondvar_t	wbc_cv;

	/* TASKQ that does async finalization of wbc_instances */
	taskq_t		*wbc_instance_fini;

	uint64_t	wbc_instance_fini_cnt;

	avl_tree_t	wbc_blocks;		/* collected blocks */
	avl_tree_t	wbc_moved_blocks;	/* moved blocks */

	uint64_t	wbc_window_bytes;	/* bytes in current wnd */
	uint64_t	wbc_altered_bytes;	/* bytes altered in new wnd */
	uint64_t	wbc_roll_threshold;	/* max percent can be altered */
	uint64_t	wbc_altered_limit;	/* max bytes can be altered */

	uint64_t	wbc_blocks_count;	/* amount of blocks */

	taskq_t		*wbc_move_taskq;	/* pending blocks taskq */
	uint64_t	wbc_move_threads;	/* taskq number of threads */

	uint64_t	wbc_start_txg;		/* left boundary */
	uint64_t	wbc_finish_txg;		/* right boundary */
	uint64_t	wbc_txg_to_rele;	/* txg to rele */
	uint64_t	wbc_blocks_in;		/* collected */
	uint64_t	wbc_blocks_out;		/* planned */
	uint64_t	wbc_blocks_mv;		/* moved */
	uint64_t	wbc_blocks_mv_last; /* latest number of moved blocks */

	uint64_t	wbc_latest_window_time;

	/* Tree of watched datasets and corresponding data */
	avl_tree_t	wbc_instances;
	boolean_t	wbc_ready_to_use;

	spa_t		*wbc_spa;		/* parent spa */
	wbc_stat_t	wbc_stat;		/* WBC statistics */

	uint64_t	wbc_fault_moves;	/* amount of fault moves */

	boolean_t	wbc_purge;	/* should purge queued blocks */
	boolean_t	wbc_walk;	/* should walk */
	boolean_t	wbc_locked;	/* do not walk while locked */
	boolean_t	wbc_walking;	/* currently walking */
	boolean_t	wbc_wait_for_window;

	boolean_t	wbc_delete;	/* delete state */

	boolean_t	wbc_thr_exit;	/* exit flag */
	boolean_t	wbc_isvalid;	/* WBC is inited */
	boolean_t	wbc_first_move; /* TRUE until the 1 WBC-win opened */
};

/* !!! Do not change these constants !!! */
#define	WBC_SPECIAL_DVA 0
#define	WBC_NORMAL_DVA 1

/*
 * In-core representation of a block which will be moved
 */
typedef struct wbc_block {
	avl_node_t	node;

	/* associated WBC */
	wbc_data_t	*data;

	/*
	 * size, compression
	 */
	uint64_t	blk_prop;

	/* birth txg for arc lookup */
	uint64_t	btxg;

	/* dvas of blocks to move */
	dva_t		dva[2];

	kmutex_t	lock;
} wbc_block_t;

typedef struct wbc_parseblock_cb {
	wbc_data_t	*wbc_data;

	/*
	 * A bookmark for resume
	 */
	zbookmark_phys_t	zb;

	/*
	 * Total size of all collected blocks
	 */
	uint64_t	bt_size;

	/*
	 * The time we started traversal process
	 */
	hrtime_t	start_time;

	uint64_t	actv_txg;
} wbc_parseblock_cb_t;

/*
 * This structure describes ZFS_PROP_WBC_MODE property
 */
typedef struct {
	/*
	 * copy of dsl_dataset_t->ds_object of dataset
	 * for which user does wbc_mode=on
	 */
	uint64_t	root_ds_object;

	/*
	 * TXG when user did 'wbc_mode=off'
	 */
	uint64_t	txg_off;

	/*
	 * Flags. Now is not used.
	 */
	uint64_t	flags;
} wbc_mode_prop_val_t;

#define	WBC_MODE_PROP_VAL_SZ (sizeof (wbc_mode_prop_val_t) / sizeof (uint64_t))

void wbc_init(wbc_data_t *wbc_data, spa_t *spa);
void wbc_fini(wbc_data_t *wbc_data);

void wbc_activate(spa_t *spa, boolean_t pool_creation);
void wbc_deactivate(spa_t *spa);

int wbc_select_dva(wbc_data_t *wbc_data, zio_t *zio);
boolean_t wbc_bp_is_migrated(wbc_data_t *wbc_data, const blkptr_t *bp);
int wbc_first_valid_dva(const blkptr_t *bp,
    wbc_data_t *wbc_data, boolean_t removal);

wbc_data_t *spa_get_wbc_data(spa_t *spa);

void wbc_add_bytes(spa_t *spa, uint64_t txg, uint64_t bytes);

/*
 * write cache thread.
 */
void wbc_start_thread(spa_t *);
boolean_t wbc_stop_thread(spa_t *);
void wbc_trigger_wbcthread(spa_t *, uint64_t);

/*
 * callback function for traverse_dataset which validates
 * the block pointer and adds to the list.
 */
blkptr_cb_t	wbc_traverse_ds_cb;

boolean_t wbc_check_parseblocks_hold(spa_t *);
void wbc_check_parseblocks_rele(spa_t *spa);
boolean_t wbc_try_hold(spa_t *);
int wbc_walk_lock(spa_t *);
void wbc_walk_unlock(spa_t *);

void wbc_process_objset(wbc_data_t *wbc_data, objset_t *os, boolean_t destroy);
void wbc_mode_changed(void *arg, uint64_t newval);
int wbc_check_dataset(const char *ds_name);

boolean_t wbc_try_disable(wbc_data_t *wbc_data);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_WRCACHE_H */
