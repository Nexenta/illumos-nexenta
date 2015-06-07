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
 * Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * On the wrcache code: this is a reasonably solid piece of
 * code that we choose not to enable just yet (it is disabled in the
 * user-level code, such that it is not possible to set specialclass to
 * wrcache). We fully intend to turn this on in the next release, but we
 * feel that performance needs to be optimized, and other things adjusted.
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

extern int zfs_txg_timeout;
extern int zfs_scan_min_time_ms;
extern uint64_t zfs_dirty_data_sync;

/*
 * timeout (in seconds) that is used to schedule a job that moves
 * blocks from a special device to other deivices in a pool
 */
int zfs_wrc_schedtmo = 0;

/*
 * timeout (in seconds) that is used to schedule a job that moves
 * blocks from a special device to other deivices in a pool
 */
int zfs_special_schedtmo = 0;

/*
 * Global tunable which decides the throttling to special device when
 * special device storage is between high and low watermark.
 *
 * When the special device is full upto low watermark, we need to
 * start throttling writes to special device. This is done based on
 * what percentage extra data is present on special device from
 * low watermark with respect to high watermark. If special device is
 * upto 10% extra filled from low watermark, then 10% of write goes to
 * normal device and 90% goes to special device. Similarly, if special
 * device is upto 90% extra filled from low watermark, then 90% of write
 * goes to normal device and 10% goes to special device.
 *
 * The throttling is implemented in weighted round robin fashion. The
 * percentage writes is based on every 11 writes. If special device is
 * upto 10% extrafilled, then for every 11 writes, 1 write goes to
 * normal device and 10 writes goes to special device.
 * User can controll the throttling rate. zfs_wrc_max_normalwr determines
 * the maximum writes out of 11 writes that can go to normal device during
 * throttling. For eg: if zfs_wrc_max_normalwr is 5, whatever be the
 * percentage of extra usage from low water mark with regard to high
 * watermark, maximum write to normal device will be 5, so minimum writes
 * to sepcial device will be 11 - 5 = 6.
 */
uint8_t zfs_wrc_max_normalwr = 10;

int wrc_thr_timeout = 10;

/* Min space in wrc to start data movement */
uint64_t spa_wrc_min_space = 1 << 20;

uint64_t zfs_wrc_data_max = 48 << 20; /* Max data to migrate in a pass */

boolean_t dsl_wrc_move_block(wrc_block_t *block);

static inline void
wrc_setroute_perc(wrc_route_t *route)
{
	/*
	 * User can set zfs_wrc_routeperc_max  to any value < 255.
	 * But valid values are in the range 1 to 10. Set it to
	 * default, if it contains invalid value.
	 */
	if (zfs_wrc_max_normalwr > 10 || zfs_wrc_max_normalwr < 1)
		zfs_wrc_max_normalwr = 10;

	route->route_normal = (route->route_perc / 10) + 1;

	/*
	 * We should be considering zfs_wrc_max_normalwr if actual
	 * route_normal greater than zfs_wrc_max_normalwr.
	 */
	if (route->route_normal > zfs_wrc_max_normalwr)
		route->route_normal = zfs_wrc_max_normalwr;

	route->route_special = 11 - route->route_normal;
}

/*
 * This function sets the round robin weights for the spa.
 */
void
wrc_route_set(spa_t *spa, boolean_t init)
{
	uint8_t perc = spa->spa_wrc_perc - (spa->spa_wrc_perc % 10);
	wrc_route_t *route = &spa->spa_wrc_route;

	mutex_enter(&route->route_lock);
	/*
	 * We need not calculate the normal and special writes if this
	 * is not the initial call and the percentage has not changed.
	 * If percentage has not changed, the values have been previously
	 * set and weighted roundrobin is using the previously set values.
	 */
	if (!init && perc == route->route_perc)
		goto out;

	route->route_perc = perc;
	wrc_setroute_perc(route);

out:
	mutex_exit(&route->route_lock);

	DTRACE_PROBE3(wrc_route_set, int, route->route_perc,
	    int, route->route_special, int, route->route_normal);
}

/*
 * This function selects the metaslab class based on the weighted roundrobin
 * as explained above. When the weights come down to zero, they are again
 * re-initialized, but one less for special class, as we select the
 * special class for next write.
 */
metaslab_class_t *
wrc_select_class(spa_t *spa)
{
	metaslab_class_t *mc;
	wrc_route_t *route = &spa->spa_wrc_route;

	if (spa->spa_watermark != SPA_WM_LOW)
		return (spa_special_class(spa));

	mutex_enter(&route->route_lock);
	if (route->route_special) {
		mc = spa_special_class(spa);
		route->route_special--;
	} else if (route->route_normal) {
		mc = spa_normal_class(spa);
		route->route_normal--;
	} else  {
		wrc_setroute_perc(route);
		mc = spa_special_class(spa);
		/*
		 * Decrement one as we select special class for writing
		 * in this iteration.
		 */
		route->route_special--;
	}
	mutex_exit(&route->route_lock);

	return (mc);

}

/*
 * Thread to manage the data movement from
 * special devices to normal devices.
 * This thread runs as long as the spa is active.
 */
static void
spa_wrc_thread(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;
	wrc_block_t	*block = 0;
	wrc_blkhdr_t	*blkhdr;
	uint64_t	done_count = 0;

	DTRACE_PROBE1(wrc_thread_start, char *, spa->spa_name);

	mutex_enter(&wrc_data->wrc_lock);
	/* CONSTCOND */
	while (1) {
		uint64_t count, written_sz;

		wrc_data->wrc_block_count -= done_count;
		done_count = 0;
		do {
			cv_wait(&wrc_data->wrc_cv, &wrc_data->wrc_lock);
			if (spa->spa_state == POOL_STATE_UNINITIALIZED ||
			    wrc_data->wrc_thr_exit)
				goto out;
			count = wrc_data->wrc_block_count;
		} while (count <= 0);

		DTRACE_PROBE2(wrc_nblocks, char *, spa->spa_name,
		    uint64_t, count);

		written_sz = 0;
		while (count > 0) {
			boolean_t wrcthr_pause = B_FALSE;

			if (wrc_data->wrc_thr_exit)
				break;

			block = list_head(&wrc_data->wrc_blocks);
			if (block) {
				list_remove(&wrc_data->wrc_blocks, block);
				if (block->hdr && block->hdr->hdr_isvalid) {
					WRC_BLK_DECCOUNT(block);
					mutex_exit(&wrc_data->wrc_lock);
					wrcthr_pause =
					    dsl_wrc_move_block(block);
					mutex_enter(&wrc_data->wrc_lock);
					written_sz += block->size;
				}
				kmem_free(block, sizeof (*block));
			} else {
				break;
			}
			count--;
			done_count++;
			if (written_sz >= zfs_wrc_data_max || wrcthr_pause) {
				DTRACE_PROBE1(wrc_sleep, int, wrcthr_pause);
				break;
			}
		}
		DTRACE_PROBE2(wrc_nbytes, char *, spa->spa_name,
		    uint64_t, written_sz);
	}

out:
	/*
	 * Clean up the list.
	 */
	DTRACE_PROBE1(wrc_thread_stop, char *, spa->spa_name);

	while (block = list_head(&wrc_data->wrc_blocks)) {
		list_remove(&wrc_data->wrc_blocks, block);
		WRC_BLK_DECCOUNT(block);
		kmem_free(block, sizeof (*block));
	}
	wrc_data->wrc_block_count = 0;

	blkhdr = wrc_data->wrc_blkhdr_head;
	while (blkhdr) {
		boolean_t last = (blkhdr == blkhdr->next);
		wrc_data->wrc_blkhdr_head = blkhdr->next;
		wrc_data->wrc_blkhdr_head->prev = blkhdr->prev;
		blkhdr->prev->next = wrc_data->wrc_blkhdr_head;
		DTRACE_PROBE1(wrc_blkhdr, char *, blkhdr->ds_name);
		kmem_free(blkhdr, sizeof (*blkhdr));

		if (!last)
			blkhdr = wrc_data->wrc_blkhdr_head;
		else
			blkhdr = NULL;
	}
	wrc_data->wrc_blkhdr_head = NULL;
	wrc_data->wrc_thread = NULL;
	wrc_data->wrc_thr_exit = B_FALSE;
	mutex_exit(&wrc_data->wrc_lock);

	DTRACE_PROBE1(wrc_thread_done, char *, spa->spa_name);

	thread_exit();
}

void
start_wrc_thread(spa_t *spa)
{
	if (strcmp(spa->spa_name, TRYIMPORT_NAME) == 0)
		return;

	mutex_enter(&spa->spa_wrc.wrc_lock);
	if (spa->spa_wrc.wrc_thread == NULL) {
		spa->spa_wrc.wrc_thread = thread_create(NULL, 0,
		    spa_wrc_thread, spa, 0, &p0, TS_RUN, maxclsyspri);
		spa->spa_wrc.wrc_thr_exit = B_FALSE;
	}
	mutex_exit(&spa->spa_wrc.wrc_lock);
}

boolean_t
stop_wrc_thread(spa_t *spa)
{
	mutex_enter(&spa->spa_wrc.wrc_lock);
	if (spa->spa_wrc.wrc_thread != NULL) {
		spa->spa_wrc.wrc_thr_exit = B_TRUE;
		cv_signal(&spa->spa_wrc.wrc_cv);
		mutex_exit(&spa->spa_wrc.wrc_lock);
		thread_join(spa->spa_wrc.wrc_thread->t_did);
		return (B_TRUE);
	}

	mutex_exit(&spa->spa_wrc.wrc_lock);
	return (B_FALSE);
}

/*
 * This function triggers the write cache thread if the past
 * two sync context dif not sync more than 1/8th of
 * zfs_dirty_data_sync.
 * This function is called only if the current sync context
 * did not sync more than 1/16th of zfs_dirty_data_sync.
 */
void
wrc_trigger_wrcthread(spa_t *spa, uint64_t prev_sync_avg)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;

	/*
	 * Using mutex_tryenter() because if the worker is
	 * holding the mutex, it is already up, no need
	 * to cv_signal()
	 */
	if (prev_sync_avg < zfs_dirty_data_sync / 8 &&
	    mutex_tryenter(&wrc_data->wrc_lock)) {
		if (wrc_data->wrc_block_count) {
			DTRACE_PROBE1(wrc_trigger_worker, char *,
			    spa->spa_name);
			cv_signal(&wrc_data->wrc_cv);
		}
		mutex_exit(&wrc_data->wrc_lock);
	}
}

/*
 * If the pool has a "special" device working as a write
 * back cache, we need to move data from it to another disks
 * in the pool.
 *
 * Returns with wrc_lock held.
 */
boolean_t
wrc_check_parseblocks_hold(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;

	/*
	 * We don't proceed if
	 *  - spa does not have write cache devices
	 *  - write cache devices does not have more than spa_wrc_min_space
	 * 		data allocated.
	 */
	if (spa->spa_state != POOL_STATE_ACTIVE ||
	    !spa_has_special(spa) ||
	    spa->spa_wrc.wrc_thread == NULL ||
	    metaslab_class_get_alloc(spa_special_class(spa)) <
	    spa_wrc_min_space)
		return (B_FALSE);

	if (!mutex_tryenter(&wrc_data->wrc_lock))
		return (B_FALSE);

	if (wrc_data->wrc_block_count != 0) {
		mutex_exit(&wrc_data->wrc_lock);
		return (B_FALSE);
	}

	/*
	 * Time to traverse datasets and identify candidate blocks
	 * to be moved from write cache to normal devices.
	 */
	return (B_TRUE);
}

static boolean_t
wrc_should_pause_scanblocks(dsl_pool_t *dp,
    wrc_parseblock_cb_t *cbd, const zbookmark_phys_t *zb)
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

/* ARGSUSED */
int
wrc_traverse_ds_cb(spa_t *spa, zilog_t *zilog, const blkptr_t *bp,
    const zbookmark_phys_t *zb, const dnode_phys_t *dnp, void *arg)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;
	wrc_parseblock_cb_t *cbd = arg;
	wrc_block_t *block;
	int i, ndvas;
	uint64_t blksz;

	/* skip ZIL blocks */
	if (bp == NULL || zb->zb_level == ZB_ZIL_LEVEL)
		return (0);

	/* skip metadata */
	if (BP_IS_METADATA(bp))
		return (0);

	/*
	 * Skip data blocks that are already on non special
	 * devices.
	 */
	ndvas = BP_GET_NDVAS(bp);
	for (i = 0; i < ndvas; i++) {
		vdev_t *vd;

		vd = vdev_lookup_top(spa, DVA_GET_VDEV(&bp->blk_dva[i]));
		ASSERT(vd != NULL);
		if (!vd->vdev_isspecial)
			return (0);
	}

	if (wrc_should_pause_scanblocks(spa->spa_dsl_pool, cbd, zb))
		return (ERESTART);

	block = kmem_alloc(sizeof (*block), KM_NOSLEEP);
	if (block == NULL)
		return (ERESTART);

	/*
	 * Fill information describing data we need to move
	 */
	block->hdr = (wrc_blkhdr_t *)cbd->wrc_blkhdr;
	blksz = BP_GET_LSIZE(bp);
	block->object = zb->zb_object;
	block->offset = zb->zb_blkid * blksz;
	block->size = blksz;
	WRC_BLK_ADDCOUNT(block);

	list_insert_tail(&wrc_data->wrc_blocks, block);
	cbd->bt_size += blksz;
	wrc_data->wrc_block_count++;

	return (0);
}

/*
 * if *blkhdr is NULL, allocate a wrc_blkhdr_t structure
 * set the valid flag to true.
 * caller should hold wrc_lock.
 */
void *
wrc_activate_blkhdr(spa_t *spa, dsl_dataset_t *ds)
{
	char ds_name[MAXNAMELEN + 5];
	wrc_data_t *wrc_data = &spa->spa_wrc;
	wrc_blkhdr_t *blkhdr = ds->ds_wrc_blkhdr = NULL;

	ASSERT(MUTEX_HELD(&wrc_data->wrc_lock));
	if (!spa_has_special(spa) ||
	    ds->ds_is_snapshot || !ds->ds_objset ||
	    spa_specialclass_id(ds->ds_objset) != SPA_SPECIALCLASS_WRCACHE ||
	    wrc_data->wrc_thr_exit)
		return (NULL);

	dsl_dataset_name(ds, ds_name);

	if (wrc_data->wrc_blkhdr_head) {
		wrc_blkhdr_t *tmpblk = wrc_data->wrc_blkhdr_head;
		do {
			if (strcmp(ds_name, tmpblk->ds_name) == 0) {
				blkhdr = tmpblk;
				DTRACE_PROBE2(wrc_activ_found,
				    char *, ds_name, wrc_blkhdr_t *, blkhdr);
				break;
			}
			tmpblk = tmpblk->next;
		} while (tmpblk != wrc_data->wrc_blkhdr_head);
	}

	if (blkhdr == NULL) {
		blkhdr = kmem_alloc(sizeof (wrc_blkhdr_t), KM_NOSLEEP);
		if (blkhdr == NULL)
			return (NULL);

		DTRACE_PROBE2(wrc_ds_add, char *, ds_name,
		    dsl_dataset_t *, ds);

		blkhdr->num_blks = 0;
		(void) strcpy(blkhdr->ds_name, ds_name);
		if (wrc_data->wrc_blkhdr_head) {
			blkhdr->prev = wrc_data->wrc_blkhdr_head->prev;
			blkhdr->next = wrc_data->wrc_blkhdr_head;
			wrc_data->wrc_blkhdr_head->prev->next = blkhdr;
			wrc_data->wrc_blkhdr_head->prev = blkhdr;
		} else {
			blkhdr->prev = blkhdr->next = blkhdr;
			wrc_data->wrc_blkhdr_head = blkhdr;
		}
	}

	ds->ds_wrc_blkhdr = (void *)blkhdr;
	blkhdr->hdr_isvalid = B_TRUE;

	return (ds->ds_wrc_blkhdr);
}

/*
 * Caller should hold the wrc_lock.
 */
void
wrc_deactivate_blkhdr(spa_t *spa, dsl_dataset_t *ds)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;
	wrc_blkhdr_t *blkhdr = (wrc_blkhdr_t *)ds->ds_wrc_blkhdr;
	wrc_block_t *block;

	ASSERT(MUTEX_HELD(&wrc_data->wrc_lock));

	if (!spa_has_special(spa) || !ds->ds_objset ||
	    spa_specialclass_id(ds->ds_objset) != SPA_SPECIALCLASS_WRCACHE ||
	    !wrc_data->wrc_blkhdr_head) {
		ds->ds_wrc_blkhdr = NULL;
		cmn_err(CE_NOTE, "wrc_deactivate_blkhdr: spa doesn't "
		    "have special device\n");
		return;
	}

	if (!blkhdr) {
		char ds_name[MAXNAMELEN + 5];
		dsl_dataset_name(ds, ds_name);
		wrc_blkhdr_t *tmpblk = wrc_data->wrc_blkhdr_head;
		do {
			if (strcmp(ds_name, tmpblk->ds_name) == 0) {
				blkhdr = tmpblk;
				DTRACE_PROBE2(wrc_deactiv_found,
				    char *, ds_name, wrc_blkhdr_t *, blkhdr);
				break;
			}
			tmpblk = tmpblk->next;
		} while (tmpblk != wrc_data->wrc_blkhdr_head);
	}

	if (!blkhdr) {
		cmn_err(CE_NOTE, "No blkhdr for dataset\n");
		return;
	}

	blkhdr->hdr_isvalid = B_FALSE;

	DTRACE_PROBE2(wrc_deactiv_start, char *, blkhdr->ds_name,
	    int, blkhdr->num_blks);

	block = list_head(&wrc_data->wrc_blocks);
	while (block) {
		if (block->hdr == blkhdr) {
			WRC_BLK_DECCOUNT(block);
			block->hdr = NULL;
		}
		block = list_next(&wrc_data->wrc_blocks, block);
	}


	/*
	 * Delete the blkhdr and free it.
	 */
	if (blkhdr->prev == blkhdr->next) {
		wrc_data->wrc_blkhdr_head = NULL;
	} else {
		blkhdr->prev->next = blkhdr->next;
		blkhdr->next->prev = blkhdr->prev;
	}

	DTRACE_PROBE2(wrc_deactiv_done, char *, blkhdr->ds_name,
	    int, blkhdr->num_blks);

	kmem_free(blkhdr, sizeof (*blkhdr));
	ds->ds_wrc_blkhdr = NULL;

}

boolean_t
wrc_try_hold(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;

	return (mutex_tryenter(&wrc_data->wrc_lock));
}

void
wrc_hold(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;

	mutex_enter(&wrc_data->wrc_lock);
}

void
wrc_check_parseblocks_rele(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;
	mutex_exit(&wrc_data->wrc_lock);
}

void
wrc_rele(spa_t *spa)
{
	wrc_data_t *wrc_data = &spa->spa_wrc;
	mutex_exit(&wrc_data->wrc_lock);
}

dmu_tx_t *
dmu_tx_create_wrc(objset_t *os, boolean_t wrc_io)
{
	dmu_tx_t *tx = dmu_tx_create(os);
	tx->tx_wrc_io = wrc_io;
	return (tx);
}

boolean_t
dmu_tx_is_wrcio(dmu_tx_t *tx)
{
	return (tx->tx_wrc_io);
}

/*
 * Moves blocks from a special device to other devices in a pool.
 * TODO: For now the function ignores any errors and it's not
 * correct enough. Ideally there should be a way to report
 * to sync context not to update starting transaction group id.
 */
boolean_t
dsl_wrc_move_block(wrc_block_t *block)
{
	objset_t *os = NULL;
	dmu_tx_t *tx;
	dmu_buf_t *db;
	int err = 0;
	boolean_t stop_wrc_thr = B_FALSE;

	if (dmu_objset_hold(WRC_BLK_DSNAME(block), FTAG, &os) != 0) {
		return (0);
	}


	tx = dmu_tx_create_wrc(os, B_TRUE);
	dmu_tx_hold_write(tx, block->object, block->offset, block->size);

	err = dmu_tx_assign(tx, TXG_WAIT);
	if (err != 0) {
		dmu_tx_abort(tx);
		goto skip;
	}

	/*
	 * If txg is huge and write cache migration i/o interferes with
	 * Normal user traffic, then we should no longer dirty blocks.
	 */
	stop_wrc_thr = dsl_pool_wrcio_limit(tx->tx_pool, dmu_tx_get_txg(tx));

	err = dmu_buf_hold(os, block->object, block->offset, FTAG,
	    &db, DMU_READ_PREFETCH);
	if (err == 0) {
		dmu_buf_will_dirty_sc(db, tx, B_FALSE);
		dmu_buf_rele(db, FTAG);
	}

	dmu_tx_commit(tx);

skip:
	dmu_objset_rele(os, FTAG);

	return (stop_wrc_thr);
}

extern void
dsl_prop_set_sync_impl(dsl_dataset_t *ds, const char *propname,
    zprop_source_t source, int intsz, int numints, const void *value,
    dmu_tx_t *tx);

/*
 * Iterate through data blocks on a "special" device and collect those
 * ones that can be moved to other devices in a pool.
 *
 * XXX: For now we collect as many blocks as possible in order to dispatch
 * them to the taskq later. It may be reasonable to limist number of blocks
 * by some constant.
 */
int
dsl_dataset_clean_special(dsl_dataset_t *ds, dmu_tx_t *tx, uint64_t curtxg,
		hrtime_t scan_start)
{
	dsl_pool_t *dp = ds->ds_dir->dd_pool;
	spa_t *spa = dp->dp_spa;
	wrc_parseblock_cb_t cb_data;
	int err;

	/*
	 * Can be called from sync context only.
	 */
	ASSERT(dsl_pool_sync_context(dp));

	/*
	 * Copy dataset name. We'll use it for resolving the dataset using
	 * it's name from a separate taskq (outside of sync context).
	 */
	if ((cb_data.wrc_blkhdr = wrc_activate_blkhdr(spa, ds)) == NULL) {
		cmn_err(CE_WARN, "returned blkhdr NULL\n");
		return (-1);
	}
	cb_data.zb = ds->ds_lszb;
	cb_data.start_time = scan_start;
	cb_data.bt_size = 0ULL;

	/*
	 * Collect "ready to move" blocks to the list
	 * and dispatch it (list) to the wrc migration thread that will do
	 * all dirtying job outside of sync context
	 */
	err = traverse_dataset_resume(ds, ds->ds_lstxg, &cb_data.zb,
	    TRAVERSE_PREFETCH_METADATA | TRAVERSE_POST,
	    wrc_traverse_ds_cb, &cb_data);

	ds->ds_lszb = cb_data.zb;
	if (err == 0 && (cb_data.bt_size == 0ULL)) {
		/*
		 * No more blocks to move.
		 */
		ds->ds_lstxg = curtxg - 1;
		bzero(&ds->ds_lszb, sizeof (ds->ds_lszb));
		/*
		 * Save lstxg to disk
		 */
		dsl_prop_set_sync_impl(ds, "lstxg", ZPROP_SRC_LOCAL,
		    sizeof (uint64_t), 1, &ds->ds_lstxg, tx);

	} else if (err == ERESTART) {
		/*
		 * We were interrupted, the iteration will be
		 * resumed later.
		 */
		DTRACE_PROBE2(traverse__intr, dsl_dataset_t *, ds,
		    wrc_parseblock_cb_t *, &cb_data);
	}

	return (err);
}

void
wrc_clean_special(dsl_pool_t *dp, dmu_tx_t *tx, uint64_t cur_txg)
{
	dsl_dataset_t *ds;
	objset_t *mos;
	uint64_t obj;
	uint64_t diff;
	int err = 0;
	hrtime_t	scan_start;

	if (!zfs_wrc_schedtmo)
		zfs_wrc_schedtmo = zfs_txg_timeout * 2;

	scan_start = gethrtime();
	diff = scan_start - dp->dp_spec_rtime;
	if (diff / NANOSEC < zfs_wrc_schedtmo)
		return;

	mos = dp->dp_meta_objset;

	/*
	 * TODO: for now we iterate through all datasets in the pool,
	 * but it's not exactly what we want. Idially we should iterate
	 * throuhg those datasets only that have some "ready to move"
	 * data on a special device. Probably we can maintain a list
	 * of all "dirty" datasets.
	 */
	obj = 1;
	while (err == 0) {
		dmu_object_info_t doi;

		err = dmu_object_next(mos, &obj, FALSE,
		    dp->dp_spa->spa_first_txg);
		if (err != 0)
			break;

		err = dmu_object_info(mos, obj, &doi);
		if (err != 0)
			break;

		if (doi.doi_type != DMU_OT_DSL_DATASET)
			continue;

		err = dsl_dataset_hold_obj(dp, obj, FTAG, &ds);
		if (err != 0)
			break;

		if (DS_IS_INCONSISTENT(ds) ||
		    ds->ds_is_snapshot ||
		    ds->ds_dir->dd_myname[0] == '$') {
			dsl_dataset_rele(ds, FTAG);
			continue;
		}

		err = dsl_dataset_clean_special(ds, tx, cur_txg, scan_start);
		dsl_dataset_rele(ds, FTAG);
		if (err != 0)
			break;
	}

	dp->dp_spec_rtime = gethrtime();
}

/*
 * This function checks if write cache migration i/o is
 * affecting the normal user i/o traffic. We determine this
 * by checking if total data in current txg > zfs_wrc_data_max
 * and migration i/o is more than zfs_wrc_io_perc_max % of total
 * data in this txg. If total data in this txg < zfs_dirty_data_sync/4,
 * we assume not much of user traffic is happening..
 */
boolean_t
dsl_pool_wrcio_limit(dsl_pool_t *dp, uint64_t txg)
{
	boolean_t ret = B_FALSE;
	if (mutex_tryenter(&dp->dp_lock)) {
		if (dp->dp_dirty_pertxg[txg & TXG_MASK] !=
		    dp->dp_wrcio_towrite[txg & TXG_MASK] &&
		    dp->dp_dirty_pertxg[txg & TXG_MASK] >
		    zfs_wrc_data_max &&
		    dp->dp_wrcio_towrite[txg & TXG_MASK] > ((WRCIO_PERC_MIN *
		    dp->dp_dirty_pertxg[txg & TXG_MASK]) / 100) &&
		    dp->dp_wrcio_towrite[txg & TXG_MASK] <
		    ((WRCIO_PERC_MAX * dp->dp_dirty_pertxg[txg & TXG_MASK]) /
		    100))
			ret = B_TRUE;
		mutex_exit(&dp->dp_lock);
	}
	return (ret);

}
