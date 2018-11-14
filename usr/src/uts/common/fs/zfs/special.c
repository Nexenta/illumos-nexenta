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

#include <sys/zfs_context.h>
#include <sys/zap.h>
#include <sys/dmu.h>
#include <sys/dmu_objset.h>
#include <sys/dbuf.h>
#include <sys/special_impl.h>
#include <sys/metaslab_impl.h>
#include <sys/vdev_impl.h>
#include <sys/spa_impl.h>
#include <sys/zio.h>
#ifdef _KERNEL
#include <sys/instance.h>
#endif

#include <sys/sysevent/eventdefs.h>
/*
 * There already exist several types of "special" vdevs in zpool:
 * log, cache, and spare. However, there are other dimensions of
 * the issue that could be addressed in a similar fashion:
 *  - vdevs for storing ZFS metadata, including DDTs
 *  - vdevs for storing important ZFS data
 *  - vdevs that absorb write load spikes and move the data
 *    to regular devices during load valleys
 *
 * Clearly, there are lots of options. So, a generalized "special"
 * vdev class is introduced that can be configured to assume the
 * following personalities:
 *  - ZIL     - store ZIL blocks in a way quite similar to SLOG
 *  - META    - in addition to ZIL blocks, store ZFS metadata
 *  - WBC     - in addition to ZIL blocks and ZFS metadata, also
 *              absorb write load spikes (store data blocks),
 *              and move the data blocks to "regular" vdevs
 *              when the system is not too busy
 *
 * The ZIL personality is self-explanatory. The remaining two
 * personalities are also given additional parameters:
 *  - low/high watermarks for space use
 *  - enable/disable special device
 *
 * The watermarks for META personality determine if the metadata
 * can be placed on the special device, with hysteresis:
 * until the space used grows above high watermark, metadata
 * goes to the special vdev, then it stops going to the vdev
 * until the space used drops below low watermark
 *
 * For WBC, the watermarks also gradually reduce the load
 * on the special vdev once the space consumption grows beyond
 * the low watermark yet is still below high watermark:
 * the closer to the high watermark the space consumtion gets,
 * the smaller percentage of writes goes to the special vdev,
 * and once the high watermark is reached, all the data goes to
 * the regular vdevs.
 *
 * Additionally, WBC moves the data off the special device
 * when the system write load subsides, and the amount of data
 * moved off the special device increases as the load falls. Note
 * that metadata is not moved off the WBC vdevs.
 *
 * The pool configuration parameters that describe special vdevs
 * are stored as nvlist in the vdevs' labels along with other
 * standard pool and vdev properties. These parameters include:
 * - class of special vdevs in the pool (ZIL, META, WBC)
 * - whether special vdevs are enabled or not
 * - low and high watermarks for META and WBC
 * - a flag that marks special vdevs
 *
 * The currently supported modes are ZIL and META
 * (see usr/src/common/zfs/zpool_prop.c) but WBC support will
 * be provided soon
 */

/*
 * Initial percentage of total write traffic routed to the
 * special vdev when the latter is working as writeback cache.
 * See spa->spa_special_to_normal_ratio.
 * Changing this variable affects only new or imported pools
 * Valid range: 0% - 100%
 */
uint64_t spa_special_to_normal_ratio = 50;

/*
 * Re-routing delta - the default value that gets added to
 * or subtracted from the spa->spa_special_to_normal_ratio
 * the setting below works as initial step that gets
 * reduced as we close on the load balancing optimum
 */
int64_t spa_special_to_normal_delta = 15;

/*
 * Initialize special vdev load balancing wares when the pool gets
 * created or imported
 */
void
spa_special_init(spa_t *spa)
{
	mutex_init(&spa->spa_perfmon.perfmon_lock, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&spa->spa_perfmon.perfmon_cv, NULL, CV_DEFAULT, NULL);

	bzero(&spa->spa_avg_stat, sizeof (spa_avg_stat_t));

	spa->spa_special_to_normal_ratio = spa_special_to_normal_ratio;
	spa->spa_special_to_normal_delta = 0;
	spa->spa_dedup_percentage = 100;
	spa->spa_avg_stat_rotor = 0;
	spa->spa_dedup_rotor = 0;

	spa->spa_perfmon.perfmon_thread = NULL;
	spa->spa_perfmon.perfmon_thr_exit = B_FALSE;
}

/*
 * The spa_special_fini function is symmetric to the spa_special_init
 * (above)
 * and is called when the pool gets destroyed or exported.
 */
void
spa_special_fini(spa_t *spa)
{
	spa->spa_perfmon.perfmon_thread = NULL;
	cv_destroy(&spa->spa_perfmon.perfmon_cv);
	mutex_destroy(&spa->spa_perfmon.perfmon_lock);
}

static void
spa_enable_special(spa_t *spa, boolean_t usesc)
{
	ASSERT(spa != NULL);

	if (!spa_has_special(spa) || usesc == spa->spa_usesc)
		return;

	spa->spa_usesc = usesc;
}

/*
 * Determine whether we should consider writing data synchronously to
 * special vdevs. See comments in zvol_log_write() and zfs_log_write()
 */
boolean_t
spa_write_data_to_special(spa_t *spa, objset_t *os)
{
	ASSERT(os != NULL);
	return ((spa_has_special(spa)) &&
	    (spa->spa_usesc) &&
	    (spa->spa_watermark == SPA_WM_NONE) &&
	    (os->os_wbc_mode != ZFS_WBC_MODE_OFF));
}

boolean_t
spa_can_special_be_used(spa_t *spa)
{
	return (spa_has_special(spa) && spa->spa_usesc &&
	    (spa->spa_watermark == SPA_WM_NONE));
}

static uint64_t
spa_special_space_perc(spa_t *spa, uint64_t perc)
{
	metaslab_class_t *mc;

	ASSERT(spa_has_special(spa));
	mc = spa_special_class(spa);
	return (metaslab_class_get_space(mc) * perc / 100);
}

/*
 * Checks whether used space on a special device
 * has exceeded either low or high watermarks.
 */
static void
spa_check_watermarks(spa_t *spa)
{
	metaslab_class_t *mc;
	uint64_t aspace, lspace;
	vdev_t *vd = NULL;

	if (!spa_has_special(spa))
		return;

	/* Control logic will not work if one of the value is 0 */
	if (spa->spa_lowat == 0 || spa->spa_hiwat == 0)
		return;

	mc = spa_special_class(spa);
	vd = mc->mc_rotor->mg_vd;
	aspace = metaslab_class_get_alloc(mc);
	spa->spa_lwm_space = spa_special_space_perc(spa, spa->spa_lowat);
	spa->spa_hwm_space = spa_special_space_perc(spa, spa->spa_hiwat);
	spa->spa_wbc_wm_range = spa->spa_hwm_space - spa->spa_lwm_space;

	if (aspace <= spa->spa_lwm_space) {
		if (spa->spa_watermark != SPA_WM_NONE) {
			spa->spa_watermark = SPA_WM_NONE;
			spa_event_notify(spa, vd, NULL, ESC_ZFS_NONE_WATERMARK);
		}
		spa_enable_special(spa, B_TRUE);
	} else if (aspace > spa->spa_hwm_space) {
		if (spa->spa_watermark != SPA_WM_HIGH) {
			spa->spa_watermark = SPA_WM_HIGH;
			spa_enable_special(spa, B_FALSE);
			spa_event_notify(spa, vd, NULL, ESC_ZFS_HIGH_WATERMARK);
		}
	} else {
		if (spa->spa_watermark != SPA_WM_LOW) {
			if (spa->spa_watermark == SPA_WM_NONE)
				spa_enable_special(spa, B_TRUE);
			spa->spa_watermark = SPA_WM_LOW;
			spa_event_notify(spa, vd, NULL, ESC_ZFS_LOW_WATERMARK);
		}

		/*
		 * correction_rate is used by the spa_special_adjust_routing()
		 * the coefficient changes proportionally to the space on the
		 * special vdev utilized beyond low watermark:
		 *	from 0% - when we are below low watermark
		 *	to 100% - at high watermark
		 */
		spa->spa_special_vdev_correction_rate =
		    ((aspace - spa->spa_lwm_space) * 100) /
		    (spa->spa_hwm_space - spa->spa_lwm_space);

		if (spa->spa_wbc.wbc_thread != NULL) {
			/*
			 * Unlike Meta device, write cache is enabled, when
			 * we change from SPA_WM_HIGH to SPA_WM_LOW and then
			 * enables the throttling logic.
			 */
			if (spa->spa_watermark == SPA_WM_HIGH)
				spa_enable_special(spa, B_TRUE);
			lspace = aspace - spa->spa_lwm_space;
			if (spa->spa_wbc_wm_range) {
				spa->spa_wbc_perc = (uint8_t)(lspace * 100 /
				    spa->spa_wbc_wm_range);
			} else {
				spa->spa_wbc_perc = 50;
			}
		}
	}

	DTRACE_PROBE1(check_wm, spa_t *, spa);
}

static int
spa_check_special_degraded(spa_t *spa)
{
	metaslab_class_t *mc;
	metaslab_group_t *mg;
	vdev_t *vd;

	if (!spa_has_special(spa))
		return (0);

	mc = spa_special_class(spa);
	/*
	 * Must hold one of the spa_config locks.
	 */
	ASSERT(spa_config_held(mc->mc_spa, SCL_ALL, RW_READER) != 0 ||
	    spa_config_held(mc->mc_spa, SCL_ALL, RW_WRITER) != 0);

	if ((mg = mc->mc_rotor) == NULL)
		return (0);

	do {
		vd = mg->mg_vd;
		if (vd->vdev_state == VDEV_STATE_DEGRADED ||
		    vd->vdev_state == VDEV_STATE_FAULTED)
			return (1);
	} while ((mg = mg->mg_next) != mc->mc_rotor);

	return (0);
}

void
spa_check_special(spa_t *spa)
{
	if (!spa_has_special(spa))
		return;

	/*
	 * Check if special has degraded vdevs then disable it
	 */
	if (spa_check_special_degraded(spa) != 0) {
		spa_enable_special(spa, B_FALSE);
		return;
	}

	spa_check_watermarks(spa);
}

/* returns B_TRUE if placed on special and B_FALSE if placed elsewhere */
static boolean_t
spa_refine_meta_placement(spa_t *spa, uint64_t zpl_meta_to_special,
    dmu_object_type_t ot)
{
	spa_meta_placement_t *mp = &spa->spa_meta_policy;
	boolean_t isddt = DMU_OT_IS_DDT_META(ot),
	    iszpl = DMU_OT_IS_ZPL_META(ot);

	if (isddt && (mp->spa_ddt_meta_to_special == META_PLACEMENT_OFF))
		return (B_FALSE);
	else if (iszpl && (zpl_meta_to_special == META_PLACEMENT_OFF))
		return (B_FALSE);
	else if (!isddt && !iszpl && (mp->spa_zfs_meta_to_special ==
	    META_PLACEMENT_OFF))
		return (B_FALSE);
	else
		return (B_TRUE);
}

/* returns B_TRUE if can be placed on cache and B_FALSE otherwise */
static boolean_t
spa_meta_is_dual(spa_t *spa, uint64_t zpl_meta_to_special, dmu_object_type_t ot)
{
	spa_meta_placement_t *mp = &spa->spa_meta_policy;
	boolean_t isddt = DMU_OT_IS_DDT_META(ot),
	    iszpl = DMU_OT_IS_ZPL_META(ot);

	if (isddt && (mp->spa_ddt_meta_to_special != META_PLACEMENT_DUAL))
		return (B_FALSE);
	else if (iszpl && (zpl_meta_to_special != META_PLACEMENT_DUAL))
		return (B_FALSE);
	else if (!isddt && !iszpl && (mp->spa_zfs_meta_to_special !=
	    META_PLACEMENT_DUAL))
		return (B_FALSE);
	else
		return (B_TRUE);
}

/*
 * Tunable: special load balancing goal
 * selects among special and normal vdevs in order to optimize specific
 * system parameter, e.g. latency or throughput/utilization
 *
 * ASSMPTION: we assume that special vdevs are much faster than regular vdevs
 * If this is not the case, the system will work better if all the vdevs
 * are made normal, as there is no reason to differentiate
 */
spa_special_selection_t spa_special_selection =
    SPA_SPECIAL_SELECTION_UTILIZATION;

/*
 * Tunable: factor used to adjust the ratio up/down
 * Range: 0 - 100
 * Units: percents
 */
uint64_t spa_special_factor = 5;

/*
 * Distribute writes across special and normal vdevs in
 * spa_special_to_normal-1:1 proportion
 */
static boolean_t
spa_refine_data_placement(spa_t *spa, zio_t *zio)
{
	uint64_t rotor = atomic_inc_64_nv(&spa->spa_avg_stat_rotor);
	spa_meta_placement_t *mp = &spa->spa_meta_policy;
	boolean_t result = B_FALSE;

	/*
	 * For the "balanced" sync-writes the load balancing is already done
	 * see comment in zfs_log_write()
	 */
	if (zio->io_priority == ZIO_PRIORITY_SYNC_WRITE) {
		if (spa->spa_watermark == SPA_WM_NONE &&
		    (mp->spa_sync_to_special == SYNC_TO_SPECIAL_ALWAYS ||
		    mp->spa_sync_to_special == SYNC_TO_SPECIAL_BALANCED)) {
			result = B_TRUE;
		}
	} else {
		result = ((rotor % 100) < spa->spa_special_to_normal_ratio);
	}

	return (result);
}

static boolean_t
spa_meta_to_special(spa_t *spa, objset_t *os, dmu_object_type_t ot)
{
	boolean_t result = B_FALSE;

	ASSERT(os != NULL);
	/* some duplication of the spa_select_class() here */

	if (spa_has_special(spa) && spa->spa_usesc) {
		result = spa_refine_meta_placement(spa,
		    os->os_zpl_meta_to_special, ot);
	}

	return (result);
}

/*
 * Decide whether block should be l2cached. Returns true if block's metadata
 * type is l2cacheable or block isn't a metadata one
 */
boolean_t
dbuf_meta_is_l2cacheable(dmu_buf_impl_t *db)
{
	boolean_t is_metadata, is_to_special;
	dmu_object_type_t ot = DMU_OT_NONE;
	spa_t *spa = db->db_objset->os_spa;

	DB_DNODE_ENTER(db);
	ot = DB_DNODE(db)->dn_type;
	DB_DNODE_EXIT(db);

	is_metadata = dmu_ot[ot].ot_metadata;

	if (!is_metadata)
		return (B_TRUE);

	is_to_special  = spa_meta_to_special(spa, db->db_objset, ot);

	if (!is_to_special)
		return (B_TRUE);

	return (spa_meta_is_dual(spa, db->db_objset->os_zpl_meta_to_special,
	    ot));
}

/*
 * Decide whether block should be l2cached. Returns true if block is a ddt
 * metadata and ddt metadata is cacheable, or if block isn't a ddt metadata
 */
boolean_t
dbuf_ddt_is_l2cacheable(dmu_buf_impl_t *db)
{
	dmu_object_type_t ot;
	spa_t *spa = db->db_objset->os_spa;
	spa_meta_placement_t *mp = &spa->spa_meta_policy;

	if (!spa_has_special(spa))
		return (B_TRUE);

	DB_DNODE_ENTER(db);
	ot = DB_DNODE(db)->dn_type;
	DB_DNODE_EXIT(db);

	if (!DMU_OT_IS_DDT_META(ot))
		return (B_TRUE);

	return (mp->spa_ddt_meta_to_special != META_PLACEMENT_ON);
}

/*
 * Select whether to direct zio to special or to normal storage class
 * Even when the top-level criteria match (for placement to the special
 * class), consider refining data and metadata placement based on
 * additional information about the system's behavior
 */
metaslab_class_t *
spa_select_class(spa_t *spa, zio_t *zio)
{
	zio_prop_t *zp = &zio->io_prop;
	spa_meta_placement_t *mp = &spa->spa_meta_policy;
	boolean_t match = B_FALSE;

	if (!zp->zp_usesc || !spa_has_special(spa) ||
	    spa->spa_special_has_errors) {
		match = B_FALSE;
	} else if (zp->zp_metadata) {
		match = mp->spa_enable_meta_placement_selection &&
		    spa_refine_meta_placement(spa, zp->zp_zpl_meta_to_special,
		    zp->zp_type);
	} else if (BP_GET_PSIZE(zio->io_bp) <= mp->spa_small_data_to_special) {
		match = B_TRUE;
	} else {
		match = zp->zp_usewbc && spa->spa_wbc.wbc_ready_to_use &&
		    spa_refine_data_placement(spa, zio);
	}

	if (match)
		return (spa_special_class(spa));

	/* drop 'use special class' */
	zp->zp_usesc = B_FALSE;
	zp->zp_usewbc = B_FALSE;
	return (spa_normal_class(spa));
}

/*
 * Tunable: enables or disables automatic spa special selection
 * logic and set static routing value for spa_special_to_normal_ratio
 *
 * Range: 0 - 100 (disables automatic logic and set static routing)
 * or
 * Default value: UINT64_MAX (enables automatic logic)
 */
uint64_t spa_static_routing_percentage = UINT64_MAX;

/*
 * Tunable: minimal delta between the current class-averaged latencies
 * Range: 0 - 100
 * Units: Percents
 */
uint64_t spa_min_latency_delta = 15;

/*
 * spa_special_adjust_routing() tunables that control re-balancing of the
 * write traffic between the two spa classes: special and normal.
 *
 * Specific SPA_SPECIAL_SELECTION_UTILIZATION mechanism here includes
 * the following steps executed by the spa_perfmon_thread():
 * 1) sample vdev utilization
 * 2) every so many (spa_rotor_load_adjusting) samples: aggregate on a
 *    per-class basis
 * 3) load-balance depending on where the latter falls as far as:
 *    (... vdev_idle, ... vdev_busy, ...)
 *    where "vdev_idle" and "vdev_busy" are the corresponding per-class
 *    boundaries specified below:
 */

/*
 * class-averaged "busy" and "idle" constants
 * E.g., special class is considered idle when its average utilization
 * is at or below spa_special_class_idle
 */
static int spa_special_class_busy = 70;
static int spa_normal_class_busy = 70;
static int spa_fairly_busy_delta = 10;
static int spa_special_class_idle = 30;
static int spa_normal_class_idle = 30;

static boolean_t
spa_class_is_busy(int ut, int busy)
{
	return (ut > busy);
}

static boolean_t
spa_class_is_idle(int ut, int idle)
{
	return (ut < idle);
}

static boolean_t
spa_class_is_fairly_busy(int ut, int busy)
{
	if (busy < spa_fairly_busy_delta)
		return (B_FALSE);
	return (ut > busy - spa_fairly_busy_delta);
}

/*
 * This specific load-balancer implements the following strategy:
 * when selecting between normal and special classes, bias "more"
 * load to the class with a smaller average latency
 */
static void
spa_special_adjust_routing_latency(spa_t *spa)
{
	/*
	 * average perf counters
	 * computed for the current spa_perfmon_thread iteration
	 */
	spa_avg_stat_t *stat = &spa->spa_avg_stat;

	/*
	 * class latencies:
	 * normal and special, min and max
	 */
	uint64_t norm_svct = stat->normal_latency;
	uint64_t spec_svct = stat->special_latency;
	uint64_t svct_min = MIN(norm_svct, spec_svct);
	uint64_t svct_max = MAX(norm_svct, spec_svct);

	/* no rebalancing: do nothing if idle */
	if (norm_svct == 0 && spec_svct == 0)
		return;

	/*
	 * normalized difference between the per-class average latencies
	 */
	uint64_t svct_delta = 100 * (svct_max - svct_min) / svct_max;

	/*
	 * do nothing if the difference between class-averaged latencies
	 * is less than configured
	 */
	if (svct_delta < spa_min_latency_delta)
		return;

	/*
	 * current special to normal load balancing ratio and its
	 * current "delta" - note that both values are recomputed below
	 */
	int64_t ratio = spa->spa_special_to_normal_ratio;
	int64_t ratio_delta = spa->spa_special_to_normal_delta;

	/*
	 * Recompute special-to-normal load balancing ratio:
	 * 1) given non-zero rerouting delta, consider the current
	 *    class-average latencies to possibly change the re-balancing
	 *    direction; halve the delta to close on the local optimum
	 * 2) otherwise, reset rerouting delta depending again
	 *    on the relationship between average latencies
	 *    (2nd and 3rd if)
	 */
	if ((norm_svct > spec_svct && ratio_delta < 0) ||
	    (norm_svct < spec_svct && ratio_delta > 0))
		ratio_delta /= -2;
	else if (norm_svct > spec_svct && ratio_delta == 0)
		ratio_delta = spa_special_to_normal_delta;
	else if (norm_svct < spec_svct && ratio_delta == 0)
		ratio_delta = -spa_special_to_normal_delta;

	ratio += ratio_delta;
	ratio = MAX(MIN(ratio, 100), 0);
	spa->spa_special_to_normal_delta = ratio_delta;
	spa->spa_special_to_normal_ratio = ratio;
}

static void
spa_special_adjust_routing_utilization(spa_t *spa)
{
	/*
	 * average perf counters
	 * computed for the current spa_perfmon_thread iteration
	 */
	spa_avg_stat_t *stat = &spa->spa_avg_stat;

	/* class utilizations: normal and special */
	uint64_t norm_util = stat->normal_utilization;
	uint64_t spec_util = stat->special_utilization;

	/*
	 * current special to normal load balancing ratio and its
	 * current "delta" - note that both values are recomputed below
	 *
	 * the first two 'if's below deal with the idle/busy situation,
	 * while the remaining two rebalance between classes as long as
	 * the "other" class is not idle
	 */
	int64_t ratio = spa->spa_special_to_normal_ratio;
	int64_t ratio_delta = spa->spa_special_to_normal_delta;

	/* 1. special is fairly busy while normal is idle */
	if (spa_class_is_fairly_busy(spec_util, spa_special_class_busy) &&
	    spa_class_is_idle(norm_util, spa_normal_class_idle))
		ratio_delta = -spa_special_factor;
	/* 2. normal is fairly busy while special is idle */
	else if (spa_class_is_fairly_busy(norm_util, spa_normal_class_busy) &&
	    spa_class_is_idle(spec_util, spa_special_class_idle))
		ratio_delta = spa_special_factor;
	/* 3. normal is not busy and special is not idling as well */
	else if (!spa_class_is_busy(norm_util, spa_normal_class_busy) &&
	    !spa_class_is_idle(spec_util, spa_special_class_idle))
		ratio_delta = -spa_special_factor;
	/* 4. special is not busy and normal is not idling as well */
	else if (!spa_class_is_busy(spec_util, spa_special_class_busy) &&
	    !spa_class_is_idle(norm_util, spa_normal_class_idle))
		ratio_delta = spa_special_factor;

	ratio += ratio_delta;
	ratio = MAX(MIN(ratio, 100), 0);
	spa->spa_special_to_normal_delta = ratio_delta;
	spa->spa_special_to_normal_ratio = ratio;
}

static void
spa_special_adjust_routing(spa_t *spa)
{
	spa_avg_stat_t *stat = &spa->spa_avg_stat;

	/*
	 * setting this spa_static_routing_percentage to a value
	 * in the range (0, 100) will cause the system to abide
	 * by this statically defined load balancing, and will
	 * therefore totally disable all the dynamic latency and
	 * throughput (default) balancing logic in this function
	 */
	if (spa_static_routing_percentage <= 100) {
		spa->spa_special_to_normal_ratio =
		    spa_static_routing_percentage;
		goto out;
	}

	if (spa->spa_watermark == SPA_WM_HIGH) {
		/*
		 * Free space on the special device is too low,
		 * so need to offload it
		 */
		spa->spa_special_to_normal_ratio = 0;
		goto out;
	}

	ASSERT(SPA_SPECIAL_SELECTION_VALID(spa_special_selection));

	switch (spa_special_selection) {
	case SPA_SPECIAL_SELECTION_LATENCY:
		spa_special_adjust_routing_latency(spa);
		break;
	case SPA_SPECIAL_SELECTION_UTILIZATION:
		spa_special_adjust_routing_utilization(spa);
		break;
	}

	/*
	 * Adjust special/normal load balancing ratio by taking
	 * into account used space vs. configurable watermarks.
	 * (see spa_check_watermarks() for details)
	 * Note that new writes are *not* routed to special
	 * vdev when used above SPA_WM_HIGH
	 */
	if (spa->spa_watermark == SPA_WM_LOW)
		spa->spa_special_to_normal_ratio -=
		    spa->spa_special_to_normal_ratio *
		    spa->spa_special_vdev_correction_rate / 100;

out:
#ifdef _KERNEL
	DTRACE_PROBE7(spa_adjust_routing,
	    uint64_t, spa->spa_special_to_normal_ratio,
	    uint64_t, stat->special_utilization,
	    uint64_t, stat->normal_utilization,
	    uint64_t, stat->special_latency,
	    uint64_t, stat->normal_latency,
	    uint64_t, stat->special_throughput,
	    uint64_t, stat->normal_throughput);
#endif
	ASSERT(spa->spa_special_to_normal_ratio <= 100);
}

typedef void (*spa_load_cb)(vdev_t *, cos_acc_stat_t *);

/*
 * Recursive walk top level vdev's tree
 * Callback on each physical vdev
 */
static void
spa_vdev_walk_stats(vdev_t *pvd, spa_load_cb func,
    cos_acc_stat_t *cos_acc)
{
	if (pvd->vdev_children == 0) {
		/* Single vdev (itself) */
		ASSERT(pvd->vdev_ops->vdev_op_leaf);
		DTRACE_PROBE1(spa_vdev_walk_lf, vdev_t *, pvd);
		func(pvd, cos_acc);
	} else {
		int i;
		/* Not a leaf-level vdev, has children */
		ASSERT(!pvd->vdev_ops->vdev_op_leaf);
		for (i = 0; i < pvd->vdev_children; i++) {
			vdev_t *vd = pvd->vdev_child[i];
			ASSERT(vd != NULL);

			if (vd->vdev_islog || vd->vdev_ishole ||
			    vd->vdev_isspare || vd->vdev_isl2cache)
				continue;

			if (vd->vdev_ops->vdev_op_leaf) {
				DTRACE_PROBE1(spa_vdev_walk_lf, vdev_t *, vd);
				func(vd, cos_acc);
			} else {
				DTRACE_PROBE1(spa_vdev_walk_nl, vdev_t *, vd);
				spa_vdev_walk_stats(vd, func, cos_acc);
			}
		}
	}
}

/*
 * Tunable: period (spa_avg_stat_update_ticks per tick)
 * for adjusting load distribution
 * Range: 1-UINT64_MAX
 * Units: period
 */
uint64_t spa_rotor_load_adjusting = 1;

/*
 * Tunable: weighted average over period
 * Range: 0-1
 * Units: boolean
 * 1: weighted average over spa_rotor_load_adjusting period
 * 0: (default): regular average
 */
boolean_t spa_rotor_use_weight = B_FALSE;

/*
 * Retrieve current kstat vdev statistics
 * Calculate delta values for all statistics
 * Calculate utilization and latency based on the received values
 * Update vdev_aux with current kstat values
 * Accumulate class utilization, latency and throughput into cos_acc
 */
static void
spa_vdev_process_stat(vdev_t *vd, cos_acc_stat_t *cos_acc)
{
	uint64_t nread;		/* number of bytes read */
	uint64_t nwritten;	/* number of bytes written */
	uint64_t reads;		/* number of read operations */
	uint64_t writes;	/* number of write operations */
	uint64_t rtime;		/* cumulative run (service) time */
	uint64_t wtime;		/* cumulative wait (pre-service) time */
	uint64_t rlentime;	/* cumulative run length*time product */
	uint64_t wlentime;	/* cumulative wait length*time product */
	uint64_t rlastupdate;	/* last time run queue changed */
	uint64_t wlastupdate;	/* last time wait queue changed */
	uint64_t rcnt;		/* count of elements in run state */
	uint64_t wcnt;		/* count of elements in wait state */

	/*
	 * average vdev utilization, measured as the percentage
	 * of time for which the device was busy servicing I/O
	 * requests during the sample interval
	 */
	uint64_t utilization = 0;

	/*
	 * average vdev throughput for read and write
	 * in kilobytes per second
	 */
	uint64_t throughput = 0;

	/* average vdev input/output operations per second */
	uint64_t iops = 0;

	/*
	 * average number of commands being processed in the active
	 * queue that the vdev is working on simultaneously
	 */
	uint64_t run_len = 0;

	/*
	 * average number of commands waiting in the queues that
	 * have not been sent to the vdev yet
	 */
	uint64_t wait_len = 0;

	/* average total queue: wait_len + run_len */
	uint64_t queue_len = 0;

	/*
	 * average time for an operation to complete after
	 * it has been dequeued from the wait queue
	 */
	uint64_t run_time = 0;

	/* average time for which operations are queued before they are run */
	uint64_t wait_time = 0;

	/* average time to queue and complete an I/O operation */
	uint64_t service_time = 0;

	vdev_aux_stat_t *vdev_aux = &vd->vdev_aux_stat;
	kstat_t *kstat = vd->vdev_iokstat;
	kstat_io_t *kdata = kstat->ks_data;

	/* retrieve current kstat values for vdev */
	mutex_enter(kstat->ks_lock);

	nread = kdata->nread;
	nwritten = kdata->nwritten;
	reads = kdata->reads;
	writes = kdata->writes;
	rtime = kdata->rtime;
	wtime = kdata->wtime;
	rlentime = kdata->rlentime;
	wlentime = kdata->wlentime;
	rlastupdate = kdata->rlastupdate;
	wlastupdate = kdata->wlastupdate;
	rcnt = kdata->rcnt;
	wcnt = kdata->wcnt;

	mutex_exit(kstat->ks_lock);

	/* convert high-res time to nanoseconds */
#ifdef _KERNEL
	scalehrtime((hrtime_t *)&rtime);
	scalehrtime((hrtime_t *)&wtime);
	scalehrtime((hrtime_t *)&rlentime);
	scalehrtime((hrtime_t *)&wlentime);
	scalehrtime((hrtime_t *)&rlastupdate);
	scalehrtime((hrtime_t *)&wlastupdate);
#endif

	/*
	 * At the beginning of each stats updating iteration
	 * (wlastupdate == 0): init the counters
	 */
	if (vdev_aux->wlastupdate != 0) {
		/* Calculate deltas for vdev statistics */
		uint64_t nread_delta = nread - vdev_aux->nread;
		uint64_t nwritten_delta = nwritten - vdev_aux->nwritten;
		uint64_t reads_delta = reads - vdev_aux->reads;
		uint64_t writes_delta = writes - vdev_aux->writes;
		uint64_t rtime_delta = rtime - vdev_aux->rtime;
		uint64_t rlentime_delta = rlentime - vdev_aux->rlentime;
		uint64_t wlentime_delta = wlentime - vdev_aux->wlentime;
		uint64_t wlastupdate_delta = wlastupdate -
		    vdev_aux->wlastupdate;

		if (wlastupdate_delta != 0) {
			/* busy: proportion of the time as a percentage */
			utilization = 100 * rtime_delta / wlastupdate_delta;
			if (utilization > 100)
				utilization = 100;
			/* throughput: KiloBytes per second */
			throughput = NANOSEC * (nread_delta + nwritten_delta) /
			    wlastupdate_delta / 1024;
			/* input/output operations per second */
			iops = NANOSEC * (reads_delta + writes_delta) /
			    wlastupdate_delta;
			run_len = rlentime_delta / wlastupdate_delta;
			wait_len = wlentime_delta / wlastupdate_delta;
			queue_len = run_len + wait_len;
		}

		if (iops != 0) {
			/* latency: microseconds */
			run_time = 1000 * run_len / iops;
			wait_time = 1000 * wait_len / iops;
			service_time = run_time + wait_time;
		}
	}

	/* update previous kstat values */
	vdev_aux->nread = nread;
	vdev_aux->nwritten = nwritten;
	vdev_aux->reads = reads;
	vdev_aux->writes = writes;
	vdev_aux->rtime = rtime;
	vdev_aux->wtime = wtime;
	vdev_aux->rlentime = rlentime;
	vdev_aux->wlentime = wlentime;
	vdev_aux->rlastupdate = rlastupdate;
	vdev_aux->wlastupdate = wlastupdate;
	vdev_aux->rcnt = rcnt;
	vdev_aux->wcnt = wcnt;

	/* accumulate current class values */
	cos_acc->utilization += utilization;
	cos_acc->throughput += throughput;
	cos_acc->iops += iops;
	cos_acc->run_len += run_len;
	cos_acc->wait_len += wait_len;
	cos_acc->queue_len += queue_len;
	cos_acc->run_time += run_time;
	cos_acc->wait_time += wait_time;
	cos_acc->service_time += service_time;
	cos_acc->count++;

#ifdef _KERNEL
	DTRACE_PROBE8(spa_vdev_stat,
	    char *, vd->vdev_path,
	    uint64_t, utilization,
	    uint64_t, throughput,
	    uint64_t, iops,
	    uint64_t, run_len,
	    uint64_t, wait_len,
	    uint64_t, run_time,
	    uint64_t, wait_time);
#endif
}

/*
 * gather and accumulate spa average statistics per special and normal classes
 */
static void
spa_class_collect_stats(spa_t *spa, spa_acc_stat_t *spa_acc, uint64_t weight)
{
	vdev_t *rvd = spa->spa_root_vdev;
	cos_acc_stat_t special_acc, normal_acc;
	int i;

	ASSERT(rvd != NULL);

	bzero(&special_acc, sizeof (cos_acc_stat_t));
	bzero(&normal_acc, sizeof (cos_acc_stat_t));

	/*
	 * Walk the top level vdevs and calculate average
	 * stats for the normal and special classes
	 */
	spa_config_enter(spa, SCL_VDEV, FTAG, RW_READER);

	for (i = 0; i < rvd->vdev_children; i++) {
		vdev_t *vd = rvd->vdev_child[i];
		ASSERT(vd != NULL);

		if (vd->vdev_islog || vd->vdev_ishole ||
		    vd->vdev_isspare || vd->vdev_isl2cache)
			continue;

		if (vd->vdev_isspecial)
			spa_vdev_walk_stats(vd, spa_vdev_process_stat,
			    &special_acc);
		else
			spa_vdev_walk_stats(vd, spa_vdev_process_stat,
			    &normal_acc);
	}

	spa_config_exit(spa, SCL_VDEV, FTAG);

	if (special_acc.count == 0 || normal_acc.count == 0)
		return;

	/*
	 * Locally accumulate (sum-up) spa and per-class throughput, latency
	 * and utilization stats. At the end of each iteration the resulting
	 * sums are averaged /= num-samples
	 */

	spa_acc->spa_utilization +=
	    weight * (special_acc.utilization + normal_acc.utilization) /
	    (special_acc.count + normal_acc.count);

	spa_acc->special_utilization +=
	    weight * special_acc.utilization / special_acc.count;
	spa_acc->special_latency +=
	    weight * special_acc.service_time / special_acc.count;
	spa_acc->special_throughput +=
	    weight * special_acc.throughput / special_acc.count;

	spa_acc->normal_utilization +=
	    weight * normal_acc.utilization / normal_acc.count;
	spa_acc->normal_latency +=
	    weight * normal_acc.service_time / normal_acc.count;
	spa_acc->normal_throughput +=
	    weight * normal_acc.throughput / normal_acc.count;

	spa_acc->count += weight;
}

/*
 * Updates spa statistics for special and normal classes
 * for every spa_rotor_load_adjusting-th of running
 */
static void
spa_load_stats_update(spa_t *spa, spa_acc_stat_t *spa_acc, uint64_t rotor)
{
	spa_avg_stat_t *spa_avg = &spa->spa_avg_stat;
	uint64_t residue, weight = 1;

	residue = rotor % spa_rotor_load_adjusting;

	if (spa_rotor_use_weight)
		weight = residue ? residue : spa_rotor_load_adjusting;

	spa_class_collect_stats(spa, spa_acc, weight);

	if (residue == 0 && spa_acc->count != 0) {
		spa_avg->spa_utilization =
		    spa_acc->spa_utilization / spa_acc->count;

		spa_avg->special_utilization =
		    spa_acc->special_utilization / spa_acc->count;
		spa_avg->normal_utilization =
		    spa_acc->normal_utilization / spa_acc->count;

		spa_avg->special_latency =
		    spa_acc->special_latency / spa_acc->count;
		spa_avg->normal_latency =
		    spa_acc->normal_latency / spa_acc->count;

		spa_avg->special_throughput =
		    spa_acc->special_throughput / spa_acc->count;
		spa_avg->normal_throughput =
		    spa_acc->normal_throughput / spa_acc->count;
	}
}

static void
spa_special_dedup_adjust(spa_t *spa)
{
	spa_avg_stat_t *spa_avg = &spa->spa_avg_stat;
	int percentage;

	/*
	 * if special_utilization < dedup_lo, then percentage = 100;
	 * if special_utilization > dedup_hi, then percentage = 0;
	 * otherwise, the percentage changes linearly from 100 to 0
	 * as special_utilization moves from dedup_lo to dedup_hi
	 */
	percentage = 100 - 100 *
	    (spa_avg->special_utilization - spa->spa_dedup_lo_best_effort) /
	    (spa->spa_dedup_hi_best_effort - spa->spa_dedup_lo_best_effort);
	/* enforce proper percentage limits */
	percentage = MIN(percentage, 100);
	percentage = MAX(percentage, 0);

	spa->spa_dedup_percentage = percentage;
}

/*
 * Tunable: period (~10ms per tick) for updating spa vdev stats
 * Range: 1 - UINT64_MAX
 * Units: 10 * milliseconds
 * For most recent cases "75" is optimal value.
 * The recommended range is: 50...200
 */
clock_t spa_avg_stat_update_ticks = 75;

/* Performance monitor thread */
static void
spa_perfmon_thread(void *void_spa)
{
	spa_t *spa = void_spa;
	spa_perfmon_data_t *data = &spa->spa_perfmon;
	spa_acc_stat_t spa_acc;
	uint64_t rotor = 0;

	ASSERT(data != NULL);

	DTRACE_PROBE1(spa_pm_start, spa_t *, spa);

	/* take a reference against spa */
	mutex_enter(&spa_namespace_lock);
	spa_open_ref(spa, FTAG);
	mutex_exit(&spa_namespace_lock);
	bzero(&spa_acc, sizeof (spa_acc_stat_t));

	while (spa->spa_state != POOL_STATE_UNINITIALIZED &&
	    !data->perfmon_thr_exit) {
		clock_t deadline, timeleft = 1;

		/*
		 * do the monitoring work here: gather average
		 * spa utilization, latency and throughput statistics
		 */
		DTRACE_PROBE1(spa_pm_work, spa_t *, spa);
		spa_load_stats_update(spa, &spa_acc, rotor);

		/* we can adjust load and dedup at the same time */
		if (rotor % spa_rotor_load_adjusting == 0) {
			spa_special_adjust_routing(spa);
			bzero(&spa_acc, sizeof (spa_acc_stat_t));
		}
		if (spa->spa_dedup_best_effort)
			spa_special_dedup_adjust(spa);

		/* wait for the next tick */
		DTRACE_PROBE1(spa_pm_sleep, spa_t *, spa);
		deadline = ddi_get_lbolt() + spa_avg_stat_update_ticks;
		mutex_enter(&data->perfmon_lock);
		while (timeleft > 0 &&
		    spa->spa_state != POOL_STATE_UNINITIALIZED &&
		    !data->perfmon_thr_exit) {
			timeleft = cv_timedwait(&data->perfmon_cv,
			    &data->perfmon_lock, deadline);
		}
		mutex_exit(&data->perfmon_lock);
		++rotor;
	}

	/* release the reference against spa */
	mutex_enter(&spa_namespace_lock);
	spa_close(spa, FTAG);
	mutex_exit(&spa_namespace_lock);

	DTRACE_PROBE1(spa_pm_stop, spa_t *, spa);
	thread_exit();
}

void
spa_start_perfmon_thread(spa_t *spa)
{
	spa_perfmon_data_t *data = &spa->spa_perfmon;

	/* not a "real" spa import/create, do not start the thread */
	if (strcmp(spa->spa_name, TRYIMPORT_NAME) == 0)
		return;

	mutex_enter(&data->perfmon_lock);

	if (data->perfmon_thread == NULL) {
		DTRACE_PROBE1(spa_start_perfmon_act, spa_t *, spa);
		data->perfmon_thr_exit = B_FALSE;
#ifdef _KERNEL
		data->perfmon_thread = thread_create(NULL, 0,
		    spa_perfmon_thread, spa, 0, &p0, TS_RUN, maxclsyspri);
#endif
	}

	mutex_exit(&data->perfmon_lock);
}

boolean_t
spa_stop_perfmon_thread(spa_t *spa)
{
	spa_perfmon_data_t *data = &spa->spa_perfmon;
	mutex_enter(&data->perfmon_lock);

	if (data->perfmon_thread != NULL) {
		DTRACE_PROBE1(spa_stop_perfmon_act, spa_t *, spa);
		data->perfmon_thr_exit = B_TRUE;
		cv_signal(&data->perfmon_cv);
		mutex_exit(&data->perfmon_lock);
#ifdef _KERNEL
		thread_join(data->perfmon_thread->t_did);
#endif
		data->perfmon_thread = NULL;
		return (B_TRUE);
	}

	mutex_exit(&data->perfmon_lock);
	return (B_FALSE);
}

/* Closed funcitons from other facilities */
void
zio_best_effort_dedup(zio_t *zio)
{
	spa_t *spa = zio->io_spa;
	zio_prop_t *zp = &zio->io_prop;
	uint64_t val;

	if (spa->spa_dedup_best_effort == 0)
		return;

	val = atomic_inc_64_nv(&spa->spa_dedup_rotor);
	if ((val % 100) >= spa->spa_dedup_percentage)
		zp->zp_dedup = 0;
}

static boolean_t
spa_has_special_child_errors(vdev_t *vd)
{
	vdev_stat_t *vs = &vd->vdev_stat;

	return (vs->vs_checksum_errors != 0 || vs->vs_read_errors != 0 ||
	    vs->vs_write_errors != 0 || !vdev_readable(vd) ||
	    !vdev_writeable(vd));
}

static int
spa_special_check_errors_children(vdev_t *pvd)
{
	int rc = 0;

	if (pvd->vdev_children == 0) {
		if (spa_has_special_child_errors(pvd))
			rc = -1;
	} else {
		ASSERT(!pvd->vdev_ops->vdev_op_leaf);
		for (size_t i = 0; i < pvd->vdev_children; i++) {
			vdev_t *vd = pvd->vdev_child[i];
			ASSERT(vd != NULL);

			if (vd->vdev_ops->vdev_op_leaf) {
				if (spa_has_special_child_errors(vd)) {
					rc = -1;
					break;
				}
			} else {
				rc = spa_special_check_errors_children(vd);
				if (rc != 0)
					break;
			}
		}
	}

	return (rc);
}

/*
 * This function is called from dsl_scan_done()
 * that is executed in sync-ctx.
 * Here we walk over all VDEVs, to find
 * special-vdev and check errors on it.
 *
 * If special-vdev does not have errors we drop
 * a flag that does not allow to write to special
 */
void
spa_special_check_errors(spa_t *spa)
{
	vdev_t *rvd;
	boolean_t clean_special_err_flag = B_TRUE;

	spa_config_enter(spa, SCL_VDEV, FTAG, RW_READER);

	rvd = spa->spa_root_vdev;
	for (size_t i = 0; i < rvd->vdev_children; i++) {
		vdev_t *vd = rvd->vdev_child[i];
		ASSERT(vd != NULL);

		if (!vd->vdev_isspecial)
			continue;

		if (spa_special_check_errors_children(vd) != 0) {
			clean_special_err_flag = B_FALSE;
			break;
		}
	}

	spa_config_exit(spa, SCL_VDEV, FTAG);

	if (clean_special_err_flag)
		spa->spa_special_has_errors = B_FALSE;
}

int
spa_special_vdev_remove(spa_t *spa, vdev_t *vd, uint64_t *txg)
{
	int err;
	metaslab_group_t *mg;

	ASSERT(MUTEX_HELD(&spa_namespace_lock));
	ASSERT(vdev_is_special(vd));

	if (vd != vd->vdev_top)
		return (SET_ERROR(ENOTSUP));

	if (spa_feature_is_active(spa, SPA_FEATURE_WBC)) {
		/*
		 * WBC still active, so we cannot remove
		 * special at this time
		 */
		return (SET_ERROR(EBUSY));
	}

	mg = vd->vdev_mg;

	/*
	 * Stop allocating from this vdev.
	 */
	metaslab_group_passivate(mg);

	/*
	 * Wait for the youngest allocations and frees to sync,
	 * and then wait for the deferral of those frees to finish.
	 */
	spa_vdev_config_exit(spa, NULL,
	    *txg + TXG_CONCURRENT_STATES + TXG_DEFER_SIZE, 0, FTAG);

	if (vd->vdev_stat.vs_alloc != 0) {
		/* Make sure that special does not have ZIL data */
		err = spa_offline_log(spa);

		if (err != 0 || vd->vdev_stat.vs_alloc != 0) {
			/*
			 * err == 0 means all ZIL data is gone,
			 * but we here so special vdev contains metadata,
			 * that we cannot migrate.
			 * It is possible that user has enabled some of
			 * the *_to_metadev prop but we cannot migrate
			 * metadata from special vdev to normal vdev in
			 * this case
			 */
			if (err == 0)
				err = SET_ERROR(EEXIST);

			*txg = spa_vdev_config_enter(spa);
			metaslab_group_activate(mg);
			return (err);
		}
	}

	*txg = spa_vdev_config_enter(spa);

	vd->vdev_removing = B_TRUE;
	vdev_dirty_leaves(vd, VDD_DTL, *txg);
	vdev_config_dirty(vd);

	/* This exit is required to sync dirty configuration */
	spa_vdev_config_exit(spa, NULL, *txg, 0, FTAG);

	if (spa_feature_is_active(spa, SPA_FEATURE_META_DEVICES)) {
		dmu_tx_t *tx = dmu_tx_create_assigned(spa_get_dsl(spa),
		    spa_last_synced_txg(spa) + 1);

		spa_feature_decr(spa, SPA_FEATURE_META_DEVICES, tx);
		dmu_tx_commit(tx);
	}

	*txg = spa_vdev_config_enter(spa);

	/*
	 * Release the references to CoS descriptors if any
	 */
	if (vd->vdev_queue.vq_cos) {
		cos_rele(vd->vdev_queue.vq_cos);
		vd->vdev_queue.vq_cos = NULL;
	}

	return (0);
}
