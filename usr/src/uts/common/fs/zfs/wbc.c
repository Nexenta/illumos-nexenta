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

/*
 * WriteBackCache (WBC) basics.
 * ZFS allows to store up to 3 dva per block pointer. Normally, all of the dvas
 * are valid at all time (or at least supposed to be so, and if data under a
 * dva is broken it is repaired with data under another dva). WBC alters the
 * behaviour. Each cached with WBC block has two dvas, and validity of them
 * changes during time. At first, when zfs decides to chace a block with WBC,
 * two dvas are allocated: one on a special device and one on a normal one.
 * Data is written to the special dva only. At the time the special dva is
 * valid and the normal one contains garbage. Later, after move operation is
 * performed for a block, i.e. the data stored under the special dva is copied
 * to the place pointed by the normal dva, the special dva is freed and can be
 * reused and the normal dva now valid and contains actual data.
 * To let zfs know which dva is valid and which is not, all data is moved by
 * chunks bounded with birth txg. When a new chunck of data should be moved, a
 * snapshot (recursive, starting at the very root dataset) is created. the
 * snapshot is used to perform simple traverse over it and not to miss any
 * block. The txg boundaries are from old_move_snap_txg + 1 to new_move_snap.
 * Checking blocks' birth txg against those boundaries, zfs understand which
 * dva is valid at the moment.
 */

#include <sys/fm/fs/zfs.h>
#include <sys/special.h>
#include <sys/spa_impl.h>
#include <sys/zio.h>
#include <sys/zio_checksum.h>
#include <sys/dmu.h>
#include <sys/dmu_tx.h>
#include <sys/zap.h>
#include <sys/zil.h>
#include <sys/ddt.h>
#include <sys/dmu_traverse.h>
#include <sys/dmu_objset.h>
#include <sys/dsl_pool.h>
#include <sys/dsl_dataset.h>
#include <sys/dsl_dir.h>
#include <sys/dsl_scan.h>
#include <sys/dsl_prop.h>
#include <sys/arc.h>
#include <sys/vdev_impl.h>
#include <sys/mutex.h>
#include <sys/time.h>
#include <sys/arc.h>
#include <sys/zio_compress.h>
#include <sys/zfs_ioctl.h>
#ifdef _KERNEL
#include <sys/ddi.h>
#endif

extern int zfs_txg_timeout;
extern int zfs_scan_min_time_ms;
extern uint64_t zfs_dirty_data_sync;
extern uint64_t krrp_debug;

typedef enum {
	WBC_READ_FROM_SPECIAL = 1,
	WBC_WRITE_TO_NORMAL,
} wbc_io_type_t;

/*
 * timeout (in seconds) that is used to schedule a job that moves
 * blocks from a special device to other deivices in a pool
 */
int zfs_wbc_schedtmo = 0;

uint64_t zfs_wbc_data_max = 48 << 20; /* Max data to migrate in a pass */

uint64_t wbc_mv_cancel_threshold_initial = 20;
/* we are not sure if we need logic of threshold increment */
uint64_t wbc_mv_cancel_threshold_step = 0;
uint64_t wbc_mv_cancel_threshold_cap = 50;

static boolean_t wbc_check_space(spa_t *spa);

static void wbc_free_block(wbc_block_t *block);
static void wbc_clean_tree(wbc_data_t *wbc_data, avl_tree_t *tree);
static void wbc_clean_plan_tree(wbc_data_t *wbc_data);
static void wbc_clean_moved_tree(wbc_data_t *wbc_data);

static void wbc_activate_impl(spa_t *spa, boolean_t pool_creation);
static wbc_block_t *wbc_create_block(wbc_data_t *wbc_data,
    const blkptr_t *bp);
static void wbc_move_block(void *arg);
static int wbc_move_block_impl(wbc_block_t *block);
static int wbc_collect_special_blocks(dsl_pool_t *dp);
static void wbc_close_window(wbc_data_t *wbc_data);
static void wbc_write_update_window(void *void_spa, dmu_tx_t *tx);

static int wbc_io(wbc_io_type_t type, wbc_block_t *block, void *data);
static int wbc_blocks_compare(const void *arg1, const void *arg2);
static int wbc_instances_compare(const void *arg1, const void *arg2);

static void wbc_unregister_instance_impl(wbc_instance_t *wbc_instance,
    boolean_t rele_autosnap);
static void wbc_unregister_instances(wbc_data_t *wbc_data);
static wbc_instance_t *wbc_register_instance(wbc_data_t *wbc_data,
    objset_t *os);
static void wbc_unregister_instance(wbc_data_t *wbc_data, objset_t *os,
    boolean_t rele_autosnap);
static wbc_instance_t *wbc_lookup_instance(wbc_data_t *wbc_data,
    uint64_t ds_object, avl_index_t *where);
static void wbc_rele_autosnaps(wbc_data_t *wbc_data, uint64_t txg_to_rele,
    boolean_t purge);

void
wbc_init(wbc_data_t *wbc_data, spa_t *spa)
{
	(void) memset(wbc_data, 0, sizeof (wbc_data_t));

	wbc_data->wbc_spa = spa;

	mutex_init(&wbc_data->wbc_lock, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&wbc_data->wbc_cv, NULL, CV_DEFAULT, NULL);

	avl_create(&wbc_data->wbc_blocks, wbc_blocks_compare,
	    sizeof (wbc_block_t), offsetof(wbc_block_t, node));
	avl_create(&wbc_data->wbc_moved_blocks, wbc_blocks_compare,
	    sizeof (wbc_block_t), offsetof(wbc_block_t, node));
	avl_create(&wbc_data->wbc_instances, wbc_instances_compare,
	    sizeof (wbc_instance_t), offsetof(wbc_instance_t, node));

	wbc_data->wbc_instance_fini = taskq_create("wbc_instance_finalization",
	    1, maxclsyspri, 50, INT_MAX, TASKQ_PREPOPULATE);
}

void
wbc_fini(wbc_data_t *wbc_data)
{
	taskq_wait(wbc_data->wbc_instance_fini);
	taskq_destroy(wbc_data->wbc_instance_fini);

	mutex_enter(&wbc_data->wbc_lock);

	wbc_clean_plan_tree(wbc_data);
	wbc_clean_moved_tree(wbc_data);

	avl_destroy(&wbc_data->wbc_blocks);
	avl_destroy(&wbc_data->wbc_moved_blocks);
	avl_destroy(&wbc_data->wbc_instances);

	mutex_exit(&wbc_data->wbc_lock);

	cv_destroy(&wbc_data->wbc_cv);
	mutex_destroy(&wbc_data->wbc_lock);

	wbc_data->wbc_spa = NULL;
}

#ifndef _KERNEL
/*ARGSUSED*/
static clock_t
drv_usectohz(uint64_t time)
{
	return (1000);
}
#endif

static wbc_block_t *
wbc_create_block(wbc_data_t *wbc_data, const blkptr_t *bp)
{
	wbc_block_t *block;

	block = kmem_alloc(sizeof (*block), KM_NOSLEEP);
	if (block == NULL)
		return (NULL);

	/*
	 * Fill information describing data we need to move
	 */
#ifdef _KERNEL
	DTRACE_PROBE6(wbc_plan_block_data,
	    uint64_t, BP_PHYSICAL_BIRTH(bp),
	    uint64_t, DVA_GET_VDEV(&bp->blk_dva[0]),
	    uint64_t, DVA_GET_OFFSET(&bp->blk_dva[0]),
	    uint64_t, DVA_GET_VDEV(&bp->blk_dva[1]),
	    uint64_t, DVA_GET_OFFSET(&bp->blk_dva[1]),
	    uint64_t, BP_GET_PSIZE(bp));
#endif

	mutex_init(&block->lock, NULL, MUTEX_DEFAULT, NULL);
	block->data = wbc_data;
	block->blk_prop = 0;

	block->dva[0] = bp->blk_dva[0];
	block->dva[1] = bp->blk_dva[1];
	block->btxg = BP_PHYSICAL_BIRTH(bp);

	WBCBP_SET_COMPRESS(block, BP_GET_COMPRESS(bp));
	WBCBP_SET_PSIZE(block, BP_GET_PSIZE(bp));
	WBCBP_SET_LSIZE(block, BP_GET_LSIZE(bp));

	return (block);
}

static void
wbc_free_block(wbc_block_t *block)
{
	mutex_destroy(&block->lock);
	kmem_free(block, sizeof (*block));
}

static void
wbc_clean_tree(wbc_data_t *wbc_data, avl_tree_t *tree)
{
	void *cookie = NULL;
	wbc_block_t *block = NULL;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	while ((block = avl_destroy_nodes(tree, &cookie)) != NULL)
		wbc_free_block(block);
}

static void
wbc_clean_plan_tree(wbc_data_t *wbc_data)
{
	wbc_clean_tree(wbc_data, &wbc_data->wbc_blocks);
	wbc_data->wbc_blocks_count = 0;
}

static void
wbc_clean_moved_tree(wbc_data_t *wbc_data)
{
	wbc_clean_tree(wbc_data, &wbc_data->wbc_moved_blocks);
	wbc_data->wbc_blocks_mv = 0;
}

/* WBC-MOVE routines */

/*
 * Writeback Cache Migration Tunables
 *
 * 1. wbc_idle_delay_ms - time to sleep when there are no blocks to move
 *    OR, when we need to update the current spa utilization by the user/app
 *
 * 2. wbc_throttle_move_delay_ms - sleep to abide by the maximum
 *    permitted rate of migration
 *
 * 3. wbc_update_statistics_interval_ms - pool utilization recompute interval
 *    (all tunables above are in milliseconds)
 *
 * 4. wbc_min_move_tasks_count & wbc_max_move_tasks_count: the min/max number
 *    of concurrent active taskq workers processing the blocks to be migrated
 *
 * 5. wbc_spa_util_low_wm & wbc_spa_util_high_wm - min/max spa utilization
 *    levels to control the rate of migration: low_wm corresponds to the
 *    highest rate, and vise versa.
 */
uint64_t wbc_idle_delay_ms = 1000;
uint64_t wbc_throttle_move_delay_ms = 10;
uint64_t wbc_update_statistics_interval_ms = 60000;

uint64_t wbc_min_move_tasks_count = 1;
uint64_t wbc_max_move_tasks_count = 256;

uint64_t wbc_spa_util_low_wm = 10;
uint64_t wbc_spa_util_high_wm = 90;

/*
 * Per-queue limits on the number of I/O's active to
 * each device from vdev_queue.c. Default value: 10.
 */
extern uint32_t zfs_vdev_async_write_max_active;

/*
 * Throtte special=>normal migration of collected blocks.
 * Returns B_TRUE indicating that the mover must slow down, B_FALSE otherwise.
 */
static boolean_t
wbc_throttle_move(wbc_data_t *wbc_data)
{
	wbc_stat_t *wbc_stat = &wbc_data->wbc_stat;
	uint64_t spa_util = wbc_stat->wbc_spa_util;
	uint64_t blocks_in_progress = 0;
	uint64_t max_tasks = 0;
	uint64_t delta_tasks = 0;

	if (wbc_data->wbc_locked)
		return (B_TRUE);

	/* get throttled by the taskq itself */
	if (spa_util < wbc_spa_util_low_wm)
		return (B_FALSE);

	blocks_in_progress =
	    wbc_data->wbc_blocks_out - wbc_data->wbc_blocks_mv;

	if (wbc_data->wbc_move_threads <= wbc_min_move_tasks_count)
		return (blocks_in_progress > wbc_min_move_tasks_count);

	max_tasks = wbc_data->wbc_move_threads - wbc_min_move_tasks_count;

	spa_util = MIN(spa_util, wbc_spa_util_high_wm);
	spa_util = MAX(spa_util, wbc_spa_util_low_wm);

	/*
	 * Number of concurrent taskq workers is:
	 * min + throttle-defined delta
	 */
	delta_tasks =
	    max_tasks - max_tasks * (wbc_spa_util_high_wm - spa_util) /
	    (wbc_spa_util_high_wm - wbc_spa_util_low_wm);

	DTRACE_PROBE4(wbc_throttle_move,
	    spa_t *, wbc_data->wbc_spa,
	    uint64_t, blocks_in_progress,
	    uint64_t, max_tasks,
	    uint64_t, delta_tasks);

	return (blocks_in_progress > (wbc_min_move_tasks_count + delta_tasks));
}

/*
 * Walk the WBC-collected-blocks AVL and for each WBC block (wbc_block_t):
 * 1. yank it from the collected-blocks AVL tree
 * 2. add it to the moved-blocks AVL tree
 * 3. dispatch taskq to execute the special=>normal migration
 * Break when either reaching an upper limit, in total bytes, or when
 * wbc_throttle_move() (the "throttler") wants us to slow-down
 */
static void
wbc_move_blocks_tree(wbc_data_t *wbc_data)
{
	wbc_stat_t *wbc_stat = &wbc_data->wbc_stat;
	uint64_t written_bytes = 0;
	uint64_t active_txg = 0;

	mutex_enter(&wbc_data->wbc_lock);
	active_txg = wbc_data->wbc_finish_txg;

	for (;;) {
		wbc_block_t *block = NULL;

		if (wbc_data->wbc_thr_exit)
			break;

		/*
		 * Move the block to the tree of moved blocks
		 * and place into the queue of blocks to be
		 * physically moved
		 */
		block = avl_first(&wbc_data->wbc_blocks);
		if (block == NULL)
			break;

		wbc_data->wbc_blocks_count--;
		ASSERT(wbc_data->wbc_blocks_count >= 0);
		avl_remove(&wbc_data->wbc_blocks, block);
		avl_add(&wbc_data->wbc_moved_blocks, block);
		wbc_data->wbc_blocks_out++;

		mutex_exit(&wbc_data->wbc_lock);

		/* TQ_SLEEP guarantees the successful dispatching */
		VERIFY(taskq_dispatch(wbc_data->wbc_move_taskq,
		    wbc_move_block, block, TQ_SLEEP) != 0);

		written_bytes += WBCBP_GET_PSIZE(block);

		mutex_enter(&wbc_data->wbc_lock);

		if (active_txg != wbc_data->wbc_finish_txg)
			break;

		/*
		 * Update existing WBC statistics during
		 * the next wbc_move_begin() iteration
		 */
		if (ddi_get_lbolt() - wbc_stat->wbc_stat_lbolt >
		    drv_usectohz(wbc_update_statistics_interval_ms * MILLISEC))
			wbc_stat->wbc_stat_update = B_TRUE;

		if (written_bytes > zfs_wbc_data_max ||
		    wbc_throttle_move(wbc_data))
			break;
	}

	mutex_exit(&wbc_data->wbc_lock);

	DTRACE_PROBE2(wbc_move_blocks_tree,
	    spa_t *, wbc_data->wbc_spa,
	    uint64_t, written_bytes);
}

/*
 * Begin new writecache migration iteration.
 * Returns B_TRUE if the migration can proceed, B_FALSE otherwise.
 * Is called from the wbc_thread prior to moving the next batch
 * of blocks.
 *
 * Quick theory of operation:
 * 1. If the pool is idle we can allow ourselves to speed-up
 *    special => normal migration
 * 2. And vise versa, higher utilization of this spa under user
 *    workload must have /more/ system resources for itself
 * 3. Which means in turn less system resources for the writecache.
 * 4. Finally, since the pool's utilization is used to speed-up or
 *    slow down (throttle) migrations. measuring of this utilization
 *    must be done in isolation - that is, when writecache migration
 *    is either not running at all or contributes relatively
 *    little to the total utilization.
 *
 * In in this wbc_move_begin() we periodcially update wbc_spa_util
 * and use it to throttle writecache via wbc_throttle_move()
 *
 * Note that we actually sleep here based on the following tunables:
 *
 * 1. wbc_idle_delay_ms when there are no blocks to move
 *    OR, when we need to update the spa utilization by the user
 *
 * 2. sleep wbc_throttle_move_delay_ms when the throttling mechanism
 *    tells us to slow down
 */
static boolean_t
wbc_move_begin(wbc_data_t *wbc_data)
{
	spa_t *spa = wbc_data->wbc_spa;
	wbc_stat_t *wbc_stat = &wbc_data->wbc_stat;
	spa_avg_stat_t *spa_stat = &spa->spa_avg_stat;

	for (;;) {
		boolean_t throttle_move = B_FALSE;
		boolean_t stat_update = B_FALSE;
		uint64_t blocks_count = 0;
		uint64_t delay = 0;

		mutex_enter(&wbc_data->wbc_lock);

		if (spa->spa_state == POOL_STATE_UNINITIALIZED ||
		    wbc_data->wbc_thr_exit) {
			mutex_exit(&wbc_data->wbc_lock);
			return (B_FALSE);
		}

		blocks_count = wbc_data->wbc_blocks_count;
		throttle_move = wbc_throttle_move(wbc_data);
		stat_update = wbc_stat->wbc_stat_update;

		mutex_exit(&wbc_data->wbc_lock);

		DTRACE_PROBE3(wbc_move_begin,
		    spa_t *, spa,
		    uint64_t, blocks_count,
		    boolean_t, throttle_move);

		if (stat_update) {
			/*
			 * Waits for all previously scheduled
			 * move tasks to complete
			 */
			taskq_wait(wbc_data->wbc_move_taskq);
			delay = wbc_idle_delay_ms;
		} else if (blocks_count == 0) {
			delay = wbc_idle_delay_ms;
		} else if (throttle_move) {
			delay = wbc_throttle_move_delay_ms;
		} else {
			return (B_TRUE);
		}

		mutex_enter(&wbc_data->wbc_lock);

		/*
		 * Sleep wbc_idle_delay_ms when there are no blocks to move
		 * or when we need to update the spa utilization by the user.
		 * Sleep wbc_throttle_move_delay_ms when the throttling
		 * mechanism tells us to slow down.
		 */
		(void) cv_timedwait(&wbc_data->wbc_cv,
		    &wbc_data->wbc_lock,
		    ddi_get_lbolt() + drv_usectohz(delay * MILLISEC));

		/* Update WBC statistics after idle period */
		if (wbc_stat->wbc_stat_update) {
			DTRACE_PROBE2(wbc_move_begin_update_stat,
			    spa_t *, spa, uint64_t, spa_stat->spa_utilization);
			wbc_stat->wbc_stat_update = B_FALSE;
			wbc_stat->wbc_stat_lbolt = ddi_get_lbolt();
			wbc_stat->wbc_spa_util = spa_stat->spa_utilization;
		}

		mutex_exit(&wbc_data->wbc_lock);

		/* Return B_TRUE if the migration can proceed */
		if (blocks_count > 0 && !throttle_move)
			return (B_TRUE);
	}
}

/*
 * Thread to manage the data movement from
 * special devices to normal devices.
 * This thread runs as long as the spa is active.
 */
static void
wbc_thread(wbc_data_t *wbc_data)
{
	spa_t *spa = wbc_data->wbc_spa;
	char tq_name[MAXPATHLEN];

	DTRACE_PROBE1(wbc_thread_start, spa_t *, spa);

	/* Prepare move queue and make the WBC active */
	(void) snprintf(tq_name, sizeof (tq_name),
	    "%s_wbc_move", spa->spa_name);

	wbc_data->wbc_move_taskq = taskq_create(tq_name,
	    wbc_data->wbc_move_threads, maxclsyspri,
	    50, INT_MAX, TASKQ_PREPOPULATE);

	/* Main dispatch loop */
	for (;;) {
		if (!wbc_move_begin(wbc_data))
			break;

		wbc_move_blocks_tree(wbc_data);
	}

	taskq_wait(wbc_data->wbc_move_taskq);
	taskq_destroy(wbc_data->wbc_move_taskq);

	wbc_data->wbc_thread = NULL;
	DTRACE_PROBE1(wbc_thread_done, spa_t *, spa);
	thread_exit();
}

static uint64_t wbc_fault_limit = 10;

typedef struct {
	void *buf;
	int len;
} wbc_arc_bypass_t;

static int
wbc_arc_bypass_cb(void *buf, int len, void *arg)
{
	wbc_arc_bypass_t *bypass = arg;

	bypass->len = len;

	(void) memcpy(bypass->buf, buf, len);

	return (0);
}

uint64_t wbc_arc_enabled = 1;
/*
 * Moves blocks from a special device to other devices in a pool.
 */
void
wbc_move_block(void *arg)
{
	wbc_block_t *block = arg;
	wbc_data_t *wbc_data = block->data;
	spa_t *spa = wbc_data->wbc_spa;
	int err = 0;

	if (wbc_data->wbc_purge || !wbc_data->wbc_isvalid) {
		atomic_inc_64(&wbc_data->wbc_blocks_mv);
		return;
	}

	err = wbc_move_block_impl(block);
	if (err == 0) {
		atomic_inc_64(&wbc_data->wbc_blocks_mv);
	} else {
		/* io error occured */
		if (++wbc_data->wbc_fault_moves >= wbc_fault_limit) {
			/* error limit exceeded - disable WBC */
			cmn_err(CE_WARN,
			    "WBC: can not move data on %s with error[%d]. "
			    "Current window will be purged\n",
			    spa->spa_name, err);

			mutex_enter(&wbc_data->wbc_lock);
			wbc_purge_window(spa, NULL);
			mutex_exit(&wbc_data->wbc_lock);
		} else {
			cmn_err(CE_WARN,
			    "WBC: can not move data on %s with error[%d]\n"
			    "WBC: retry block (fault limit: %llu/%llu)",
			    spa->spa_name, err,
			    (unsigned long long) wbc_data->wbc_fault_moves,
			    (unsigned long long) wbc_fault_limit);

			/*
			 * re-plan the block with the highest priority and
			 * try to move it again
			 *
			 * TQ_SLEEP guarantees the successful dispatching
			 */
			VERIFY(taskq_dispatch(wbc_data->wbc_move_taskq,
			    wbc_move_block, block, TQ_SLEEP | TQ_FRONT) != 0);
		}
	}
}

static int
wbc_move_block_impl(wbc_block_t *block)
{
	void *buf;
	int err = 0;
	wbc_data_t *wbc_data = block->data;
	spa_t *spa = wbc_data->wbc_spa;

	if (WBCBP_IS_DELETED(block))
		return (0);

	spa_config_enter(spa, SCL_VDEV | SCL_STATE_ALL, FTAG, RW_READER);

	buf = zio_data_buf_alloc(WBCBP_GET_PSIZE(block));

	if (wbc_arc_enabled) {
		blkptr_t pseudo_bp = { 0 };
		wbc_arc_bypass_t bypass = { 0 };
		void *dbuf = NULL;

		if (WBCBP_GET_COMPRESS(block) != ZIO_COMPRESS_OFF) {
			dbuf = zio_data_buf_alloc(WBCBP_GET_LSIZE(block));
			bypass.buf = dbuf;
		} else {
			bypass.buf = buf;
		}

		pseudo_bp.blk_dva[0] = block->dva[0];
		pseudo_bp.blk_dva[1] = block->dva[1];
		BP_SET_BIRTH(&pseudo_bp, block->btxg, block->btxg);

		mutex_enter(&block->lock);
		if (WBCBP_IS_DELETED(block)) {
			if (WBCBP_GET_COMPRESS(block) != ZIO_COMPRESS_OFF)
				zio_data_buf_free(dbuf, WBCBP_GET_LSIZE(block));

			goto out;
		}

		err = arc_io_bypass(spa, &pseudo_bp,
		    wbc_arc_bypass_cb, &bypass);

		if (!err && WBCBP_GET_COMPRESS(block) != ZIO_COMPRESS_OFF) {
			size_t size = zio_compress_data(
			    (enum zio_compress)WBCBP_GET_COMPRESS(block),
			    dbuf, buf, bypass.len);
			size_t rounded =
			    P2ROUNDUP(size, (size_t)SPA_MINBLOCKSIZE);
			if (rounded != WBCBP_GET_PSIZE(block)) {
				/* random error to get to slow path */
				err = ERANGE;
				cmn_err(CE_WARN, "WBC WARN: ARC COMPRESSION "
				    "FAILED: %u %u %u",
				    (unsigned)size,
				    (unsigned)WBCBP_GET_PSIZE(block),
				    (unsigned)WBCBP_GET_COMPRESS(block));
			} else if (rounded > size) {
				bzero((char *)buf + size, rounded - size);
			}
		}

		if (WBCBP_GET_COMPRESS(block) != ZIO_COMPRESS_OFF)
			zio_data_buf_free(dbuf, WBCBP_GET_LSIZE(block));

	} else {
		err = ENOTSUP;
		mutex_enter(&block->lock);
		if (WBCBP_IS_DELETED(block))
			goto out;
	}

	/*
	 * Any error means that arc read failed and block is being moved via
	 * slow path
	 */
	if (err) {
		err = wbc_io(WBC_READ_FROM_SPECIAL, block, buf);
		if (err) {
			cmn_err(CE_WARN, "WBC: move task has failed to read:"
			    " error [%d]", err);
			goto out;
		}
		DTRACE_PROBE(wbc_move_from_disk);
	} else {
		DTRACE_PROBE(wbc_move_from_arc);
	}

	err = wbc_io(WBC_WRITE_TO_NORMAL, block, buf);
	if (err) {
		cmn_err(CE_WARN, "WBC: move task has failed to write: "
		    "error [%d]", err);
		goto out;
	}

#ifdef _KERNEL
	DTRACE_PROBE5(wbc_move_block_data,
	    uint64_t, DVA_GET_VDEV(&block->dva[0]),
	    uint64_t, DVA_GET_OFFSET(&block->dva[0]),
	    uint64_t, DVA_GET_VDEV(&block->dva[1]),
	    uint64_t, DVA_GET_OFFSET(&block->dva[1]),
	    uint64_t, WBCBP_GET_PSIZE(block));
#endif

out:
	mutex_exit(&block->lock);
	zio_data_buf_free(buf, WBCBP_GET_PSIZE(block));

	spa_config_exit(spa, SCL_VDEV | SCL_STATE_ALL, FTAG);

	return (err);
}

/* WBC-WALK routines */

int
wbc_walk_lock(spa_t *spa)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);

	mutex_enter(&wbc_data->wbc_lock);
	while (wbc_data->wbc_locked)
		(void) cv_wait(&wbc_data->wbc_cv, &wbc_data->wbc_lock);
	if (wbc_data->wbc_thr_exit) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ENOLCK);
	}

	wbc_data->wbc_locked = B_TRUE;
	while (wbc_data->wbc_walking)
		(void) cv_wait(&wbc_data->wbc_cv, &wbc_data->wbc_lock);
	if (wbc_data->wbc_thr_exit) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ENOLCK);
	}

	cv_broadcast(&wbc_data->wbc_cv);
	mutex_exit(&wbc_data->wbc_lock);

	return (0);
}

void
wbc_walk_unlock(spa_t *spa)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	mutex_enter(&wbc_data->wbc_lock);
	wbc_data->wbc_locked = B_FALSE;
	cv_broadcast(&wbc_data->wbc_cv);
	mutex_exit(&wbc_data->wbc_lock);
}

/* thread to collect blocks that must be moved */
static void
wbc_walk_thread(wbc_data_t *wbc_data)
{
	spa_t *spa = wbc_data->wbc_spa;
	int err = 0;

	DTRACE_PROBE1(wbc_walk_thread_start, char *, spa->spa_name);

	for (;;) {
		err = 0;
		mutex_enter(&wbc_data->wbc_lock);

		wbc_data->wbc_walking = B_FALSE;

		cv_broadcast(&wbc_data->wbc_cv);

		/* Set small wait time to delay walker restart */
		do {
			(void) cv_timedwait(&wbc_data->wbc_cv,
			    &wbc_data->wbc_lock,
			    ddi_get_lbolt() + hz / 4);
		} while (spa->spa_state == POOL_STATE_UNINITIALIZED &&
		    !wbc_data->wbc_thr_exit);

		if (wbc_data->wbc_thr_exit || !spa->spa_dsl_pool) {
			mutex_exit(&wbc_data->wbc_lock);
			break;
		}

		wbc_data->wbc_walking = B_TRUE;

		cv_broadcast(&wbc_data->wbc_cv);

		mutex_exit(&wbc_data->wbc_lock);

		err = wbc_collect_special_blocks(spa->spa_dsl_pool);
		if (err != 0) {
			cmn_err(CE_WARN, "WBC: can not "
			    "traverse pool: error [%d]. "
			    "Current window will be purged\n", err);

			wbc_purge_window(spa, NULL);
		}
	}

	wbc_data->wbc_walk_thread = NULL;

	DTRACE_PROBE1(wbc_walk_thread_done, char *, spa->spa_name);

	thread_exit();
}

int wbc_force_trigger = 1;
/*
 * This function triggers the write cache thread if the past
 * two sync context dif not sync more than 1/8th of
 * zfs_dirty_data_sync.
 * This function is called only if the current sync context
 * did not sync more than 1/16th of zfs_dirty_data_sync.
 */
void
wbc_trigger_wbcthread(spa_t *spa, uint64_t prev_sync_avg)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);

	/*
	 * Using mutex_tryenter() because if the worker is
	 * holding the mutex, it is already up, no need
	 * to cv_signal()
	 */
	if ((wbc_force_trigger || prev_sync_avg < zfs_dirty_data_sync / 8) &&
	    mutex_tryenter(&wbc_data->wbc_lock)) {
		if (wbc_data->wbc_blocks_count != 0) {
			DTRACE_PROBE1(wbc_trigger_worker, char *,
			    spa->spa_name);
			cv_signal(&wbc_data->wbc_cv);
		}
		mutex_exit(&wbc_data->wbc_lock);
	}
}

static boolean_t
wbc_should_pause_scanblocks(dsl_pool_t *dp,
    wbc_parseblock_cb_t *cbd, const zbookmark_phys_t *zb)
{
	hrtime_t elapsed_ns;

	/*
	 * We know how to resume iteration on level 0
	 * blocks only
	 */
	if (zb->zb_level != 0)
		return (B_FALSE);

	/* We're resuming */
	if (!ZB_IS_ZERO(&cbd->zb))
		return (B_FALSE);

	/*
	 * We should stop if either traversal time
	 * took more than zfs_txg_timeout or it took
	 * more zfs_scan_min_time while somebody is waiting
	 * for our transaction group.
	 */
	elapsed_ns = gethrtime() - cbd->start_time;
	if (elapsed_ns / NANOSEC > zfs_txg_timeout ||
	    (elapsed_ns / MICROSEC > zfs_scan_min_time_ms &&
	    txg_sync_waiting(dp)) || spa_shutting_down(dp->dp_spa))
		return (B_TRUE);

	return (B_FALSE);
}

/*
 * Callback passed in traversal function. Checks whether block is
 * special and hence should be planned for move
 */
/* ARGSUSED */
int
wbc_traverse_ds_cb(spa_t *spa, zilog_t *zilog, const blkptr_t *bp,
    const zbookmark_phys_t *zb, const dnode_phys_t *dnp, void *arg)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	wbc_parseblock_cb_t *cbd = arg;
	wbc_block_t *block, *found_block;
	avl_index_t where = NULL;
	boolean_t increment_counters = B_FALSE;

	/* skip ZIL blocks */
	if (bp == NULL || zb->zb_level == ZB_ZIL_LEVEL)
		return (0);

	if (!BP_IS_SPECIAL(bp))
		return (0);

	mutex_enter(&wbc_data->wbc_lock);

	if (wbc_data->wbc_thr_exit) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ERESTART);
	}

	if (cbd->actv_txg != wbc_data->wbc_finish_txg) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ERESTART);
	}

	if (wbc_should_pause_scanblocks(spa->spa_dsl_pool, cbd, zb)) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ERESTART);
	}

	/*
	 * If dedup is enabled then travesal gives us the original block,
	 * that already moved as part of previous WBC-win.
	 * So just skip it.
	 */
	if (BP_PHYSICAL_BIRTH(bp) < wbc_data->wbc_start_txg) {
		mutex_exit(&wbc_data->wbc_lock);
		return (0);
	}

	block = wbc_create_block(wbc_data, bp);
	if (block == NULL) {
		mutex_exit(&wbc_data->wbc_lock);
		return (ERESTART);
	}

	/*
	 * Before add the block to the tree of planned tree need
	 * to check that:
	 *  - a block with the same DVA is not contained in one of
	 *  out trees (planned of moved)
	 *  - a block is contained in a tree, so need to check that:
	 *		- DVA already freed: need to free the corresponding
	 *		wbc_block and add new wbc_block to
	 *		the tree of planned blocks. This is possible if
	 *		DVA was freed and later allocated for another data.
	 *
	 *		- DVA still allocated: is not required to add
	 *		the new block to the tree of planned blocks,
	 *		so just free it. This is possible if deduplication
	 *		is enabled
	 */
	found_block = avl_find(&wbc_data->wbc_moved_blocks, block, NULL);
	if (found_block != NULL) {
		if (WBCBP_IS_DELETED(found_block)) {
			avl_remove(&wbc_data->wbc_moved_blocks, found_block);
			wbc_free_block(found_block);
			goto insert;
		} else {
			wbc_free_block(block);
			goto out;
		}
	}

	found_block = avl_find(&wbc_data->wbc_blocks, block, &where);
	if (found_block != NULL) {
		if (WBCBP_IS_DELETED(found_block)) {
			avl_remove(&wbc_data->wbc_blocks, found_block);
			wbc_free_block(found_block);
			goto insert;
		} else {
			wbc_free_block(block);
			goto out;
		}
	}

	increment_counters = B_TRUE;

insert:
	avl_insert(&wbc_data->wbc_blocks, block, where);
	cbd->bt_size += WBCBP_GET_PSIZE(block);
	if (increment_counters) {
		wbc_data->wbc_blocks_count++;
		wbc_data->wbc_blocks_in++;
	}

out:
	mutex_exit(&wbc_data->wbc_lock);

	return (0);
}

/*
 * Iterate through data blocks on a "special" device and collect those
 * ones that can be moved to other devices in a pool.
 *
 * XXX: For now we collect as many blocks as possible in order to dispatch
 * them to the taskq later. It may be reasonable to invent a mechanism
 * which will allow not to store the whole `moving` tree in-core
 * (persistent move bookmark, for example)
 */
int
wbc_collect_special_blocks(dsl_pool_t *dp)
{
	spa_t *spa = dp->dp_spa;
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	wbc_parseblock_cb_t cb_data;
	int err = 0;
	hrtime_t scan_start;
	uint64_t diff;

	if (!zfs_wbc_schedtmo)
		zfs_wbc_schedtmo = zfs_txg_timeout * 2;

	scan_start = gethrtime();
	diff = scan_start - dp->dp_spec_rtime;
	if (diff / NANOSEC < zfs_wbc_schedtmo)
		return (0);

	cb_data.wbc_data = wbc_data;
	cb_data.zb = spa->spa_lszb;
	cb_data.start_time = scan_start;
	cb_data.actv_txg = wbc_data->wbc_finish_txg;
	cb_data.bt_size = 0ULL;

	/*
	 * Traverse the range of txg to collect blocks
	 */
	if (wbc_data->wbc_walk && wbc_data->wbc_finish_txg) {
		if (krrp_debug) {
			cmn_err(CE_NOTE, "WBC: new window (%llu; %llu)",
			    (unsigned long long)wbc_data->wbc_start_txg,
			    (unsigned long long)wbc_data->wbc_finish_txg);
		}
		err = traverse_pool(spa, wbc_data->wbc_start_txg - 1,
		    wbc_data->wbc_finish_txg + 1,
		    TRAVERSE_PREFETCH_METADATA | TRAVERSE_POST,
		    wbc_traverse_ds_cb, &cb_data, &cb_data.zb);
	}

	spa->spa_lszb = cb_data.zb;
	if (err != ERESTART && err != EAGAIN && (cb_data.bt_size == 0ULL) ||
	    ZB_IS_ZERO(&cb_data.zb)) {
		/*
		 * No more blocks to move or error state
		 */
		mutex_enter(&wbc_data->wbc_lock);
		wbc_data->wbc_walk = B_FALSE;
		if (err) {
			/*
			 * Something went wrong during the traversing
			 */
			if (wbc_data->wbc_thr_exit) {
				mutex_exit(&wbc_data->wbc_lock);
				return (0);
			}

			cmn_err(CE_WARN,
			    "WBC: Can not collect data "
			    "because of error [%d]", err);

			wbc_purge_window(spa, NULL);
			wbc_data->wbc_wait_for_window = B_TRUE;
			mutex_exit(&wbc_data->wbc_lock);

			err = 0;
		} else if (wbc_data->wbc_blocks_in == wbc_data->wbc_blocks_mv &&
		    !wbc_data->wbc_purge) {
			/* Everything is moved, close the window */
			if (wbc_data->wbc_finish_txg != 0)
				wbc_close_window(wbc_data);

			/*
			 * Process of the window closing might be
			 * interrupted by wbc_purge_window()
			 * (e.g., when the pool gets destroyed, etc.)
			 * If this is the case we simply return. New
			 * WBC window will be opened later upon completion
			 * of the purge..
			 */
			if (wbc_data->wbc_purge) {
				mutex_exit(&wbc_data->wbc_lock);
				return (0);
			}


			/* Say to others that walking stopped */
			wbc_data->wbc_walking = B_FALSE;
			wbc_data->wbc_wait_for_window = B_TRUE;
			cv_broadcast(&wbc_data->wbc_cv);

			/* and wait until a new window appears */
			while (!wbc_data->wbc_walk && !wbc_data->wbc_thr_exit) {
				cv_wait(&wbc_data->wbc_cv,
				    &wbc_data->wbc_lock);
			}

			if (wbc_data->wbc_thr_exit) {
				mutex_exit(&wbc_data->wbc_lock);
				return (0);
			}

			mutex_exit(&wbc_data->wbc_lock);

			dsl_sync_task(spa->spa_name, NULL,
			    wbc_write_update_window, spa,
			    ZFS_SPACE_CHECK_NONE, 0);
		} else {
			mutex_exit(&wbc_data->wbc_lock);
		}


	} else if (err == ERESTART) {
		/*
		 * We were interrupted, the iteration will be
		 * resumed later.
		 */
		DTRACE_PROBE2(traverse__intr, spa_t *, spa,
		    wbc_parseblock_cb_t *, &cb_data);
		err = 0;
	}

	dp->dp_spec_rtime = gethrtime();

	return (err);
}

/* WBC-THREAD_CONTROL */

/* Starts WBC threads and set associated structures */
void
wbc_start_thread(spa_t *spa)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	boolean_t lock_held;

	ASSERT(strcmp(spa->spa_name, TRYIMPORT_NAME) != 0);
	ASSERT(wbc_data->wbc_isvalid);

	lock_held = MUTEX_HELD(&wbc_data->wbc_lock);
	if (!lock_held)
		mutex_enter(&wbc_data->wbc_lock);

	if (wbc_data->wbc_thread == NULL && wbc_data->wbc_walk_thread == NULL) {
		wbc_data->wbc_thr_exit = B_FALSE;
#ifdef _KERNEL
		wbc_data->wbc_thread = thread_create(NULL, 0,
		    wbc_thread, wbc_data, 0, &p0, TS_RUN, maxclsyspri);
		wbc_data->wbc_walk_thread = thread_create(NULL, 0,
		    wbc_walk_thread, wbc_data, 0, &p0, TS_RUN, maxclsyspri);
		spa_start_perfmon_thread(spa);
#endif
	}

	wbc_data->wbc_wait_for_window = B_TRUE;
	if (!lock_held)
		mutex_exit(&wbc_data->wbc_lock);
}

/* Disables WBC thread and reset associated data structures */
boolean_t
wbc_stop_thread(spa_t *spa)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	boolean_t stop = B_FALSE;

	stop |= spa_stop_perfmon_thread(spa);
	mutex_enter(&wbc_data->wbc_lock);

	/*
	 * We do not want to wait the finishing of migration,
	 * because it can take a long time
	 */
	wbc_purge_window(spa, NULL);
	wbc_data->wbc_wait_for_window = B_FALSE;

	if (wbc_data->wbc_thread != NULL || wbc_data->wbc_walk_thread != NULL) {
		wbc_data->wbc_thr_exit = B_TRUE;
		cv_broadcast(&wbc_data->wbc_cv);
		mutex_exit(&wbc_data->wbc_lock);
#ifdef _KERNEL
		if (wbc_data->wbc_thread)
			thread_join(wbc_data->wbc_thread->t_did);
		if (wbc_data->wbc_walk_thread)
			thread_join(wbc_data->wbc_walk_thread->t_did);
#endif
		mutex_enter(&wbc_data->wbc_lock);
		wbc_data->wbc_thread = NULL;
		wbc_data->wbc_walk_thread = NULL;
		stop |= B_TRUE;
	}

	wbc_clean_plan_tree(wbc_data);
	wbc_clean_moved_tree(wbc_data);

	mutex_exit(&wbc_data->wbc_lock);

	return (stop);
}

/* WBC-WND routines */

#define	DMU_POOL_WBC_START_TXG "wbc_start_txg"
#define	DMU_POOL_WBC_FINISH_TXG "wbc_finish_txg"
#define	DMU_POOL_WBC_TO_RELE_TXG "wbc_to_rele_txg"
#define	DMU_POOL_WBC_STATE_DELETE "wbc_state_delete"

/* On-disk WBC parameters alternation */

static void
wbc_set_state_delete(void *void_spa, dmu_tx_t *tx)
{
	uint64_t upd = 1;
	spa_t *spa = void_spa;

	(void) zap_update(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_STATE_DELETE, sizeof (uint64_t), 1, &upd, tx);
}

static void
wbc_clean_state_delete(void *void_spa, dmu_tx_t *tx)
{
	uint64_t upd = 0;
	spa_t *spa = void_spa;

	(void) zap_update(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_STATE_DELETE, sizeof (uint64_t), 1, &upd, tx);
}

static void
wbc_write_update_window(void *void_spa, dmu_tx_t *tx)
{
	spa_t *spa = void_spa;
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);

	if (wbc_data->wbc_finish_txg == 0) {
		/*
		 * The "delete" state is not valid,
		 * because window has been closed or purged
		 */
		wbc_clean_state_delete(void_spa, tx);
	}

	(void) zap_update(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_START_TXG, sizeof (uint64_t), 1,
	    &wbc_data->wbc_start_txg, tx);
	(void) zap_update(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_FINISH_TXG, sizeof (uint64_t), 1,
	    &wbc_data->wbc_finish_txg, tx);
	(void) zap_update(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_TO_RELE_TXG, sizeof (uint64_t), 1,
	    &wbc_data->wbc_txg_to_rele, tx);
}

static void
wbc_close_window_impl(spa_t *spa, avl_tree_t *tree)
{
	wbc_block_t *node;
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	dmu_tx_t *tx;
	int err;
	uint64_t txg;
	void *cookie = NULL;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	wbc_data->wbc_delete = B_TRUE;

	mutex_exit(&wbc_data->wbc_lock);
	/*
	 * Set flag that WBC has finished moving the window and
	 * freeing special dvas now
	 */
	dsl_sync_task(spa->spa_name, NULL,
	    wbc_set_state_delete, spa, 0, ZFS_SPACE_CHECK_NONE);

	tx = dmu_tx_create_dd(spa->spa_dsl_pool->dp_mos_dir);
	err = dmu_tx_assign(tx, TXG_WAIT);

	VERIFY(err == 0);

	txg = tx->tx_txg;

	mutex_enter(&wbc_data->wbc_lock);

	/*
	 * There was a purge while delete state was being written
	 * Everything is reset so no frees are required or allowed
	 */
	if (wbc_data->wbc_delete == B_FALSE) {
		dmu_tx_commit(tx);
		return;
	}

	/*
	 * Clean the tree of moved blocks, free special dva and
	 * wbc_block structure of every block in the tree
	 */
	spa_config_enter(spa, SCL_VDEV, FTAG, RW_READER);
	while ((node = avl_destroy_nodes(tree, &cookie)) != NULL) {
		if (!WBCBP_IS_DELETED(node)) {
			metaslab_free_dva(spa, &node->dva[WBC_SPECIAL_DVA],
			    tx->tx_txg, B_FALSE);
		}

		wbc_free_block(node);
	}
	spa_config_exit(spa, SCL_VDEV, FTAG);

	/* Move left boundary of the window and reset the right one */
	wbc_data->wbc_start_txg = wbc_data->wbc_finish_txg + 1;
	wbc_data->wbc_finish_txg = 0;
	wbc_data->wbc_txg_to_rele = 0;
	wbc_data->wbc_roll_threshold = wbc_mv_cancel_threshold_initial;
	wbc_data->wbc_delete = B_FALSE;

	wbc_data->wbc_blocks_mv_last = wbc_data->wbc_blocks_mv;

	wbc_data->wbc_blocks_in = 0;
	wbc_data->wbc_blocks_out = 0;
	wbc_data->wbc_blocks_mv = 0;

	/* Write down new boundaries */
	dsl_sync_task_nowait(spa->spa_dsl_pool,
	    wbc_write_update_window, spa, 0, ZFS_SPACE_CHECK_NONE, tx);
	dmu_tx_commit(tx);

	mutex_exit(&wbc_data->wbc_lock);

	/* Wait frees and WBC parameters to be synced to disk */
	txg_wait_synced(spa->spa_dsl_pool, txg);

	mutex_enter(&wbc_data->wbc_lock);
}

/* Close the WBC window and release the snapshot of its right boundary */
static void
wbc_close_window(wbc_data_t *wbc_data)
{
	spa_t *spa = wbc_data->wbc_spa;
	uint64_t txg_to_rele = wbc_data->wbc_txg_to_rele;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	ASSERT0(wbc_data->wbc_blocks_count);
	ASSERT(avl_is_empty(&wbc_data->wbc_blocks));

	VERIFY(wbc_data->wbc_finish_txg != 0);

	if (krrp_debug) {
		cmn_err(CE_NOTE, "WBC: window (%llu; %llu) has been completed\n"
		    "WBC: %llu blocks moved",
		    (unsigned long long)wbc_data->wbc_start_txg,
		    (unsigned long long)wbc_data->wbc_finish_txg,
		    (unsigned long long)wbc_data->wbc_blocks_mv);
		VERIFY(wbc_data->wbc_blocks_mv == wbc_data->wbc_blocks_in);
		VERIFY(wbc_data->wbc_blocks_mv == wbc_data->wbc_blocks_out);
	}

	wbc_close_window_impl(spa, &wbc_data->wbc_moved_blocks);

	wbc_rele_autosnaps(wbc_data, txg_to_rele, B_FALSE);
}

/*
 * To fini of a wbc_instance need to inherit wbc_mode.
 * During this operation will be called wbc_process_objset()
 * that will unregister this instance and destroy it
 */
static void
wbc_instance_finalization(void *arg)
{
	wbc_instance_t *wbc_instance = arg;

	ASSERT(wbc_instance->fini_done);

#ifdef _KERNEL
	/*
	 * NVL needs to be populated here, because after
	 * calling dsl_prop_inherit() wbc_instance cannot
	 * be used
	 */
	nvlist_t *event;
	event = fnvlist_alloc();
	fnvlist_add_string(event, "fsname", wbc_instance->ds_name);
#endif

	VERIFY3U(dsl_prop_inherit(wbc_instance->ds_name,
	    zfs_prop_to_name(ZFS_PROP_WBC_MODE),
	    ZPROP_SRC_INHERITED), ==, 0);

#ifdef _KERNEL
	zfs_event_post(ZFS_EC_STATUS, "wbc_done", event);
#endif
}

static void
wbc_rele_autosnaps(wbc_data_t *wbc_data, uint64_t txg_to_rele,
    boolean_t purge)
{
	wbc_instance_t *wbc_instance;

	wbc_instance = avl_first(&wbc_data->wbc_instances);
	while (wbc_instance != NULL) {
		if (wbc_instance->txg_to_rele != 0) {
			VERIFY3U(wbc_instance->txg_to_rele,
			    ==, txg_to_rele);
			if (wbc_instance->fini_migration &&
			    txg_to_rele > wbc_instance->txg_off && !purge) {
				/*
				 * This WBC instance will be terminated in
				 * the preallocated taskq
				 *
				 * WBC instance termination involves writing
				 * and therefore requires sync context.
				 * But since we are here already in the sync
				 * context, the operation is task-dispatched
				 */
				wbc_data->wbc_instance_fini_cnt--;
				wbc_instance->fini_done = B_TRUE;
				VERIFY(taskq_dispatch(
				    wbc_data->wbc_instance_fini,
				    wbc_instance_finalization, wbc_instance,
				    TQ_SLEEP) != NULL);
			} else if (wbc_instance->fini_migration) {
				autosnap_force_snap_fast(
				    wbc_instance->wbc_autosnap_hdl);
			}

			autosnap_release_snapshots_by_txg(
			    wbc_instance->wbc_autosnap_hdl,
			    txg_to_rele, AUTOSNAP_NO_SNAP);
			wbc_instance->txg_to_rele = 0;
		} else if (wbc_instance->fini_migration) {
			autosnap_force_snap_fast(
			    wbc_instance->wbc_autosnap_hdl);
		}

		wbc_instance = AVL_NEXT(&wbc_data->wbc_instances,
		    wbc_instance);
	}
}

/*
 * Purge pending blocks and reset right boundary.
 * It is used when dataset is deleted or an error
 * occured during traversing. If called in the
 * context of the sync thread, then syncing tx must
 * be passed. Outside the syncing thread NULL is
 * expected instead.
 */
void
wbc_purge_window(spa_t *spa, dmu_tx_t *tx)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	uint64_t snap_txg;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	if (wbc_data->wbc_finish_txg == 0)
		return;

	/*
	 * Clean tree with blocks which are not queued
	 * to be moved yet
	 */
	wbc_clean_plan_tree(wbc_data);

	/*
	 * Set purge on to notify move workers to skip all
	 * blocks that are left in queue not to waste time
	 * moving data which will be required to move again.
	 * Wait until all queued blocks are processed.
	 */
	wbc_data->wbc_purge = B_TRUE;

	/*
	 * Reset the deletion flag to make sure
	 * that the purge is appreciated by
	 * dva[0] deleter
	 */
	wbc_data->wbc_delete = B_FALSE;

	while (wbc_data->wbc_blocks_out !=
	    wbc_data->wbc_blocks_mv &&
	    !wbc_data->wbc_thr_exit) {
		(void) cv_timedwait(&wbc_data->wbc_cv,
		    &wbc_data->wbc_lock,
		    ddi_get_lbolt() + 1000);
	}

	/*
	 * Clean the tree of moved blocks
	 */
	wbc_clean_moved_tree(wbc_data);

	wbc_data->wbc_blocks_in = 0;
	wbc_data->wbc_blocks_out = 0;
	wbc_data->wbc_blocks_mv = 0;

	/* Reset bookmark */
	bzero(&spa->spa_lszb, sizeof (spa->spa_lszb));

	snap_txg = wbc_data->wbc_txg_to_rele;

	/*
	 * Reset right boundary and time of latest window
	 * start to catch the closest snapshot which will be
	 * created
	 */
	wbc_data->wbc_finish_txg = 0;
	wbc_data->wbc_txg_to_rele = 0;
	wbc_data->wbc_latest_window_time = 0;
	wbc_data->wbc_roll_threshold =
	    MIN(wbc_data->wbc_roll_threshold + wbc_mv_cancel_threshold_step,
	    wbc_mv_cancel_threshold_cap);

	if (krrp_debug)
		cmn_err(CE_NOTE, "WBC: Right boundary will be moved forward");

	if (tx) {
		dsl_sync_task_nowait(spa->spa_dsl_pool,
		    wbc_write_update_window, spa, 0, ZFS_SPACE_CHECK_NONE, tx);
	} else {
		/*
		 * It is safe to drop the lock as the function has already
		 * set everything it wanted up to the moment and only need
		 * to update on-disk format
		 */
		mutex_exit(&wbc_data->wbc_lock);

		dsl_sync_task(spa->spa_name, NULL,
		    wbc_write_update_window, spa, 0, ZFS_SPACE_CHECK_NONE);
		mutex_enter(&wbc_data->wbc_lock);
	}

	wbc_rele_autosnaps(wbc_data, snap_txg, B_TRUE);

	/* Purge done */
	wbc_data->wbc_purge = B_FALSE;
}

/* Finalize interrupted with power cycle window */
static void
wbc_free_restore(spa_t *spa)
{
	uint64_t ret;
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	int err = zap_lookup(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_STATE_DELETE, sizeof (uint64_t), 1, &ret);
	boolean_t need_restore = err ? B_FALSE : (!!ret);
	wbc_parseblock_cb_t cb_data = { 0 };

	if (!need_restore) {
		wbc_data->wbc_finish_txg = 0;
		wbc_data->wbc_txg_to_rele = 0;
		return;
	}

	/*
	 * The mutex must be dropped to prevent recursive entry
	 * It is safe as we are the only user of the WBC structures
	 * at the point
	 */
	mutex_exit(&wbc_data->wbc_lock);
	cb_data.wbc_data = wbc_data;
	err = traverse_pool(spa, wbc_data->wbc_start_txg - 1,
	    wbc_data->wbc_finish_txg + 1,
	    TRAVERSE_PREFETCH_METADATA | TRAVERSE_POST,
	    wbc_traverse_ds_cb, &cb_data, &cb_data.zb);

	mutex_enter(&wbc_data->wbc_lock);

	wbc_close_window_impl(spa, &wbc_data->wbc_blocks);
	wbc_data->wbc_blocks_count = 0;
}

/*
 * The bool returned from this function tells to autosnapper
 * whether to take a new autosnapshot or not.
 * The new autosnapshot is used as the right boundary for a new
 * writecache migration window.
 */
/*ARGSUSED*/
static boolean_t
wbc_confirm_cb(const char *name, boolean_t recursive, uint64_t txg, void *arg)
{
	wbc_instance_t *wbc_instance = arg;
	wbc_data_t *wbc_data = wbc_instance->wbc_data;

	/*
	 * The conditions are:
	 * - no active writecache window currently
	 * - writecache is not locked
	 * - used space on special vdev is at or above min-watermark
	 * or an instance waits for finalization
	 */
	return (wbc_data->wbc_wait_for_window && !wbc_data->wbc_locked &&
	    (!wbc_check_space(wbc_data->wbc_spa) ||
	    wbc_data->wbc_instance_fini_cnt != 0));
}

uint64_t wbc_window_roll_delay_ms = 0;

static boolean_t
wbc_check_time(wbc_data_t *wbc_data)
{
#ifdef _KERNEL
	if (wbc_window_roll_delay_ms == 0)
		return (B_FALSE);

	uint64_t time_spent =
	    ddi_get_lbolt() - wbc_data->wbc_latest_window_time;
	return (time_spent < drv_usectohz(wbc_window_roll_delay_ms * MILLISEC));
#else
	return (B_FALSE);
#endif
}

/*
 * Returns B_TRUE if the percentage of used space on special vdev
 * is below ZPOOL_PROP_MINWATERMARK ("min-watermark", MIN_WN),
 * otherwise returns B_FALSE.
 *
 * Based on this return wbc_confirm_cb() caller either opens
 * a new writecache window, or not. In the latter case, when
 * the used space remains below min-watermark, writecache migration
 * does not run.
 *
 * Similarly to low-watermark and high-watermark that control
 * special vdev's used space and the rate of its utilization,
 * the min-watermark is a pool's property that can be set via:
 *
 * 'zpool set min-watermark <pool name>'
 *
 */
static boolean_t
wbc_check_space(spa_t *spa)
{
	uint64_t percentage =
	    spa_class_alloc_percentage(spa_special_class(spa));

	return (percentage < spa->spa_minwat);
}

/* Autosnap notification callback */
/*ARGSUSED*/
static boolean_t
wbc_nc_cb(const char *name, boolean_t recursive, boolean_t autosnap,
    uint64_t txg, uint64_t etxg, void *arg)
{
	boolean_t result = B_FALSE;
	wbc_instance_t *wbc_instance = arg;
	wbc_data_t *wbc_data = wbc_instance->wbc_data;

	mutex_enter(&wbc_data->wbc_lock);
	if (!wbc_data->wbc_isvalid) {
		mutex_exit(&wbc_data->wbc_lock);
		return (B_FALSE);
	}

	if (wbc_data->wbc_finish_txg != 0) {
		if (wbc_data->wbc_finish_txg == etxg &&
		    !wbc_instance->fini_done) {
			/* Same window-snapshot for another WBC-Instance */
			wbc_instance->txg_to_rele = txg;
			result = B_TRUE;
		}

		mutex_exit(&wbc_data->wbc_lock);
		return (result);
	}

	if (wbc_data->wbc_walking) {
		/* Current window already done, but is not closed yet */
		result = B_FALSE;
	} else if (wbc_data->wbc_locked) {
		/* WBC is locked by an external caller */
		result = B_FALSE;
	} else if (wbc_instance->fini_done) {
		/* Instance already done, so snapshot is not required */
		result = B_FALSE;
	} else {
		/* Accept new windows */
		VERIFY0(wbc_data->wbc_blocks_count);
		VERIFY(avl_is_empty(&wbc_data->wbc_blocks));
		wbc_data->wbc_latest_window_time = ddi_get_lbolt();
		wbc_data->wbc_first_move = B_FALSE;
		wbc_data->wbc_walk = B_TRUE;
		wbc_data->wbc_finish_txg = etxg;
		wbc_data->wbc_txg_to_rele = txg;
		wbc_data->wbc_altered_limit = 0;
		wbc_data->wbc_altered_bytes = 0;
		wbc_data->wbc_window_bytes = 0;
		wbc_data->wbc_fault_moves = 0;
		cv_broadcast(&wbc_data->wbc_cv);
		result = B_TRUE;
		wbc_instance->txg_to_rele = txg;
		wbc_data->wbc_wait_for_window = B_FALSE;
	}

	mutex_exit(&wbc_data->wbc_lock);
	return (result);
}

/*ARGSUSED*/
static void
wbc_err_cb(const char *name, int err, uint64_t txg, void *arg)
{
	if (krrp_debug) {
		cmn_err(CE_WARN, "Autosnap can not create a snapshot "
		    "for writecached dataset [%s] at txg %llu [%d]",
		    name, (unsigned long long)txg, err);
	}
}

void
wbc_add_bytes(spa_t *spa, uint64_t txg, uint64_t bytes)
{
	wbc_data_t *wbc_data = &spa->spa_wbc;

	mutex_enter(&wbc_data->wbc_lock);

	if (wbc_data->wbc_finish_txg == txg) {
		wbc_data->wbc_window_bytes += bytes;
		wbc_data->wbc_altered_limit =
		    wbc_data->wbc_window_bytes *
		    wbc_data->wbc_roll_threshold / 100;

		DTRACE_PROBE3(wbc_window_size, uint64_t, txg,
		    uint64_t, wbc_data->wbc_window_bytes,
		    uint64_t, wbc_data->wbc_altered_limit);
	}

	mutex_exit(&wbc_data->wbc_lock);
}

/* WBC-INIT routines */

void
wbc_activate(spa_t *spa, boolean_t pool_creation)
{
	if (spa_feature_is_enabled(spa, SPA_FEATURE_WBC))
		wbc_activate_impl(spa, pool_creation);
}

/*
 * This function is callback for dmu_objset_find_dp()
 * that is called during the initialization of WBC.
 *
 * Here we register wbc_instance for the given dataset
 * if WBC is activated for this datasets
 */
/* ARGSUSED */
static int
wbc_activate_instances(dsl_pool_t *dp, dsl_dataset_t *ds, void *arg)
{
	wbc_data_t *wbc_data = arg;
	objset_t *os = NULL;
	wbc_instance_t *wbc_instance = NULL;
	int rc = 0;

	(void) dmu_objset_from_ds(ds, &os);
	VERIFY(os != NULL);

	if (os->os_wbc_mode == ZFS_WBC_MODE_OFF)
		return (0);

	if (os->os_dsl_dataset->ds_object != os->os_wbc_root_ds_obj)
		return (0);

	mutex_enter(&wbc_data->wbc_lock);

	if (wbc_data->wbc_isvalid)
		wbc_instance = wbc_register_instance(wbc_data, os);
	else
		rc = EINTR;

	if (wbc_instance != NULL) {
		if (os->os_wbc_mode == ZFS_WBC_MODE_OFF_DELAYED) {
			wbc_instance->fini_migration = B_TRUE;
			wbc_instance->txg_off = os->os_wbc_off_txg;
			wbc_data->wbc_instance_fini_cnt++;
		}

		autosnap_force_snap_fast(wbc_instance->wbc_autosnap_hdl);
	}

	mutex_exit(&wbc_data->wbc_lock);

	return (rc);
}

/*
 * Second stage of the WBC initialization.
 *
 * We walk over all DS of the given pool to activate
 * wbc_instances for DSs with activated WBC
 */
static void
wbc_init_thread(void *arg)
{
	wbc_data_t *wbc_data = arg;
	spa_t *spa = wbc_data->wbc_spa;
	dsl_dataset_t *ds_root = NULL;
	uint64_t dd_root_object;
	int err;

	/*
	 * If the feature flag is active then need to
	 * lookup the datasets that have enabled WBC
	 */
	if (spa_feature_is_active(spa, SPA_FEATURE_WBC)) {
		dsl_pool_config_enter(spa_get_dsl(spa), FTAG);

		err = dsl_dataset_hold(spa_get_dsl(spa), spa->spa_name,
		    FTAG, &ds_root);
		if (err != 0) {
			dsl_pool_config_exit(spa_get_dsl(spa), FTAG);
			mutex_enter(&wbc_data->wbc_lock);
			goto out;
		}

		dd_root_object = ds_root->ds_dir->dd_object;
		dsl_dataset_rele(ds_root, FTAG);

		VERIFY0(dmu_objset_find_dp(spa_get_dsl(spa), dd_root_object,
		    wbc_activate_instances, wbc_data, DS_FIND_CHILDREN));

		dsl_pool_config_exit(spa_get_dsl(spa), FTAG);
	}

	mutex_enter(&wbc_data->wbc_lock);

	wbc_data->wbc_ready_to_use = B_TRUE;
	if (avl_numnodes(&wbc_data->wbc_instances) != 0 &&
	    !wbc_data->wbc_thr_exit)
		wbc_start_thread(wbc_data->wbc_spa);

out:
	wbc_data->wbc_init_thread = NULL;
	cv_broadcast(&wbc_data->wbc_cv);
	mutex_exit(&wbc_data->wbc_lock);
}

/*
 * Initialize WBC properties for the given pool.
 */
static void
wbc_activate_impl(spa_t *spa, boolean_t pool_creation)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);
	wbc_stat_t *wbc_stat = &wbc_data->wbc_stat;
	uint64_t spa_children = spa->spa_root_vdev->vdev_children;
	int err = 0;
	boolean_t hold = B_FALSE;

	mutex_enter(&wbc_data->wbc_lock);
	if (wbc_data->wbc_isvalid) {
		mutex_exit(&wbc_data->wbc_lock);
		return;
	}

	/* Reset bookmark */
	bzero(&spa->spa_lszb, sizeof (spa->spa_lszb));

	wbc_data->wbc_roll_threshold = wbc_mv_cancel_threshold_initial;
	wbc_data->wbc_altered_limit = 0;
	wbc_data->wbc_altered_bytes = 0;
	wbc_data->wbc_window_bytes = 0;

	/* Reset statistics */
	wbc_stat->wbc_spa_util = 0;
	wbc_stat->wbc_stat_lbolt = 0;
	wbc_stat->wbc_stat_update = B_FALSE;

	/* Number of WBC block-moving threads - taskq nthreads */
	wbc_data->wbc_move_threads = MIN(wbc_max_move_tasks_count,
	    spa_children * zfs_vdev_async_write_max_active);

	/*
	 * Read WBC parameters to restore
	 * latest WBC window's boundaries
	 */
	if (!rrw_held(&spa->spa_dsl_pool->dp_config_rwlock,
	    RW_WRITER)) {
		rrw_enter(&spa->spa_dsl_pool->dp_config_rwlock,
		    RW_READER, FTAG);
		hold = B_TRUE;
	}

	err = zap_lookup(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_START_TXG, sizeof (uint64_t), 1,
	    &wbc_data->wbc_start_txg);
	if (err)
		wbc_data->wbc_start_txg = 4;

	err = zap_lookup(spa->spa_dsl_pool->dp_meta_objset,
	    DMU_POOL_DIRECTORY_OBJECT,
	    DMU_POOL_WBC_FINISH_TXG, sizeof (uint64_t), 1,
	    &wbc_data->wbc_finish_txg);
	if (!err) {
		err = zap_lookup(spa->spa_dsl_pool->dp_meta_objset,
		    DMU_POOL_DIRECTORY_OBJECT,
		    DMU_POOL_WBC_TO_RELE_TXG, sizeof (uint64_t), 1,
		    &wbc_data->wbc_txg_to_rele);
	}

	if (hold)
		rrw_exit(&spa->spa_dsl_pool->dp_config_rwlock, FTAG);

	if (err) {
		wbc_data->wbc_finish_txg = 0;
		wbc_data->wbc_txg_to_rele = 0;
	}

	wbc_data->wbc_latest_window_time = ddi_get_lbolt();

	wbc_data->wbc_ready_to_use = B_FALSE;
	wbc_data->wbc_thr_exit = B_FALSE;
	wbc_data->wbc_purge = B_FALSE;
	wbc_data->wbc_walk = B_TRUE;
	wbc_data->wbc_spa = spa;
	wbc_data->wbc_isvalid = B_TRUE;
	wbc_data->wbc_instance_fini_cnt = 0;

	/* Finalize window interrupted by power cycle or reimport */
	wbc_free_restore(spa);

	if (pool_creation) {
		/* On create there is no reason to start init_thread */
		wbc_data->wbc_ready_to_use = B_TRUE;
	} else {
		/*
		 * On import need to restore wbc_instances.
		 * Do this asynchronously.
		 */
		wbc_data->wbc_init_thread = thread_create(NULL, 0,
		    wbc_init_thread, wbc_data, 0, &p0, TS_RUN, maxclsyspri);
	}

	mutex_exit(&wbc_data->wbc_lock);

	DTRACE_PROBE2(wbc_spa_add, char *, spa->spa_name,
	    spa_t *, spa);
}

void
wbc_deactivate(spa_t *spa)
{
	wbc_data_t *wbc_data = spa_get_wbc_data(spa);

	mutex_enter(&wbc_data->wbc_lock);

	if (!spa_has_special(spa) || !wbc_data->wbc_isvalid) {
		mutex_exit(&wbc_data->wbc_lock);
		return;
	}

	DTRACE_PROBE1(wbc_deactiv_start, char *, spa->spa_name);

	wbc_data->wbc_isvalid = B_FALSE;

	while (wbc_data->wbc_init_thread != NULL)
		cv_wait(&wbc_data->wbc_cv, &wbc_data->wbc_lock);

	wbc_unregister_instances(wbc_data);

	VERIFY(avl_is_empty(&wbc_data->wbc_blocks));
	VERIFY(avl_is_empty(&wbc_data->wbc_moved_blocks));

	DTRACE_PROBE1(wbc_deactiv_done, char *, spa->spa_name);

	mutex_exit(&wbc_data->wbc_lock);
}

/*
 * AVL comparison function (callback) for writeback-cached blocks.
 * This function defines the tree's sorting order which is:
 * (vdev, offset) ascending, where vdev and offset are the respective
 * vdev id and offset of the block.
 *
 * Returns -1 if (block1 < block2), 0 if (block1 == block2),
 * and 1 when (block1 > block2).
 */
static int
wbc_blocks_compare(const void *arg1, const void *arg2)
{
	wbc_block_t *block1 = (wbc_block_t *)arg1;
	wbc_block_t *block2 = (wbc_block_t *)arg2;

	/* calculate vdev and offset for block1 and block2 */
	uint64_t vdev1 = DVA_GET_VDEV(&block1->dva[WBC_SPECIAL_DVA]);
	uint64_t offset1 = DVA_GET_OFFSET(&block1->dva[WBC_SPECIAL_DVA]);
	uint64_t vdev2 = DVA_GET_VDEV(&block2->dva[WBC_SPECIAL_DVA]);
	uint64_t offset2 = DVA_GET_OFFSET(&block2->dva[WBC_SPECIAL_DVA]);

	/* compare vdev's and offsets */
	int cmp1 = (vdev1 < vdev2) ? (-1) : (vdev1 == vdev2 ? 0 : 1);
	int cmp2 = (offset1 < offset2) ? (-1) : (offset1 == offset2 ? 0 : 1);
	int cmp = (cmp1 == 0) ? cmp2 : cmp1;

	return (cmp);
}

static int
wbc_instances_compare(const void *arg1, const void *arg2)
{
	const wbc_instance_t *instance1 = arg1;
	const wbc_instance_t *instance2 = arg2;

	if (instance1->ds_object > instance2->ds_object)
		return (1);

	if (instance1->ds_object < instance2->ds_object)
		return (-1);

	return (0);
}

static int
wbc_io(wbc_io_type_t type, wbc_block_t *block, void *data)
{
	zio_t *zio;
	zio_type_t zio_type;
	vdev_t *vd;
	uint64_t bias;
	size_t dva_num;

	if (type == WBC_READ_FROM_SPECIAL) {
		zio_type = ZIO_TYPE_READ;
		dva_num = WBC_SPECIAL_DVA;
	} else {
		ASSERT(type == WBC_WRITE_TO_NORMAL);
		zio_type = ZIO_TYPE_WRITE;
		dva_num = WBC_NORMAL_DVA;
	}

	vd = vdev_lookup_top(block->data->wbc_spa,
	    DVA_GET_VDEV(&block->dva[dva_num]));
	bias = vd->vdev_children == 0 ? VDEV_LABEL_START_SIZE : 0;
	zio = zio_wbc(zio_type, vd, data, WBCBP_GET_PSIZE(block),
	    DVA_GET_OFFSET(&block->dva[dva_num]) + bias);

	return (zio_wait(zio));
}

/*
 * if birth_txg is less than windows, then block is on
 * normal device only otherwise it can be found on
 * special, because deletion goes under lock and until
 * deletion is done, the block is accessible on special
 */
int
wbc_select_dva(wbc_data_t *wbc_data, zio_t *zio)
{
	uint64_t stxg;
	uint64_t ftxg;
	uint64_t btxg;
	int c;

	mutex_enter(&wbc_data->wbc_lock);

	stxg = wbc_data->wbc_start_txg;
	ftxg = wbc_data->wbc_finish_txg;
	btxg = BP_PHYSICAL_BIRTH(zio->io_bp);

	if (ftxg && btxg > ftxg) {
		DTRACE_PROBE(wbc_read_special_after);
		c = WBC_SPECIAL_DVA;
	} else if (btxg >= stxg) {
		if (!ftxg && wbc_data->wbc_delete) {
			DTRACE_PROBE(wbc_read_normal);
			c = WBC_NORMAL_DVA;
		} else {
			DTRACE_PROBE(wbc_read_special_inside);
			c = WBC_SPECIAL_DVA;
		}
	} else {
		DTRACE_PROBE(wbc_read_normal);
		c = WBC_NORMAL_DVA;
	}

	mutex_exit(&wbc_data->wbc_lock);

	return (c);
}

/*
 * Checks if a special block has left the special device and has been fully
 * migrated by WBC to the normal pool.
 */
boolean_t
wbc_bp_is_migrated(wbc_data_t *wbc_data, const blkptr_t *bp)
{
	boolean_t result;

	ASSERT(BP_IS_SPECIAL(bp));
	mutex_enter(&wbc_data->wbc_lock);
	result = BP_PHYSICAL_BIRTH(bp) < wbc_data->wbc_start_txg;
	mutex_exit(&wbc_data->wbc_lock);

	return (result);
}

/*
 * 3 cases can be here
 * 1st - birth_txg is less than window - only normal device should be free
 * 2nd - inside window both trees are checked and if both of the trees
 *	haven't this block and deletion in process, then block is already
 *	freed, otherwise both dva are freed
 * 3rd - birth_txg is higher than window - both dva must be freed
 */
int
wbc_first_valid_dva(const blkptr_t *bp,
    wbc_data_t *wbc_data, boolean_t removal)
{
	int start_dva = 0;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	if (BP_PHYSICAL_BIRTH(bp) < wbc_data->wbc_start_txg) {
		start_dva = 1;
	} else if (BP_PHYSICAL_BIRTH(bp) <= wbc_data->wbc_finish_txg) {
		wbc_block_t search, *planned, *moved;

		/* Only DVA[0] is required for search */
		search.dva[WBC_SPECIAL_DVA] = bp->blk_dva[WBC_SPECIAL_DVA];

		moved = avl_find(&wbc_data->wbc_moved_blocks,
		    &search, NULL);
		if (moved != NULL && removal) {
			/*
			 * later WBC will do free for this block
			 */
			mutex_enter(&moved->lock);
			WBCBP_MARK_DELETED(moved);
			mutex_exit(&moved->lock);
		}

		planned = avl_find(&wbc_data->wbc_blocks,
		    &search, NULL);
		if (planned != NULL && removal) {
			avl_remove(&wbc_data->wbc_blocks, planned);
			wbc_free_block(planned);
		}

		if (planned == NULL && moved == NULL && wbc_data->wbc_delete)
			start_dva = 1;
	}

	return (start_dva);
}

/*
 * 1) for each dataset of the given pool at the dataset load time
 * 2) on each change of the wbc_mode property, for the dataset in
 * question and all its children
 *
 * see dsl_prop_register()/dsl_prop_unregister() and
 * dmu_objset_open_impl()/dmu_objset_evict()
 *
 * wbc_mode has 3 states:
 * ON, OFF - for user
 * OFF_DELAYED - for the internal using
 *
 * ON - generation of special BPs and migration
 * OFF_DELAYED - special BPs will not be created, but migration
 * still active to migrate. To migrate all blocks that still on SPECIAL
 * OFF - we migrated all blocks that were on special, so this instance
 * can be destroyed.
 */
void
wbc_mode_changed(void *arg, uint64_t newval)
{
	objset_t *os = arg;
	wbc_data_t *wbc_data = spa_get_wbc_data(os->os_spa);
	wbc_mode_prop_val_t *val =
	    (wbc_mode_prop_val_t *)((uintptr_t)newval);

	if (val->root_ds_object != 0) {
		os->os_wbc_root_ds_obj = val->root_ds_object;
		os->os_wbc_off_txg = val->txg_off;
		if (val->txg_off == 0)
			os->os_wbc_mode = ZFS_WBC_MODE_ON;
		else
			os->os_wbc_mode = ZFS_WBC_MODE_OFF_DELAYED;
	} else {
		if (os->os_wbc_mode == ZFS_WBC_MODE_OFF)
			return;

		os->os_wbc_mode = ZFS_WBC_MODE_OFF;
	}

	DTRACE_PROBE4(wbc_mc,
	    boolean_t, wbc_data->wbc_ready_to_use,
	    uint64_t, os->os_dsl_dataset->ds_object,
	    uint64_t, os->os_wbc_mode,
	    uint64_t, os->os_wbc_root_ds_obj);

	wbc_process_objset(wbc_data, os, B_FALSE);

	if (os->os_wbc_mode == ZFS_WBC_MODE_OFF) {
		os->os_wbc_root_ds_obj = 0;
		os->os_wbc_off_txg = 0;
	}
}

/*
 * This function is called:
 * 1) on change of wbc_mode property
 * 2) on destroying of a DS
 *
 * It processes only top-level DS of a WBC-DS-tree
 */
void
wbc_process_objset(wbc_data_t *wbc_data,
    objset_t *os, boolean_t destroy)
{
	wbc_instance_t *wbc_instance;
	size_t num_nodes_before, num_nodes_after;

	if (os->os_wbc_root_ds_obj == 0)
		return;

	mutex_enter(&wbc_data->wbc_lock);
	/* Do not register instances too early */
	if (!wbc_data->wbc_isvalid || !wbc_data->wbc_ready_to_use) {
		mutex_exit(&wbc_data->wbc_lock);
		return;
	}

	if (os->os_dsl_dataset->ds_object != os->os_wbc_root_ds_obj) {
		wbc_instance = wbc_lookup_instance(wbc_data,
		    os->os_wbc_root_ds_obj, NULL);

		/*
		 * If instance for us does not exist, then WBC
		 * should not be enabled for this DS
		 */
		if (wbc_instance == NULL)
			os->os_wbc_mode = ZFS_WBC_MODE_OFF;

		mutex_exit(&wbc_data->wbc_lock);
		return;
	}

	num_nodes_before = avl_numnodes(&wbc_data->wbc_instances);

	if (os->os_wbc_mode == ZFS_WBC_MODE_OFF || destroy) {
		wbc_unregister_instance(wbc_data, os, !destroy);
	} else {
		wbc_instance = wbc_register_instance(wbc_data, os);
		if (wbc_instance != NULL &&
		    os->os_wbc_mode == ZFS_WBC_MODE_OFF_DELAYED &&
		    !wbc_instance->fini_migration) {
			wbc_instance->fini_migration = B_TRUE;
			wbc_data->wbc_instance_fini_cnt++;
			wbc_instance->txg_off = os->os_wbc_off_txg;
			autosnap_force_snap_fast(
			    wbc_instance->wbc_autosnap_hdl);
		}

		if (wbc_instance == NULL) {
			/*
			 * We do not want to write data to special
			 * if the data will not be migrated, because
			 * registration failed
			 */
			os->os_wbc_mode = ZFS_WBC_MODE_OFF;
		}
	}

	num_nodes_after = avl_numnodes(&wbc_data->wbc_instances);

	mutex_exit(&wbc_data->wbc_lock);

	/*
	 * The first instance, so need to
	 * start the collector and the mover
	 */
	if ((num_nodes_after > num_nodes_before) &&
	    (num_nodes_before == 0)) {
		wbc_start_thread(wbc_data->wbc_spa);
	}

	/*
	 * The last instance, so need to
	 * stop the collector and the mover
	 */
	if ((num_nodes_after < num_nodes_before) &&
	    (num_nodes_after == 0)) {
		(void) wbc_stop_thread(wbc_data->wbc_spa);
	}
}

static wbc_instance_t *
wbc_register_instance(wbc_data_t *wbc_data, objset_t *os)
{
	dsl_dataset_t *ds = os->os_dsl_dataset;
	wbc_instance_t *wbc_instance;
	avl_index_t where = NULL;
	zfs_autosnap_t *autosnap;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	/* Is it already registered? */
	wbc_instance = wbc_lookup_instance(wbc_data,
	    ds->ds_object, &where);
	if (wbc_instance != NULL)
		return (wbc_instance);

	wbc_instance = kmem_zalloc(sizeof (wbc_instance_t), KM_SLEEP);
	wbc_instance->ds_object = ds->ds_object;
	wbc_instance->wbc_data = wbc_data;
	dsl_dataset_name(ds, wbc_instance->ds_name);
	autosnap = spa_get_autosnap(wbc_data->wbc_spa);
	wbc_instance->wbc_autosnap_hdl =
	    autosnap_register_handler_impl(autosnap, wbc_instance->ds_name,
	    AUTOSNAP_CREATOR | AUTOSNAP_DESTROYER |
	    AUTOSNAP_RECURSIVE | AUTOSNAP_WBC,
	    wbc_confirm_cb, wbc_nc_cb, wbc_err_cb, wbc_instance);
	if (wbc_instance->wbc_autosnap_hdl == NULL) {
		cmn_err(CE_WARN, "Cannot register autosnap handler "
		    "for WBC-Instance (%s)", wbc_instance->ds_name);
		kmem_free(wbc_instance, sizeof (wbc_instance_t));
		return (NULL);
	}

	DTRACE_PROBE2(register_done,
	    uint64_t, wbc_instance->ds_object,
	    char *, wbc_instance->ds_name);

	avl_insert(&wbc_data->wbc_instances, wbc_instance, where);

	return (wbc_instance);
}

static void
wbc_unregister_instance(wbc_data_t *wbc_data, objset_t *os,
    boolean_t rele_autosnap)
{
	dsl_dataset_t *ds = os->os_dsl_dataset;
	wbc_instance_t *wbc_instance;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	wbc_instance = wbc_lookup_instance(wbc_data, ds->ds_object, NULL);
	if (wbc_instance != NULL) {
		DTRACE_PROBE1(unregister_done,
		    uint64_t, wbc_instance->ds_object);

		avl_remove(&wbc_data->wbc_instances, wbc_instance);
		wbc_unregister_instance_impl(wbc_instance,
		    rele_autosnap && (wbc_instance->txg_to_rele != 0));
	}
}

static void
wbc_unregister_instances(wbc_data_t *wbc_data)
{
	void *cookie = NULL;
	wbc_instance_t *wbc_instance;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	while ((wbc_instance = avl_destroy_nodes(
	    &wbc_data->wbc_instances, &cookie)) != NULL)
		wbc_unregister_instance_impl(wbc_instance, B_FALSE);
}

static void
wbc_unregister_instance_impl(wbc_instance_t *wbc_instance,
    boolean_t rele_autosnap)
{
	if (rele_autosnap) {
		autosnap_release_snapshots_by_txg(
		    wbc_instance->wbc_autosnap_hdl,
		    wbc_instance->txg_to_rele,
		    AUTOSNAP_NO_SNAP);
	}

	autosnap_unregister_handler(wbc_instance->wbc_autosnap_hdl);
	kmem_free(wbc_instance, sizeof (wbc_instance_t));
}

static wbc_instance_t *
wbc_lookup_instance(wbc_data_t *wbc_data,
    uint64_t ds_object, avl_index_t *where)
{
	wbc_instance_t wbc_instance;

	ASSERT(MUTEX_HELD(&wbc_data->wbc_lock));

	wbc_instance.ds_object = ds_object;
	return (avl_find(&wbc_data->wbc_instances,
	    &wbc_instance, where));
}

/*
 * Returns:
 * 0  - the dataset is a top-level (root) writecached dataset
 * EOPNOTSUPP - the dataset is a writecached child
 * ENOTACTIVE - is not writecached
 * other zfs err - cannot open the pool, is busy, etc.
 */
int
wbc_check_dataset(const char *ds_name)
{
	int error;
	spa_t *spa = NULL;
	dsl_dataset_t *ds = NULL;
	objset_t *os = NULL;
	zfs_wbc_mode_t wbc_mode;
	uint64_t wbc_root_object, ds_object;

	error = spa_open(ds_name, &spa, FTAG);
	if (error != 0)
		return (error);

	dsl_pool_config_enter(spa_get_dsl(spa), FTAG);
	error = dsl_dataset_hold(spa_get_dsl(spa), ds_name, FTAG, &ds);
	if (error) {
		dsl_pool_config_exit(spa_get_dsl(spa), FTAG);
		spa_close(spa, FTAG);
		return (error);
	}

	error = dmu_objset_from_ds(ds, &os);
	dsl_pool_config_exit(spa_get_dsl(spa), FTAG);
	if (error) {
		dsl_dataset_rele(ds, FTAG);
		spa_close(spa, FTAG);
		return (error);
	}

	wbc_mode = os->os_wbc_mode;
	wbc_root_object = os->os_wbc_root_ds_obj;
	ds_object = ds->ds_object;
	dsl_dataset_rele(ds, FTAG);
	spa_close(spa, FTAG);

	if (wbc_mode != ZFS_WBC_MODE_OFF) {
		if (wbc_root_object != ds_object) {
			/* The child of writecached ds-tree */
			return (EOPNOTSUPP);
		}

		/* The root of writecached ds-tree */
		return (0);
	}

	/* not writecached */
	return (ENOTACTIVE);
}

/*
 * The function requires that all the writecache
 * instances are already disabled
 */
boolean_t
wbc_try_disable(wbc_data_t *wbc_data)
{
	boolean_t result = B_FALSE;

	mutex_enter(&wbc_data->wbc_lock);

	if (avl_numnodes(&wbc_data->wbc_instances) == 0) {
		wbc_data->wbc_isvalid = B_FALSE;
		result = B_TRUE;
	}

	mutex_exit(&wbc_data->wbc_lock);

	return (result);
}
