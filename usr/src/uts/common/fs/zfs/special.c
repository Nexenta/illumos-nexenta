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
 *  - WRCACHE - in addition to ZIL blocks and ZFS metadata, also
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
 * For WRCACHE, the watermarks also gradually reduce the load
 * on the special vdev once the space consumption grows beyond
 * the low watermark yet is still below high watermark:
 * the closer to the high watermark the space consumtion gets,
 * the smaller percentage of writes goes to the special vdev,
 * and once the high watermark is reached, all the data goes to
 * the regular vdevs.
 *
 * Additionally, WRCACHE moves the data off the special device
 * when the system write load subsides, and the amount of data
 * moved off the special device increases as the load falls. Note
 * that metadata is not moved off the WRCACHE vdevs.
 *
 * The pool configuration parameters that describe special vdevs
 * are stored as nvlist in the vdevs' labels along with other
 * standard pool and vdev properties. These parameters include:
 * - class of special vdevs in the pool (ZIL, META, WRCACHE)
 * - whether special vdevs are enabled or not
 * - low and high watermarks for META and WRCACHE
 * - a flag that marks special vdevs
 *
 * The currently supported modes are ZIL and META
 * (see usr/src/common/zfs/zpool_prop.c) but WRCACHE support will
 * be provided soon
 */

/* existing special class desriptors */
spa_specialclass_t specialclass_desc[SPA_NUM_SPECIALCLASSES] = {
	{ SPA_SPECIALCLASS_ZIL,	0 },
	{ SPA_SPECIALCLASS_META,	SPECIAL_META_FLAGS },
	{ SPA_SPECIALCLASS_WRCACHE,	SPECIAL_WRCACHE_FLAGS }
};

void
spa_set_specialclass(spa_t *spa, objset_t *os,
    spa_specialclass_id_t specclassid)
{
	ASSERT(spa);
	ASSERT(os);
	ASSERT(specclassid < SPA_NUM_SPECIALCLASSES);

	os->os_special_class = specialclass_desc[specclassid];
	if (specclassid == SPA_SPECIALCLASS_WRCACHE)
		(void) start_wrc_thread(spa);
}

static void
spa_enable_special(spa_t *spa, boolean_t usesc)
{
	ASSERT(spa);

	if (!spa_has_special(spa) || usesc == spa->spa_usesc)
		return;

	spa->spa_usesc = usesc;
}


/*
 * Determine whether we should consider writing data to special vdevs
 * for performance reasons
 */
boolean_t
spa_write_data_to_special(spa_t *spa, objset_t *os)
{
	ASSERT(os);
	return ((spa_has_special(spa)) &&
	    (spa->spa_usesc) &&
	    (spa->spa_watermark == SPA_WM_NONE) &&
	    (os->os_special_class.sc_id == SPA_SPECIALCLASS_WRCACHE));
}

spa_specialclass_id_t
spa_specialclass_id(objset_t *os)
{
	ASSERT(os);
	return (os->os_special_class.sc_id);
}

spa_specialclass_t *
spa_get_specialclass(objset_t *os)
{
	ASSERT(os);
	return (&os->os_special_class);
}

uint64_t
spa_specialclass_flags(objset_t *os)
{
	ASSERT(os);
	return (os->os_special_class.sc_flags);
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
 * Checks whether allocated space on a special device
 * crossed either high or low watermarks.
 */
static void
spa_check_watermarks(spa_t *spa)
{
	metaslab_class_t *mc;
	uint64_t aspace, lspace;
	vdev_t *vd = NULL;

	if (!spa_has_special(spa))
		return;

	if (spa->spa_lowat == 0 && spa->spa_hiwat == 0)
		return;

	mc = spa_special_class(spa);
	vd = mc->mc_rotor->mg_vd;
	aspace = metaslab_class_get_alloc(mc);
	spa->spa_lwm_space = spa_special_space_perc(spa, spa->spa_lowat);
	spa->spa_hwm_space = spa_special_space_perc(spa, spa->spa_hiwat);
	spa->spa_wrc_wm_range = spa->spa_hwm_space - spa->spa_lwm_space;

	if (aspace <= spa->spa_lwm_space) {
		if (spa->spa_watermark != SPA_WM_NONE) {
			spa->spa_watermark = SPA_WM_NONE;
			spa_event_notify(spa, vd, ESC_ZFS_NONE_WATERMARK);
		}
		spa_enable_special(spa, B_TRUE);
	} else if (aspace > spa->spa_hwm_space) {
		if (spa->spa_watermark != SPA_WM_HIGH) {
			spa->spa_watermark = SPA_WM_HIGH;
			spa_enable_special(spa, B_FALSE);
			spa_event_notify(spa, vd, ESC_ZFS_HIGH_WATERMARK);
		}
	} else {
		boolean_t wrc_route_init = B_FALSE;
		if (spa->spa_watermark != SPA_WM_LOW) {
			wrc_route_init = B_TRUE;
			if (spa->spa_watermark == SPA_WM_NONE)
				spa_enable_special(spa, B_TRUE);
			spa->spa_watermark = SPA_WM_LOW;
			spa_event_notify(spa, vd, ESC_ZFS_LOW_WATERMARK);
		}
		if (spa->spa_wrc.wrc_thread != NULL) {
			/*
			 * Unlike Meta device, write cache is enabled, when
			 * we change from SPA_WM_HIGH to SPA_WM_LOW and then
			 * enables the throttling logic.
			 */
			if (spa->spa_watermark == SPA_WM_HIGH)
				spa_enable_special(spa, B_TRUE);
			wrc_route_init = B_TRUE;
			lspace = aspace - spa->spa_lwm_space;
			if (spa->spa_wrc_wm_range) {
				spa->spa_wrc_perc = (uint8_t)(lspace * 100 /
				    spa->spa_wrc_wm_range);
			} else {
				spa->spa_wrc_perc = 50;
			}

			wrc_route_set(spa, wrc_route_init);
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
	ASSERT(spa_config_held(mc->mc_spa, SCL_ALL, RW_READER) ||
	    spa_config_held(mc->mc_spa, SCL_ALL, RW_WRITER));

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
	    isgen = DMU_OT_IS_GENERAL_META(ot),
	    iszpl = DMU_OT_IS_ZPL_META(ot);

	if (isddt && (mp->spa_ddt_to_special == META_PLACEMENT_OFF))
		return (B_FALSE);
	else if (isgen && (mp->spa_general_meta_to_special ==
	    META_PLACEMENT_OFF))
		return (B_FALSE);
	else if (iszpl && (zpl_meta_to_special == META_PLACEMENT_OFF))
		return (B_FALSE);
	else if (!isddt && !isgen && !iszpl &&
	    (mp->spa_other_meta_to_special == META_PLACEMENT_OFF))
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
	    isgen = DMU_OT_IS_GENERAL_META(ot),
	    iszpl = DMU_OT_IS_ZPL_META(ot);

	if (isddt && (mp->spa_ddt_to_special != META_PLACEMENT_DUAL))
		return (B_FALSE);
	else if (isgen && (mp->spa_general_meta_to_special !=
	    META_PLACEMENT_DUAL))
		return (B_FALSE);
	else if (iszpl && (zpl_meta_to_special != META_PLACEMENT_DUAL))
		return (B_FALSE);
	else if (!isddt && !isgen && !iszpl &&
	    (mp->spa_other_meta_to_special != META_PLACEMENT_DUAL))
		return (B_FALSE);
	else
		return (B_TRUE);
}

/*
 * Tunable: enable auto-adjustment of load based on performance metrics
 *
 * spa_enable_data_placement_selection - EXPERIMENTAL - enable distribution
 * of I/O load between special and normal classes
 * if true, enables distribution of I/O between special and normal
 * classes according to the spa->spa_special_to_normal_ratio
 * if false, the ratio is disregarded, special class is used when possible
 *
 * spa_enable_best_effort_dedup - enable auto-adjustment of the percentage
 * of data blocks to be de-duplicated
 * if true, enables changing the percentage of data blocks to be deduplicated
 * based on the utilization of the special vdevs
 * if false, all data blocks are deduplicated as usual
 */
boolean_t spa_enable_data_placement_selection = B_FALSE;
boolean_t spa_enable_best_effort_dedup = B_TRUE;
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
    SPA_SPECIAL_SELECTION_LATENCY;
/* Tunable: limits on the ratio of special to normal writes */
uint64_t spa_special_ratio_max = SPA_SPECIAL_RATIO_MAX;
uint64_t spa_special_ratio_min = SPA_SPECIAL_RATIO_MIN;
/* Tunable: factor used to adjust the ratio up/down */
uint64_t spa_special_factor = SPA_SPECIAL_ADJUSTMENT;
/*
 * Tunable: vdev utilization threshold
 * once reached, start re-distributing I/O requests to other vdev classes
 */
int spa_special_vdev_busy = SPA_SPECIAL_UTILIZATION;
int spa_normal_vdev_busy = SPA_SPECIAL_UTILIZATION;

/*
 * Distribute writes across special and normal vdevs in
 * spa_special_to_normal-1:1 proportion
 */
static boolean_t
spa_refine_data_placement(spa_t *spa)
{
	uint64_t val = atomic_inc_64_nv(&spa->spa_special_stat_rotor);
	return (val % spa->spa_special_to_normal_ratio);
}

static boolean_t
spa_meta_to_special(spa_t *spa, objset_t *os, dmu_object_type_t ot)
{
	ASSERT(os);
	/* some duplication of the spa_select_class() here */
	if ((spa->spa_usesc == B_FALSE) || (spa_has_special(spa) == B_FALSE)) {
		return (B_FALSE);
	} else {
		uint64_t specflags = spa_specialclass_flags(os);
		boolean_t match = !!(SPECIAL_FLAG_DATAMETA & specflags);
		return (match && spa_refine_meta_placement(spa,
		    os->os_zpl_meta_to_special, ot));
	}
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
	uint64_t specflags;
	boolean_t match;

	if (!spa_has_special(spa))
		return (B_TRUE);

	specflags = spa_specialclass_flags(db->db_objset);
	match = !!(SPECIAL_FLAG_DATAMETA & specflags);

	DB_DNODE_ENTER(db);
	ot = DB_DNODE(db)->dn_type;
	DB_DNODE_EXIT(db);

	if ((!DMU_OT_IS_DDT_META(ot)) || (!match))
		return (B_TRUE);

	return (mp->spa_ddt_to_special != META_PLACEMENT_ON);
}

/*
 * Select whether to direct zio to special or to normal storage class
 * Even when the top-level criteria match (for placement to the special
 * class), consider refining data and metadata placement based on
 * additional information about the system's behavior
 */
metaslab_class_t *
spa_select_class(spa_t *spa, zio_prop_t *zp)
{
	spa_meta_placement_t *mp = &spa->spa_meta_policy;
	if (zp->zp_usesc && spa_has_special(spa) && spa->spa_usesc) {
		boolean_t match = B_FALSE;
		uint64_t specflags = zp->zp_specflags;

		if (zp->zp_metadata) {
			match = !!(SPECIAL_FLAG_DATAMETA & specflags);
			if (match && mp->spa_enable_meta_placement_selection)
				match = spa_refine_meta_placement(spa,
				    zp->zp_zpl_meta_to_special, zp->zp_type);
		} else {
			match = !!(SPECIAL_FLAG_DATAUSER & specflags);
			if (match && spa_enable_data_placement_selection)
				match = spa_refine_data_placement(spa);
		}

		if (match)
			return (spa_special_class(spa));
	}

	return (spa_normal_class(spa));
}

static void
spa_special_load_adjust(spa_t *spa)
{
	spa_special_stat_t *stat = &spa->spa_special_stat;
	/*
	 * write to special until utilization threshold is reached
	 * then look at either latency or vdev utilization and adjust
	 * load distribution accordingly
	 */
	ASSERT(SPA_SPECIAL_SELECTION_VALID(spa_special_selection));
	switch (spa_special_selection) {
	case SPA_SPECIAL_SELECTION_LATENCY:
		/*
		 * bias selection toward class with smaller
		 * average latency
		 */
		if (stat->normal_lt && stat->special_lt) {
			if (stat->normal_lt > stat->special_lt)
				spa->spa_special_to_normal_ratio *=
				    spa_special_factor;
			if (stat->normal_lt < stat->special_lt)
				spa->spa_special_to_normal_ratio /=
				    spa_special_factor;
		}
		break;
	case SPA_SPECIAL_SELECTION_THROUGHPUT:
		if (stat->special_ut < spa_special_vdev_busy) {
			/*
			 * keep using special class until
			 * the threshold is reached
			 */
			spa->spa_special_to_normal_ratio *= spa_special_factor;
		} else if (stat->normal_ut < spa_normal_vdev_busy) {
			/*
			 * move some of the work to the normal class,
			 * unless it is already busy
			 */
			spa->spa_special_to_normal_ratio /= spa_special_factor;
		}
		break;
	default:
		break; /* do nothing */
	}
	/*
	 * must stay within limits
	 */
	if (spa->spa_special_to_normal_ratio < spa_special_ratio_min)
		spa->spa_special_to_normal_ratio = spa_special_ratio_min;
	if (spa->spa_special_to_normal_ratio > spa_special_ratio_max)
		spa->spa_special_to_normal_ratio = spa_special_ratio_max;
}

/* update vdev utilization stats */
static int
spa_vdev_busy(vdev_t *vd)
{
	vdev_stat_t *vs = &vd->vdev_stat;
	hrtime_t ts = gethrtime();

	ASSERT(MUTEX_HELD(&vd->vdev_stat_lock));
	ASSERT(ts >= vs->vs_wcstart);

	if (vs->vs_wcstart != 0) {
		vs->vs_busy = 100 * vs->vs_bztotal/(ts - vs->vs_wcstart);
	}
	/* reset the busy accumulator and the wall clock start */
	vs->vs_bztotal = 0;
	vs->vs_wcstart = ts;

	return (vs->vs_busy);
}

static void
spa_vdev_walk_stats(vdev_t *pvd, hrtime_t *lt, int *ut, int *nvdev)
{
	int i;
	if (pvd->vdev_children == 0) {
		vdev_stat_t *pvd_stat = &pvd->vdev_stat;
		/* single vdev (itself) */
		ASSERT(pvd->vdev_ops->vdev_op_leaf);
		DTRACE_PROBE1(spa_vdev_walk_lf, vdev_t *, pvd);
		mutex_enter(&pvd->vdev_stat_lock);
		*lt += pvd_stat->vs_latency[ZIO_TYPE_WRITE];
		*ut += spa_vdev_busy(pvd);
		mutex_exit(&pvd->vdev_stat_lock);
		*nvdev = *nvdev+1;
	} else {
		/* not a leaf-level vdev, has children */
		ASSERT(pvd->vdev_ops->vdev_op_leaf == B_FALSE);
		for (i = 0; i < pvd->vdev_children; i++) {
			vdev_t *vd = pvd->vdev_child[i];
			vdev_stat_t *vd_stat = &vd->vdev_stat;
			ASSERT(vd);

			if (vd->vdev_islog || vd->vdev_ishole ||
			    vd->vdev_isspare || vd->vdev_isl2cache)
				continue;

			if (vd->vdev_ops->vdev_op_leaf == B_FALSE) {
				DTRACE_PROBE1(spa_vdev_walk_nl, vdev_t *, vd);
				spa_vdev_walk_stats(vd, lt, ut, nvdev);
			} else {
				DTRACE_PROBE1(spa_vdev_walk_lf, vdev_t *, vd);
				mutex_enter(&vd->vdev_stat_lock);
				*lt += vd_stat->vs_latency[ZIO_TYPE_WRITE];
				*ut += spa_vdev_busy(vd);
				mutex_exit(&vd->vdev_stat_lock);
				*nvdev = *nvdev+1;
			}
		}
	}
}

static void
spa_load_stats_update(spa_t *spa)
{
	int i, nnormal = 0, nspecial = 0;
	vdev_t *rvd;
	spa_special_stat_t spa_stat = {0};

	/*
	 * walk the top level vdevs and calculate average stats for
	 * the normal and special classes
	 */
	spa_config_enter(spa, SCL_VDEV, FTAG, RW_READER);

	rvd = spa->spa_root_vdev;
	ASSERT(rvd);

	for (i = 0; i < rvd->vdev_children; i++) {
		vdev_t *vd = rvd->vdev_child[i];
		ASSERT(vd);

		if (vd->vdev_islog || vd->vdev_ishole ||
		    vd->vdev_isspare || vd->vdev_isl2cache)
			continue;
		if (vd->vdev_isspecial) {
			spa_vdev_walk_stats(vd, &spa_stat.special_lt,
			    &spa_stat.special_ut, &nspecial);
		} else {
			spa_vdev_walk_stats(vd, &spa_stat.normal_lt,
			    &spa_stat.normal_ut, &nnormal);
		}
	}

	spa_config_exit(spa, SCL_VDEV, FTAG);

	DTRACE_PROBE4(spa_vdev_stats, int, nnormal, int, nspecial,
	    int, spa_stat.normal_ut, int, spa_stat.special_ut);

	/* calculate averages */
	if (nnormal) {
		spa->spa_special_stat.normal_lt = spa_stat.normal_lt/nnormal;
		spa->spa_special_stat.normal_ut = spa_stat.normal_ut/nnormal;
	}
	if (nspecial) {
		spa->spa_special_stat.special_lt = spa_stat.special_lt/nspecial;
		spa->spa_special_stat.special_ut = spa_stat.special_ut/nspecial;
	}
}

static void
spa_special_dedup_adjust(spa_t *spa)
{
	int percentage;

	/*
	 * if special_ut < dedup_lo, then percentage = 100;
	 * if special_ut > dedup_hi, then percentage = 0;
	 * otherwise, the percentage changes linearly from 100 to 0
	 * as special_ut moves from dedup_lo to dedup_hi
	 */
	percentage = 100 - 100 *
	    (spa->spa_special_stat.special_ut - spa->spa_dedup_lo_best_effort) /
	    (spa->spa_dedup_hi_best_effort - spa->spa_dedup_lo_best_effort);
	/* enforce proper percentage limits */
	percentage = MIN(percentage, 100);
	percentage = MAX(percentage, 0);

	spa->spa_dedup_percentage = percentage;
}

/* Tunable: period (~10ms per tick) for updating spa vdev stats */
clock_t spa_special_stat_update_ticks = 10;

/* Performance monitor thread */
static void
spa_perfmon_thread(spa_t *spa)
{
	spa_perfmon_data_t *data = &spa->spa_perfmon;
	boolean_t done = B_FALSE;

	ASSERT(data);

	DTRACE_PROBE1(spa_pm_start, spa_t *, spa);

	/* take a reference against spa */
	mutex_enter(&spa_namespace_lock);
	spa_open_ref(spa, FTAG);
	mutex_exit(&spa_namespace_lock);

	/* CONSTCOND */
	while (1) {
		clock_t deadline = ddi_get_lbolt() +
		    spa_special_stat_update_ticks;

		/* wait for the next tick, check exit condition */
		mutex_enter(&data->perfmon_lock);
		(void) cv_timedwait(&data->perfmon_cv, &data->perfmon_lock,
		    deadline);
		if (spa->spa_state == POOL_STATE_UNINITIALIZED ||
		    data->perfmon_thr_exit)
			done = B_TRUE;
		mutex_exit(&data->perfmon_lock);

		if (done)
			goto out;

		/*
		 * do the monitoring work here: gather average
		 * latency and utilization statistics
		 */
		DTRACE_PROBE1(spa_pm_work, spa_t *, spa);
		spa_load_stats_update(spa);

		/* we can adjust load and dedup at the same time */
		if (spa_enable_data_placement_selection)
			spa_special_load_adjust(spa);
		if (spa->spa_dedup_best_effort)
			spa_special_dedup_adjust(spa);

		/* go to sleep until next tick */
		DTRACE_PROBE1(spa_pm_sleep, spa_t *, spa);
	}

out:
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
		data->perfmon_thread = thread_create(NULL, 0,
		    spa_perfmon_thread, spa, 0, &p0, TS_RUN, maxclsyspri);
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
		thread_join(data->perfmon_thread->t_did);
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
