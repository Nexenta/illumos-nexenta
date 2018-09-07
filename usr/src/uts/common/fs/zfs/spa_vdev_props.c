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
 * Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/spa_impl.h>
#include <sys/vdev_impl.h>
#include <sys/cos_impl.h>
#include <sys/refcount.h>
#include <sys/dmu.h>
#include <sys/dsl_synctask.h>
#include <sys/zap.h>
#include <sys/zfeature.h>

#include <zfs_prop.h>

/*
 * Support for vdev-specific properties. Similar properties can be set
 * on per-pool basis; vdev-specific properties override per-pool ones.
 * In addition to path and fru, the supported vdev properties include
 * min_active/max_active (request queue length params), and preferred
 * read (biases reads toward this device if it is a part of a mirror).
 */

/*
 * Add vdev properties for this vdev to nvl_array[index]
 */
static void
vdev_add_props(vdev_t *vdev, nvlist_t *nvl_array[], uint_t *index)
{
	const char *propname;
	zio_priority_t p;

	if (!vdev->vdev_ops->vdev_op_leaf) {
		for (int c = 0; c < vdev->vdev_children; c++) {
			vdev_add_props(vdev->vdev_child[c], nvl_array,
			    index);
		}
		return;
	}

	propname = vdev_prop_to_name(VDEV_PROP_GUID);
	VERIFY0(nvlist_add_uint64(nvl_array[*index], propname,
	    vdev->vdev_guid));

	for (p = ZIO_PRIORITY_SYNC_READ; p < ZIO_PRIORITY_NUM_QUEUEABLE; p++) {
		uint64_t val = vdev->vdev_queue.vq_class[p].vqc_min_active;
		int prop_id = VDEV_ZIO_PRIO_TO_PROP_MIN(p);

		ASSERT(VDEV_PROP_MIN_VALID(prop_id));
		propname = vdev_prop_to_name(prop_id);
		VERIFY0(nvlist_add_uint64(nvl_array[*index], propname, val));

		val = vdev->vdev_queue.vq_class[p].vqc_max_active;
		prop_id = VDEV_ZIO_PRIO_TO_PROP_MAX(p);
		ASSERT(VDEV_PROP_MAX_VALID(prop_id));
		propname = vdev_prop_to_name(prop_id);
		VERIFY0(nvlist_add_uint64(nvl_array[*index], propname, val));
	}

	propname = vdev_prop_to_name(VDEV_PROP_PREFERRED_READ);
	VERIFY0(nvlist_add_uint64(nvl_array[*index], propname,
	    vdev->vdev_queue.vq_preferred_read));

	if (vdev->vdev_queue.vq_cos) {
		propname = vdev_prop_to_name(VDEV_PROP_COS);
		VERIFY0(nvlist_add_uint64(nvl_array[*index], propname,
		    vdev->vdev_queue.vq_cos->cos_guid));
	}

	if (vdev->vdev_spare_group) {
		propname = vdev_prop_to_name(VDEV_PROP_SPAREGROUP);
		VERIFY0(nvlist_add_string(nvl_array[*index], propname,
		    vdev->vdev_spare_group));
	}

	propname = vdev_prop_to_name(VDEV_PROP_L2ADDDT);
	VERIFY0(nvlist_add_uint64(nvl_array[*index], propname,
	    vdev->vdev_l2ad_ddt));

	(*index)++;
}

/*
 * Get the properties from nvlist and put them in vdev object
 */
static void
vdev_parse_props(vdev_t *vdev, nvlist_t *nvl)
{
	uint64_t ival;
	const char *propname;
	char *sval;
	zio_priority_t p;

	ASSERT(vdev);

	if (!vdev->vdev_ops->vdev_op_leaf)
		return;

	for (p = ZIO_PRIORITY_SYNC_READ; p < ZIO_PRIORITY_NUM_QUEUEABLE; p++) {
		int prop_id = VDEV_ZIO_PRIO_TO_PROP_MIN(p);

		ASSERT(VDEV_PROP_MIN_VALID(prop_id));
		propname = vdev_prop_to_name(prop_id);

		if (nvlist_lookup_uint64(nvl, propname, &ival) == 0)
			vdev->vdev_queue.vq_class[p].vqc_min_active = ival;

		prop_id = VDEV_ZIO_PRIO_TO_PROP_MAX(p);
		ASSERT(VDEV_PROP_MAX_VALID(prop_id));
		propname = vdev_prop_to_name(prop_id);
		if (nvlist_lookup_uint64(nvl, propname, &ival) == 0)
			vdev->vdev_queue.vq_class[p].vqc_max_active = ival;
	}

	propname = vdev_prop_to_name(VDEV_PROP_L2ADDDT);
	if (nvlist_lookup_uint64(nvl, propname, &ival) == 0) {
		vdev->vdev_l2ad_ddt = ival;
		/* on import may need to adjust per SPA DDT dev space count */
		if (vdev->vdev_l2ad_ddt == 1) {
			atomic_add_64(&vdev->vdev_spa->spa_l2arc_ddt_devs_size,
			    vdev_get_min_asize(vdev));
		}
	}

	propname = vdev_prop_to_name(VDEV_PROP_PREFERRED_READ);
	if (nvlist_lookup_uint64(nvl, propname, &ival) == 0)
		vdev->vdev_queue.vq_preferred_read = ival;
	propname = vdev_prop_to_name(VDEV_PROP_COS);
	if (nvlist_lookup_uint64(nvl, propname, &ival) == 0) {
		/*
		 * At this time, all CoS properties have been loaded.
		 * Lookup CoS by guid and take it if found.
		 */
		cos_t *cos = NULL;
		spa_t *spa = vdev->vdev_spa;
		spa_cos_enter(spa);
		cos = spa_lookup_cos_by_guid(spa, ival);
		if (cos) {
			cos_hold(cos);
			vdev->vdev_queue.vq_cos = cos;
		} else {
			cmn_err(CE_WARN, "vdev %s refers to non-existent "
			    "CoS %" PRIu64 "\n", vdev->vdev_path, ival);
			vdev->vdev_queue.vq_cos = NULL;
		}
		spa_cos_exit(spa);
	}
	propname = vdev_prop_to_name(VDEV_PROP_SPAREGROUP);
	if (nvlist_lookup_string(nvl, propname, &sval) == 0)
		vdev->vdev_spare_group = spa_strdup(sval);
}

/*
 * Get specific property for a leaf-level vdev by property id or name.
 */
static int
spa_vdev_get_common(spa_t *spa, uint64_t guid, char **value,
    uint64_t *oval, vdev_prop_t prop)
{
	vdev_t *vd;
	vdev_queue_class_t *vqc;
	zio_priority_t p;

	spa_vdev_state_enter(spa, SCL_ALL);

	if ((vd = spa_lookup_by_guid(spa, guid, B_TRUE)) == NULL)
		return (spa_vdev_state_exit(spa, NULL, EINVAL));

	if (!vd->vdev_ops->vdev_op_leaf)
		return (spa_vdev_state_exit(spa, NULL, EINVAL));

	vqc = vd->vdev_queue.vq_class;

	switch (prop) {
	case VDEV_PROP_L2ADDDT:
		*oval = vd->vdev_l2ad_ddt;
		break;
	case VDEV_PROP_PATH:
		if (vd->vdev_path != NULL) {
			*value = vd->vdev_path;
		}
		break;
	case VDEV_PROP_GUID:
		*oval = guid;
		break;
	case VDEV_PROP_FRU:
		if (vd->vdev_fru != NULL) {
			*value = vd->vdev_fru;
		}
		break;

	case VDEV_PROP_READ_MINACTIVE:
	case VDEV_PROP_AREAD_MINACTIVE:
	case VDEV_PROP_WRITE_MINACTIVE:
	case VDEV_PROP_AWRITE_MINACTIVE:
	case VDEV_PROP_SCRUB_MINACTIVE:
	case VDEV_PROP_RESILVER_MINACTIVE:
		p = VDEV_PROP_TO_ZIO_PRIO_MIN(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		*oval = vqc[p].vqc_min_active;
		break;

	case VDEV_PROP_READ_MAXACTIVE:
	case VDEV_PROP_AREAD_MAXACTIVE:
	case VDEV_PROP_WRITE_MAXACTIVE:
	case VDEV_PROP_AWRITE_MAXACTIVE:
	case VDEV_PROP_SCRUB_MAXACTIVE:
	case VDEV_PROP_RESILVER_MAXACTIVE:
		p = VDEV_PROP_TO_ZIO_PRIO_MAX(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		*oval = vqc[p].vqc_max_active;
		break;

	case VDEV_PROP_PREFERRED_READ:
		*oval = vd->vdev_queue.vq_preferred_read;
		break;

	case VDEV_PROP_COS:
		if (vd->vdev_queue.vq_cos != NULL) {
			*value = vd->vdev_queue.vq_cos->cos_name;
		} else {
			*value = NULL;
			return (spa_vdev_state_exit(spa, NULL, ENOENT));
		}
		break;

	case VDEV_PROP_SPAREGROUP:
		if (vd->vdev_spare_group != NULL) {
			*value = vd->vdev_spare_group;
		} else {
			*value = NULL;
			return (spa_vdev_state_exit(spa, NULL, ENOENT));
		}
		break;

	default:
		return (spa_vdev_state_exit(spa, NULL, ENOTSUP));
	}

	return (spa_vdev_state_exit(spa, NULL, 0));
}

/*
 * Update the stored property for this vdev.
 */
static int
spa_vdev_set_common(vdev_t *vd, const char *value,
    uint64_t ival, vdev_prop_t prop)
{
	spa_t *spa = vd->vdev_spa;
	cos_t *cos = NULL, *cos_to_release = NULL;
	boolean_t sync = B_FALSE;
	boolean_t reset_cos = B_FALSE;
	vdev_queue_class_t *vqc = vd->vdev_queue.vq_class;
	zio_priority_t p;
	int64_t ddt_devs_size;
	nvlist_t *nvp;
	int err;
	const char *propname = vdev_prop_to_name(prop);

	ASSERT(spa_writeable(spa));

	spa_vdev_state_enter(spa, SCL_ALL);

	if (!vd->vdev_ops->vdev_op_leaf)
		return (spa_vdev_state_exit(spa, NULL, EINVAL));

	VERIFY0(nvlist_alloc(&nvp, NV_UNIQUE_NAME, KM_SLEEP));
	if (value == NULL)
		VERIFY0(nvlist_add_uint64(nvp, propname, ival));
	else
		VERIFY0(nvlist_add_string(nvp, propname, value));
	err = spa_vdev_prop_validate(spa, vd->vdev_guid, nvp);
	nvlist_free(nvp);
	if (err != 0)
		return (spa_vdev_state_exit(spa, NULL, err));

	switch (prop) {
	case VDEV_PROP_L2ADDDT:
		if (vd->vdev_l2ad_ddt != ival) {
			vd->vdev_l2ad_ddt = ival;
			ddt_devs_size = vdev_get_min_asize(vd);
			if (ival == 0)
				ddt_devs_size *= -1;
			atomic_add_64(&vd->vdev_spa->spa_l2arc_ddt_devs_size,
			    ddt_devs_size);
			sync = B_TRUE;
		}
		break;

	case VDEV_PROP_PATH:
		if (vd->vdev_path == NULL) {
			vd->vdev_path = spa_strdup(value);
			sync = B_TRUE;
		} else if (strcmp(value, vd->vdev_path) != 0) {
			spa_strfree(vd->vdev_path);
			vd->vdev_path = spa_strdup(value);
			sync = B_TRUE;
		}
		break;

	case VDEV_PROP_FRU:
		if (vd->vdev_fru == NULL) {
			vd->vdev_fru = spa_strdup(value);
			sync = B_TRUE;
		} else if (strcmp(value, vd->vdev_fru) != 0) {
			spa_strfree(vd->vdev_fru);
			vd->vdev_fru = spa_strdup(value);
			sync = B_TRUE;
		}
		break;

	case VDEV_PROP_READ_MINACTIVE:
	case VDEV_PROP_AREAD_MINACTIVE:
	case VDEV_PROP_WRITE_MINACTIVE:
	case VDEV_PROP_AWRITE_MINACTIVE:
	case VDEV_PROP_SCRUB_MINACTIVE:
	case VDEV_PROP_RESILVER_MINACTIVE:
		p = VDEV_PROP_TO_ZIO_PRIO_MIN(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		vqc[p].vqc_min_active = ival;
		break;

	case VDEV_PROP_READ_MAXACTIVE:
	case VDEV_PROP_AREAD_MAXACTIVE:
	case VDEV_PROP_WRITE_MAXACTIVE:
	case VDEV_PROP_AWRITE_MAXACTIVE:
	case VDEV_PROP_SCRUB_MAXACTIVE:
	case VDEV_PROP_RESILVER_MAXACTIVE:
		p = VDEV_PROP_TO_ZIO_PRIO_MAX(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		vqc[p].vqc_max_active = ival;
		break;

	case VDEV_PROP_PREFERRED_READ:
		vd->vdev_queue.vq_preferred_read = ival;
		break;

	case VDEV_PROP_COS:
		spa_cos_enter(spa);

		if ((value == NULL || value[0] == '\0') && ival == 0) {
			reset_cos = B_TRUE;
		} else {
			if (ival != 0)
				cos = spa_lookup_cos_by_guid(spa, ival);
			else
				cos = spa_lookup_cos_by_name(spa, value);
		}

		if (!reset_cos && cos == NULL) {
			spa_cos_exit(spa);
			return (spa_vdev_state_exit(spa, NULL, ENOENT));
		}

		cos_to_release = vd->vdev_queue.vq_cos;

		if (reset_cos) {
			vd->vdev_queue.vq_cos = NULL;
		} else {
			cos_hold(cos);
			vd->vdev_queue.vq_cos = cos;
		}

		if (cos_to_release)
			cos_rele(cos_to_release);

		spa_cos_exit(spa);
		break;

	case VDEV_PROP_SPAREGROUP:
		if (vd->vdev_spare_group == NULL) {
			vd->vdev_spare_group = spa_strdup(value);
			sync = B_TRUE;
		} else if (strcmp(value, vd->vdev_spare_group) != 0) {
			spa_strfree(vd->vdev_spare_group);
			vd->vdev_spare_group = spa_strdup(value);
			sync = B_TRUE;
		}
		break;

	case VDEV_PROP_GUID:
	default:
		return (spa_vdev_state_exit(spa, NULL, ENOTSUP));
	}

	return (spa_vdev_state_exit(spa, sync ? vd : NULL, 0));
}

/*
 * Set properties (names, values) in this nvlist, indicate if sync is needed
 */
static int
spa_vdev_prop_set_nosync(vdev_t *vd, nvlist_t *nvp, boolean_t *needsyncp)
{
	int error = 0;
	nvpair_t *elem;
	vdev_prop_t prop;
	boolean_t need_sync = B_FALSE;

	elem = NULL;
	while ((elem = nvlist_next_nvpair(nvp, elem)) != NULL) {
		uint64_t ival = 0;
		char *strval = NULL;
		zprop_type_t proptype;
		if ((prop = vdev_name_to_prop(
		    nvpair_name(elem))) == ZPROP_INVAL)
			return (ENOTSUP);

		switch (prop) {
		case VDEV_PROP_L2ADDDT:
		case VDEV_PROP_READ_MINACTIVE:
		case VDEV_PROP_READ_MAXACTIVE:
		case VDEV_PROP_AREAD_MINACTIVE:
		case VDEV_PROP_AREAD_MAXACTIVE:
		case VDEV_PROP_WRITE_MINACTIVE:
		case VDEV_PROP_WRITE_MAXACTIVE:
		case VDEV_PROP_AWRITE_MINACTIVE:
		case VDEV_PROP_AWRITE_MAXACTIVE:
		case VDEV_PROP_SCRUB_MINACTIVE:
		case VDEV_PROP_SCRUB_MAXACTIVE:
		case VDEV_PROP_RESILVER_MAXACTIVE:
		case VDEV_PROP_RESILVER_MINACTIVE:
		case VDEV_PROP_PREFERRED_READ:
		case VDEV_PROP_COS:
		case VDEV_PROP_SPAREGROUP:
			need_sync = B_TRUE;
			break;
		default:
			need_sync = B_FALSE;
		}

		proptype = vdev_prop_get_type(prop);

		switch (proptype) {
		case PROP_TYPE_STRING:
			VERIFY0(nvpair_value_string(elem, &strval));
			break;

		case PROP_TYPE_INDEX:
		case PROP_TYPE_NUMBER:
			if (proptype == PROP_TYPE_INDEX) {
				const char *unused;
				VERIFY0(vdev_prop_index_to_string(
				    prop, ival, &unused));
			}
			VERIFY0(nvpair_value_uint64(elem, &ival));
			break;

		}

		error = spa_vdev_set_common(vd, strval, ival, prop);
	}

	if (needsyncp != NULL)
		*needsyncp = need_sync;

	return (error);
}

/*
 * Store properties of vdevs in the pool in the MOS of that pool
 */
static void
spa_vdev_sync_props(void *arg1, dmu_tx_t *tx)
{
	spa_t *spa = (spa_t *)arg1;
	objset_t *mos = spa->spa_meta_objset;
	size_t size, nvsize;
	uint64_t *sizep;
	vdev_t *root_vdev;
	vdev_t *top_vdev;
	nvlist_t **nvl_array, *nvl;
	dmu_buf_t *db;
	char *buf;
	uint_t index = 0;
	uint_t vdev_cnt = vdev_count_leaf_vdevs(spa->spa_root_vdev) +
	    spa->spa_l2cache.sav_count + spa->spa_spares.sav_count;

	VERIFY0(nvlist_alloc(&nvl, NV_UNIQUE_NAME, KM_SLEEP));
	nvl_array = kmem_alloc(vdev_cnt * sizeof (nvlist_t *), KM_SLEEP);

	for (int i = 0; i < vdev_cnt; i++)
		VERIFY0(nvlist_alloc(&nvl_array[i], NV_UNIQUE_NAME, KM_SLEEP));

	mutex_enter(&spa->spa_vdev_props_lock);

	if (spa->spa_vdev_props_object == 0) {
		VERIFY((spa->spa_vdev_props_object =
		    dmu_object_alloc(mos, DMU_OT_PACKED_NVLIST,
		    SPA_CONFIG_BLOCKSIZE, DMU_OT_PACKED_NVLIST_SIZE,
		    sizeof (uint64_t), tx)) > 0);

		VERIFY0(zap_update(mos,
		    DMU_POOL_DIRECTORY_OBJECT,
		    DMU_POOL_VDEV_PROPS,
		    8, 1, &spa->spa_vdev_props_object, tx));

		spa_feature_incr(spa, SPA_FEATURE_VDEV_PROPS, tx);
	}

	root_vdev = spa->spa_root_vdev;
	/* process regular vdevs */
	for (int c = 0; c < spa->spa_root_vdev->vdev_children; c++) {
		top_vdev = root_vdev->vdev_child[c];
		vdev_add_props(top_vdev, nvl_array, &index);
	}

	/* process aux vdevs */
	for (int i = 0; i < spa->spa_l2cache.sav_count; i++) {
		vdev_t *vd = spa->spa_l2cache.sav_vdevs[i];
		vdev_add_props(vd, nvl_array, &index);
	}

	for (int i = 0; i < spa->spa_spares.sav_count; i++) {
		vdev_t *vd = spa->spa_spares.sav_vdevs[i];
		vdev_add_props(vd, nvl_array, &index);
	}
	ASSERT3P(index, ==, vdev_cnt);

	VERIFY0(nvlist_add_nvlist_array(nvl,
	    DMU_POOL_VDEV_PROPS, nvl_array, vdev_cnt));

	VERIFY0(nvlist_size(nvl, &nvsize, NV_ENCODE_XDR));
	size = P2ROUNDUP(nvsize, 8);
	buf = kmem_zalloc(size, KM_SLEEP);
	VERIFY0(nvlist_pack(nvl, &buf, &size, NV_ENCODE_XDR, KM_SLEEP));

	dmu_write(mos, spa->spa_vdev_props_object, 0, size, buf, tx);

	VERIFY0(dmu_bonus_hold(mos, spa->spa_vdev_props_object, FTAG, &db));
	dmu_buf_will_dirty(db, tx);

	sizep = db->db_data;
	*sizep = size;

	dmu_buf_rele(db, FTAG);

	kmem_free(buf, size);

	mutex_exit(&spa->spa_vdev_props_lock);

	for (int i = 0; i < vdev_cnt; i++)
		nvlist_free(nvl_array[i]);

	kmem_free(nvl_array, vdev_cnt * sizeof (nvlist_t *));
	nvlist_free(nvl);
}

int
spa_vdev_props_sync_task_do(spa_t *spa)
{
	return (dsl_sync_task(spa->spa_name, NULL, spa_vdev_sync_props,
	    spa, 3, ZFS_SPACE_CHECK_RESERVED));
}

/*
 * Load vdev properties from the vdev_props_object in the MOS
 */
int
spa_load_vdev_props(spa_t *spa)
{
	objset_t *mos = spa->spa_meta_objset;
	vdev_t *vdev;
	dmu_buf_t *db;
	size_t bufsize = 0;
	char *buf;
	uint_t nelem;
	nvlist_t *nvl, **prop_array;
	uint64_t vdev_guid;

	ASSERT(spa);

	if (spa->spa_vdev_props_object == 0)
		return (ENOENT);

	mutex_enter(&spa->spa_vdev_props_lock);

	VERIFY0(dmu_bonus_hold(mos, spa->spa_vdev_props_object, FTAG, &db));
	bufsize = *(uint64_t *)db->db_data;
	dmu_buf_rele(db, FTAG);

	if (bufsize == 0)
		goto out;

	buf = kmem_alloc(bufsize, KM_SLEEP);
	VERIFY0(nvlist_alloc(&nvl, NV_UNIQUE_NAME, KM_SLEEP));

	/* read and unpack array of nvlists */
	VERIFY0(dmu_read(mos, spa->spa_vdev_props_object,
	    0, bufsize, buf, DMU_READ_PREFETCH));
	VERIFY0(nvlist_unpack(buf, bufsize, &nvl, KM_SLEEP));
	VERIFY0(nvlist_lookup_nvlist_array(nvl,
	    DMU_POOL_VDEV_PROPS, &prop_array, &nelem));
	for (uint_t i = 0; i < nelem; i++) {
		VERIFY0(nvlist_lookup_uint64(prop_array[i],
		    vdev_prop_to_name(VDEV_PROP_GUID), &vdev_guid));
		vdev = spa_lookup_by_guid(spa, vdev_guid, B_TRUE);
		if (vdev == NULL)
			continue;
		vdev_parse_props(vdev, prop_array[i]);
	}
	nvlist_free(nvl);

out:
	mutex_exit(&spa->spa_vdev_props_lock);

	return (0);
}

/*
 * Check properties (names, values) in this nvlist
 */
int
spa_vdev_prop_validate(spa_t *spa, uint64_t vdev_guid, nvlist_t *props)
{
	nvpair_t *elem;
	int error = 0;

	if (!spa_feature_is_enabled(spa, SPA_FEATURE_VDEV_PROPS))
		return (SET_ERROR(ENOTSUP));

	elem = NULL;
	while ((elem = nvlist_next_nvpair(props, elem)) != NULL) {
		vdev_prop_t prop;
		char *propname;
		uint64_t ival;

		propname = nvpair_name(elem);

		if ((prop = vdev_name_to_prop(propname)) == ZPROP_INVAL)
			return (SET_ERROR(EINVAL));

		switch (prop) {
		case VDEV_PROP_L2ADDDT:
			if (!spa_l2cache_exists(vdev_guid, NULL)) {
				error = SET_ERROR(ENOTSUP);
				break;
			}
			error = nvpair_value_uint64(elem, &ival);
			if (!error && ival != 1 && ival != 0)
				error = SET_ERROR(EINVAL);
			break;

		case VDEV_PROP_PATH:
		case VDEV_PROP_GUID:
		case VDEV_PROP_FRU:
		case VDEV_PROP_COS:
		case VDEV_PROP_SPAREGROUP:
			break;

		case VDEV_PROP_READ_MINACTIVE:
		case VDEV_PROP_AREAD_MINACTIVE:
		case VDEV_PROP_WRITE_MINACTIVE:
		case VDEV_PROP_AWRITE_MINACTIVE:
		case VDEV_PROP_SCRUB_MINACTIVE:
		case VDEV_PROP_RESILVER_MINACTIVE:
		case VDEV_PROP_READ_MAXACTIVE:
		case VDEV_PROP_AREAD_MAXACTIVE:
		case VDEV_PROP_WRITE_MAXACTIVE:
		case VDEV_PROP_AWRITE_MAXACTIVE:
		case VDEV_PROP_SCRUB_MAXACTIVE:
		case VDEV_PROP_RESILVER_MAXACTIVE:
			error = nvpair_value_uint64(elem, &ival);
			if (!error && ival > 1000)
				error = SET_ERROR(EINVAL);
			break;

		case VDEV_PROP_PREFERRED_READ:
			error = nvpair_value_uint64(elem, &ival);
			if (!error && ival > 10)
				error = SET_ERROR(EINVAL);
			break;

		default:
			error = SET_ERROR(EINVAL);
		}

		if (error)
			break;
	}

	return (error);
}

/*
 * Set properties for the vdev and its children
 */
int
spa_vdev_prop_set(spa_t *spa, uint64_t vdev_guid, nvlist_t *nvp)
{
	int error;
	vdev_t	*vd;
	boolean_t need_sync = B_FALSE;

	if ((error = spa_vdev_prop_validate(spa, vdev_guid, nvp)) != 0)
		return (error);

	if ((vd = spa_lookup_by_guid(spa, vdev_guid, B_TRUE)) == NULL)
		return (ENOENT);

	if (!vd->vdev_ops->vdev_op_leaf) {
		int i;
		for (i = 0; i < vd->vdev_children; i++) {
			error = spa_vdev_prop_set(spa,
			    vd->vdev_child[i]->vdev_guid, nvp);
			if (error != 0)
				break;
		}

		return (error);
	}

	if ((error = spa_vdev_prop_set_nosync(vd, nvp, &need_sync)) != 0)
		return (error);

	if (need_sync)
		return (spa_vdev_props_sync_task_do(spa));

	return (error);
}

/*
 * Get properties for the vdev, put them on nvlist
 */
int
spa_vdev_prop_get(spa_t *spa, uint64_t vdev_guid, nvlist_t **nvp)
{
	int err;
	vdev_prop_t prop;

	VERIFY0(nvlist_alloc(nvp, NV_UNIQUE_NAME, KM_SLEEP));

	for (prop = VDEV_PROP_PATH; prop < VDEV_NUM_PROPS; prop++) {
		uint64_t ival;
		char *strval = NULL;
		const char *propname = vdev_prop_to_name(prop);

		/* don't get L2ARC prop for non L2ARC dev, can't set anyway */
		if (prop == VDEV_PROP_L2ADDDT &&
		    !spa_l2cache_exists(vdev_guid, NULL))
			continue;

		if ((err = spa_vdev_get_common(spa, vdev_guid, &strval,
		    &ival, prop)) != 0 && (err != ENOENT))
			return (err);

		if (strval != NULL) {
			VERIFY0(nvlist_add_string(*nvp, propname, strval));
		} else if (err != ENOENT) {
			VERIFY0(nvlist_add_uint64(*nvp, propname, ival));
		}
	}

	return (0);
}

int
spa_vdev_setl2adddt(spa_t *spa, uint64_t guid, const char *newval)
{
	vdev_t *vdev;
	uint64_t index;

	if ((vdev = spa_lookup_by_guid(spa, guid, B_TRUE)) == NULL)
		return (SET_ERROR(ENOENT));

	if (vdev_prop_string_to_index(VDEV_PROP_L2ADDDT, newval, &index) != 0)
		return (SET_ERROR(EINVAL));

	return (spa_vdev_set_common(vdev, NULL, index, VDEV_PROP_L2ADDDT));
}

int
spa_vdev_setpath(spa_t *spa, uint64_t guid, const char *newpath)
{
	vdev_t *vdev;

	if ((vdev = spa_lookup_by_guid(spa, guid, B_TRUE)) == NULL)
		return (ENOENT);

	return (spa_vdev_set_common(vdev, newpath, 0, VDEV_PROP_PATH));
}

int
spa_vdev_setfru(spa_t *spa, uint64_t guid, const char *newfru)
{
	vdev_t *vdev;

	if ((vdev = spa_lookup_by_guid(spa, guid, B_TRUE)) == NULL)
		return (ENOENT);

	return (spa_vdev_set_common(vdev, newfru, 0, VDEV_PROP_FRU));
}
