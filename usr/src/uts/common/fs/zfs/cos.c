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

#include <sys/dmu_tx.h>
#include <sys/zap.h>
#include <sys/dsl_synctask.h>
#include <sys/spa_impl.h>
#include <sys/cos_impl.h>
#include <sys/vdev_impl.h>
#include <sys/dbuf.h>
#include <sys/debug.h>
#include <sys/zfeature.h>
#include "zfs_prop.h"

/* Static name of the CoS property list */
#define	COS_ARRAY	"COS_ARRAY"

static int spa_alloc_cos_nosync(spa_t *spa, const char *cosname,
    uint64_t cosid);
static int cos_set_common(cos_t *cos, const char *strval, uint64_t ival,
    cos_prop_t prop);
static int cos_get_common(cos_t *cos, char **value, uint64_t *oval,
    cos_prop_t prop);

typedef boolean_t (*cos_func_t)(cos_t *, void *);

void
spa_cos_enter(spa_t *spa)
{
	mutex_enter(&spa->spa_cos_props_lock);
}

void
spa_cos_exit(spa_t *spa)
{
	mutex_exit(&spa->spa_cos_props_lock);
}

static boolean_t
cos_match_guid(cos_t *cos, void *match_data)
{
	uint64_t guid = (uint64_t)(unsigned long)match_data;
	return (cos->cos_guid == guid);
}

static boolean_t
cos_match_name(cos_t *cos, void *match_data)
{
	const char *name = (const char *)match_data;
	return (strncmp(cos->cos_name, name, MAXCOSNAMELEN-1) == 0);
}

static cos_t *
spa_foreach_cos(spa_t *spa, cos_func_t cos_f, void *data)
{
	cos_t *cos, *next_cos;

	for (cos = list_head(&spa->spa_cos_list); cos != NULL;
	    cos = next_cos) {
		next_cos = list_next(&spa->spa_cos_list, cos);
		if (cos_f(cos, data))
			break;
	}

	return (cos);
}

cos_t *
spa_lookup_cos_by_guid(spa_t *spa, uint64_t guid)
{
	return (spa_foreach_cos(spa, cos_match_guid,
	    (void *)(unsigned long)guid));
}

cos_t *
spa_lookup_cos_by_name(spa_t *spa, const char *name)
{
	if (name == NULL)
		return (NULL);
	return (spa_foreach_cos(spa, cos_match_name, (void *)name));
}

uint64_t
cos_refcount(cos_t *cos)
{
	return (cos->cos_refcnt);
}

void
cos_hold(cos_t *cos)
{
	atomic_inc_64(&cos->cos_refcnt);
}

void
cos_rele(cos_t *cos)
{
	ASSERT(cos->cos_refcnt);
	atomic_dec_64(&cos->cos_refcnt);
}

static int
cos_set_common(cos_t *cos, const char *strval, uint64_t ival, cos_prop_t prop)
{
	zio_priority_t p;

	switch (prop) {
	case COS_PROP_NAME:
		(void) snprintf(cos->cos_name, MAXCOSNAMELEN,
		    "%s", strval);
		break;

	case COS_PROP_PREFERRED_READ:
		cos->cos_preferred_read = (boolean_t)ival;
		break;

	case COS_PROP_READ_MINACTIVE:
	case COS_PROP_AREAD_MINACTIVE:
	case COS_PROP_WRITE_MINACTIVE:
	case COS_PROP_AWRITE_MINACTIVE:
	case COS_PROP_SCRUB_MINACTIVE:
	case COS_PROP_RESILVER_MINACTIVE:
		p = COS_PROP_TO_ZIO_PRIO_MIN(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		cos->cos_min_active[p] = ival;
		break;

	case COS_PROP_READ_MAXACTIVE:
	case COS_PROP_AREAD_MAXACTIVE:
	case COS_PROP_WRITE_MAXACTIVE:
	case COS_PROP_AWRITE_MAXACTIVE:
	case COS_PROP_SCRUB_MAXACTIVE:
	case COS_PROP_RESILVER_MAXACTIVE:
		p = COS_PROP_TO_ZIO_PRIO_MAX(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		cos->cos_max_active[p] = ival;
		break;

	default:
		return (SET_ERROR(ENOTSUP));
	}

	return (0);
}

/*ARGSUSED*/
static int
cos_get_common(cos_t *cos, char **value, uint64_t *oval, cos_prop_t prop)
{
	zio_priority_t p;

	switch (prop) {
	case COS_PROP_GUID:
		*oval = cos->cos_guid;
		break;

	case COS_PROP_NAME:
		if (cos->cos_name[0] != '\0')
			*value = spa_strdup(cos->cos_name);
		break;

	case COS_PROP_PREFERRED_READ:
		*oval = cos->cos_preferred_read;
		break;

	case COS_PROP_READ_MINACTIVE:
	case COS_PROP_AREAD_MINACTIVE:
	case COS_PROP_WRITE_MINACTIVE:
	case COS_PROP_AWRITE_MINACTIVE:
	case COS_PROP_SCRUB_MINACTIVE:
	case COS_PROP_RESILVER_MINACTIVE:
		p = COS_PROP_TO_ZIO_PRIO_MIN(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		*oval = cos->cos_min_active[p];
		break;

	case COS_PROP_READ_MAXACTIVE:
	case COS_PROP_AREAD_MAXACTIVE:
	case COS_PROP_WRITE_MAXACTIVE:
	case COS_PROP_AWRITE_MAXACTIVE:
	case COS_PROP_SCRUB_MAXACTIVE:
	case COS_PROP_RESILVER_MAXACTIVE:
		p = COS_PROP_TO_ZIO_PRIO_MAX(prop);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(p));
		*oval = cos->cos_max_active[p];
		break;

	default:
		return (SET_ERROR(ENOTSUP));
	}

	return (0);
}

/* ARGSUSED */
static boolean_t
cos_count(cos_t *cos, void *cntp)
{
	spa_t *spa = cos->cos_spa;
	size_t *counterp = cntp;

	ASSERT(MUTEX_HELD(&spa->spa_cos_props_lock));

	(*counterp)++;

	/*
	 * The B_FALSE is an indication to spa_foreach_cos()
	 * to continue iterating along the cos list
	 */
	return (B_FALSE);
}

static void
cos_sync_classes(spa_t *spa, uint64_t obj, dmu_tx_t *tx)
{
	dmu_buf_t *db;
	nvlist_t *nvl;
	nvlist_t **nvl_arr;
	cos_t *cos;
	char *buf;
	size_t bufsize = 0;
	size_t packedsize = 0;
	uint_t nvl_arr_sz;
	size_t num_classes = 0;
	int i;

	if (list_is_empty(&spa->spa_cos_list))
		goto empty;

	(void) spa_foreach_cos(spa, cos_count, &num_classes);
	nvl_arr_sz = num_classes * sizeof (void *);

	nvl_arr = kmem_alloc(nvl_arr_sz, KM_SLEEP);

	VERIFY(0 == nvlist_alloc(&nvl, NV_UNIQUE_NAME, KM_SLEEP));

	for (i = 0, cos = list_head(&spa->spa_cos_list); cos != NULL;
	    cos = list_next(&spa->spa_cos_list, cos), i++) {
		const char *propname;

		VERIFY(0 == nvlist_alloc(&nvl_arr[i], NV_UNIQUE_NAME,
		    KM_SLEEP));

		propname = cos_prop_to_name(COS_PROP_GUID);
		VERIFY(0 == nvlist_add_uint64(nvl_arr[i], propname,
		    cos->cos_guid));
		propname = cos_prop_to_name(COS_PROP_NAME);
		VERIFY(0 == nvlist_add_string(nvl_arr[i], propname,
		    cos->cos_name));
		propname = cos_prop_to_name(COS_PROP_PREFERRED_READ);
		VERIFY(0 == nvlist_add_uint64(nvl_arr[i], propname,
		    cos->cos_preferred_read));

		for (zio_priority_t p = ZIO_PRIORITY_SYNC_READ;
		    p < ZIO_PRIORITY_NUM_QUEUEABLE; p++) {
			uint64_t val = cos->cos_min_active[p];
			int prop_id = COS_ZIO_PRIO_TO_PROP_MIN(p);

			ASSERT(COS_PROP_MIN_VALID(prop_id));
			propname = cos_prop_to_name(prop_id);
			VERIFY(0 == nvlist_add_uint64(nvl_arr[i],
			    propname, val));

			val = cos->cos_max_active[p];
			prop_id = COS_ZIO_PRIO_TO_PROP_MAX(p);
			ASSERT(COS_PROP_MAX_VALID(prop_id));
			propname = cos_prop_to_name(prop_id);

			VERIFY(0 == nvlist_add_uint64(nvl_arr[i],
			    propname, val));
		}
	}

	VERIFY(0 == nvlist_add_nvlist_array(nvl, COS_ARRAY,
	    nvl_arr, num_classes));
	VERIFY(0 == nvlist_size(nvl, &packedsize, NV_ENCODE_XDR));

	bufsize = P2ROUNDUP((uint64_t)packedsize, SPA_MINBLOCKSIZE);
	buf = kmem_alloc(bufsize, KM_SLEEP);

	bzero(buf + packedsize, bufsize - packedsize);

	VERIFY(0 == nvlist_pack(nvl, &buf, &packedsize, NV_ENCODE_XDR,
	    KM_SLEEP));

	dmu_write(spa->spa_meta_objset, obj, 0, bufsize, buf, tx);

	kmem_free(buf, bufsize);
	for (i = 0; i < num_classes; i++)
		nvlist_free(nvl_arr[i]);
	kmem_free(nvl_arr, nvl_arr_sz);
	nvlist_free(nvl);

empty:
	VERIFY(0 == dmu_bonus_hold(spa->spa_meta_objset, obj, FTAG, &db));
	dmu_buf_will_dirty(db, tx);
	*(uint64_t *)db->db_data = (uint64_t)packedsize;
	dmu_buf_rele(db, FTAG);
}

typedef enum {
	COS_FEATURE_NONE,
	COS_FEATURE_INCR,
	COS_FEATURE_DECR
} cos_feature_action_t;

typedef struct {
	spa_t *spa;
	cos_feature_action_t action;
} cos_sync_arg_t;

static void
cos_sync_props(void *arg1, dmu_tx_t *tx)
{
	cos_sync_arg_t *arg = (cos_sync_arg_t *)arg1;
	spa_t *spa = arg->spa;
	objset_t *mos = arg->spa->spa_meta_objset;

	switch (arg->action) {
	case COS_FEATURE_INCR:
		spa_feature_incr(spa, SPA_FEATURE_COS_PROPS, tx);
		break;
	case COS_FEATURE_DECR:
		spa_feature_decr(spa, SPA_FEATURE_COS_PROPS, tx);
		break;
	case COS_FEATURE_NONE:
	default:
		break;
	}

	spa_cos_enter(spa);

	if (spa->spa_cos_props_object == 0) {
		VERIFY((spa->spa_cos_props_object =
		    dmu_object_alloc(mos, DMU_OT_PACKED_NVLIST, 0,
		    DMU_OT_PACKED_NVLIST_SIZE, 8, tx)) > 0);

		VERIFY(zap_update(mos,
		    DMU_POOL_DIRECTORY_OBJECT,
		    DMU_POOL_COS_PROPS,
		    8, 1, &spa->spa_cos_props_object, tx) == 0);
	}
	cos_sync_classes(spa, spa->spa_cos_props_object, tx);

	spa_cos_exit(spa);

	/* done with the argument */
	kmem_free(arg, sizeof (cos_sync_arg_t));
}

int
spa_load_cos_props(spa_t *spa)
{
	objset_t *mos = spa->spa_meta_objset;
	dmu_buf_t *db;
	nvlist_t *nvl = NULL;
	nvlist_t **nvl_arr;
	uint64_t packedsize;
	void *buf = NULL;
	uint_t n;
	int i;

	if (spa->spa_cos_props_object == 0)
		return (SET_ERROR(ENOENT));

	spa_cos_enter(spa);

	VERIFY(0 == dmu_bonus_hold(mos, spa->spa_cos_props_object, FTAG, &db));
	packedsize = *(uint64_t *)db->db_data;
	dmu_buf_rele(db, FTAG);

	if (packedsize == 0) {
		spa_cos_exit(spa);
		return (0);
	}

	buf = kmem_alloc(packedsize, KM_SLEEP);

	VERIFY(0 == dmu_read(mos, spa->spa_cos_props_object,
	    0, packedsize, buf, DMU_READ_NO_PREFETCH));

	VERIFY(0 == nvlist_unpack(buf, packedsize, &nvl, 0));
	VERIFY(0 == nvlist_lookup_nvlist_array(nvl, COS_ARRAY,
	    &nvl_arr, &n));

	for (i = 0; i < n; i++) {
		cos_t *cos = NULL;
		char *strval;
		uint64_t u64;
		const char *propname;

		propname = cos_prop_to_name(COS_PROP_GUID);
		if (nvlist_lookup_uint64(nvl_arr[i], propname, &u64) == 0) {
			cos = spa_lookup_cos_by_guid(spa, u64);
			if (cos == NULL) {
				propname = cos_prop_to_name(COS_PROP_NAME);
				if (nvlist_lookup_string(nvl_arr[i], propname,
				    &strval) != 0)
					continue;

				if (spa_alloc_cos_nosync(spa, strval, u64) != 0)
					continue;
				cos =  spa_lookup_cos_by_name(spa, strval);
			}
		}

		if (cos == NULL)
			continue;

		propname = cos_prop_to_name(COS_PROP_PREFERRED_READ);
		if (nvlist_lookup_uint64(nvl_arr[i], propname, &u64) == 0)
			cos->cos_preferred_read = u64;


		for (zio_priority_t p = ZIO_PRIORITY_SYNC_READ;
		    p < ZIO_PRIORITY_NUM_QUEUEABLE; p++) {
			int prop_id = COS_ZIO_PRIO_TO_PROP_MIN(p);
			const char *pname;

			ASSERT(COS_PROP_MIN_VALID(prop_id));
			pname = cos_prop_to_name(prop_id);

			if (nvlist_lookup_uint64(nvl_arr[i], pname, &u64) == 0)
				cos->cos_min_active[p] = u64;

			prop_id = COS_ZIO_PRIO_TO_PROP_MAX(p);
			ASSERT(COS_PROP_MAX_VALID(prop_id));
			pname = cos_prop_to_name(prop_id);

			if (nvlist_lookup_uint64(nvl_arr[i], pname, &u64) == 0)
				cos->cos_max_active[p] = u64;
		}
	}

	spa_cos_exit(spa);

	nvlist_free(nvl);
	kmem_free(buf, packedsize);

	return (0);
}

int
cos_prop_validate(spa_t *spa, uint64_t id, nvlist_t *props)
{
	nvpair_t *elem;
	int error = 0;

	elem = NULL;
	while ((elem = nvlist_next_nvpair(props, elem)) != NULL) {
		cos_prop_t prop;
		char *propname;
		char *strval;
		uint64_t intval;
		cos_t *cos;

		propname = nvpair_name(elem);

		if ((prop = cos_name_to_prop(propname)) == ZPROP_INVAL)
			return (SET_ERROR(EINVAL));

		switch (prop) {
		case COS_PROP_NAME:
			error = nvpair_value_string(elem, &strval);
			if (error)
				break;

			/*
			 * Cannot exceed max length of cos name
			 * and cannot be same as existing one
			 */
			if ((strnlen(strval, MAXCOSNAMELEN) == MAXCOSNAMELEN) ||
			    (((cos = spa_lookup_cos_by_name(spa, strval)) !=
			    NULL) && cos->cos_guid != id))
				error = EINVAL;
			break;
		case COS_PROP_PREFERRED_READ:
			error = nvpair_value_uint64(elem, &intval);
			if (!error && intval > 100)
				error = EINVAL;
			break;

		case COS_PROP_READ_MINACTIVE:
		case COS_PROP_AREAD_MINACTIVE:
		case COS_PROP_WRITE_MINACTIVE:
		case COS_PROP_AWRITE_MINACTIVE:
		case COS_PROP_SCRUB_MINACTIVE:
		case COS_PROP_RESILVER_MINACTIVE:
		case COS_PROP_READ_MAXACTIVE:
		case COS_PROP_AREAD_MAXACTIVE:
		case COS_PROP_WRITE_MAXACTIVE:
		case COS_PROP_AWRITE_MAXACTIVE:
		case COS_PROP_SCRUB_MAXACTIVE:
		case COS_PROP_RESILVER_MAXACTIVE:
			error = nvpair_value_uint64(elem, &intval);
			if (!error && intval > 1000)
				error = EINVAL;
			break;

		default:
			error = EINVAL;
		}

		if (error)
			break;
	}

	return (error);
}

/* ARGSUSED */
int
cos_sync_task_do(spa_t *spa, cos_feature_action_t action)
{
	int err = 0;
	cos_sync_arg_t *arg = kmem_alloc(sizeof (cos_sync_arg_t), KM_SLEEP);
	/* argument allocated and initialized here and freed in the callback */
	arg->spa = spa;
	arg->action = action;
	err = dsl_sync_task(spa->spa_name, NULL, cos_sync_props, arg, 3,
	    ZFS_SPACE_CHECK_RESERVED);
	return (err);
}

int
spa_cos_prop_set(spa_t *spa, const char *cosname, nvlist_t *nvp)
{
	cos_t *cos;
	nvpair_t *elem;
	boolean_t need_sync = B_FALSE;
	cos_prop_t prop;
	uint64_t intval;
	char *strval;
	zprop_type_t proptype;

	ASSERT(spa_writeable(spa));

	spa_cos_enter(spa);
	cos = spa_lookup_cos_by_name(spa, cosname);
	if (cos == NULL) {
		spa_cos_exit(spa);
		return (ENOENT);
	}

	elem = NULL;
	while ((elem = nvlist_next_nvpair(nvp, elem)) != NULL) {
		if ((prop = cos_name_to_prop(
		    nvpair_name(elem))) == ZPROP_INVAL)
			return (EINVAL);

		need_sync = B_TRUE;
		proptype = cos_prop_get_type(prop);

		if (nvpair_type(elem) == DATA_TYPE_STRING) {
			ASSERT(proptype == PROP_TYPE_STRING);
			VERIFY(nvpair_value_string(elem, &strval) == 0);

		} else if (nvpair_type(elem) == DATA_TYPE_UINT64) {
			VERIFY(nvpair_value_uint64(elem, &intval) == 0);

			if (proptype == PROP_TYPE_INDEX) {
				const char *unused;
				VERIFY(cos_prop_index_to_string(
				    prop, intval, &unused) == 0);
			}
		} else {
			ASSERT(0); /* not allowed */
		}

		(void) cos_set_common(cos, strval, intval, prop);
	}
	spa_cos_exit(spa);

	if (need_sync)
		return (cos_sync_task_do(spa, COS_FEATURE_NONE));
	return (0);
}

int
spa_cos_prop_get(spa_t *spa, const char *cosname, nvlist_t **nvp)
{
	cos_t *cos;
	int err;
	cos_prop_t prop;

	VERIFY(nvlist_alloc(nvp, NV_UNIQUE_NAME, KM_SLEEP) == 0);

	spa_cos_enter(spa);
	cos = spa_lookup_cos_by_name(spa, cosname);
	if (cos == NULL) {
		spa_cos_exit(spa);
		return (ENOENT);
	}

	for (prop = COS_PROP_GUID; prop < COS_NUM_PROPS; prop++) {
		uint64_t ival;
		char *strval = NULL;
		const char *propname = cos_prop_to_name(prop);

		if ((err = cos_get_common(cos, &strval, &ival, prop)) != 0)
			return (err);

		if (strval != NULL) {
			VERIFY(nvlist_add_string(*nvp, propname, strval) == 0);
			spa_strfree(strval);
		} else {
			VERIFY(nvlist_add_uint64(*nvp, propname, ival) == 0);
		}
	}
	spa_cos_exit(spa);

	return (0);
}

static uint64_t
generate_cos_guid(spa_t *spa)
{
	uint64_t guid = 0;

	do {
		(void) random_get_pseudo_bytes((uint8_t *)&guid, sizeof (guid));
	} while (guid != 0 && spa_lookup_cos_by_guid(spa, guid) != NULL);

	return (guid);
}

static int
spa_alloc_cos_nosync(spa_t *spa, const char *cosname, uint64_t cosguid)
{
	cos_t *cos;

	ASSERT(MUTEX_HELD(&spa->spa_cos_props_lock));

	cos = kmem_zalloc(sizeof (cos_t), KM_SLEEP);

	if (spa_lookup_cos_by_name(spa, cosname) != NULL)
		return (EEXIST);

	cos->cos_guid = (cosguid != 0 ? cosguid : generate_cos_guid(spa));
	if (cos->cos_guid == 0)
		return (ENOSPC);

	cos->cos_spa = spa;
	(void) strlcpy(cos->cos_name, cosname, MAXCOSNAMELEN);

	list_insert_tail(&spa->spa_cos_list, cos);

	return (0);
}

/*
 * Note: CoS objects are allocated and freed explicitly. Allocated CoS objects
 * are placed on the list in the pool, and once they are freed, they are no
 * longer on the list. As such, they may or may not be referenced by vdevs while
 * allocated. The reference counting is desined to make sure that CoS objects
 * that are referenced by some vdevs are not de-allocated.
 */

int
spa_alloc_cos(spa_t *spa, const char *cosname, uint64_t cosid)
{
	int err;

	if (!spa_feature_is_enabled(spa, SPA_FEATURE_COS_PROPS))
		return (ENOTSUP);

	spa_cos_enter(spa);
	err = spa_alloc_cos_nosync(spa, cosname, cosid);
	spa_cos_exit(spa);
	if (err)
		return (err);

	return (cos_sync_task_do(spa, COS_FEATURE_INCR));
}


/* force cos_free() implementation */
typedef void (*cos_free_cb_t)(vdev_t *, void *);

static void
cos_free_cb(vdev_t *vd, void *arg)
{
	cos_t *cos = (cos_t *)arg;

	ASSERT(MUTEX_HELD(&cos->cos_spa->spa_cos_props_lock));
	ASSERT(spa_config_held(cos->cos_spa, SCL_STATE_ALL,
	    RW_WRITER) == SCL_STATE_ALL);

	if (!vd->vdev_ops->vdev_op_leaf)
		return;

	if (vd->vdev_queue.vq_cos == cos) {
		cos_rele(cos);
		vd->vdev_queue.vq_cos = NULL;
	}
}

static void
cos_vdev_walk(vdev_t *vd, cos_free_cb_t cb, void *arg)
{
	for (int i = 0; i < vd->vdev_children; i++)
		cos_vdev_walk(vd->vdev_child[i], cb, arg);
	cb(vd, arg);
}

int
spa_free_cos(spa_t *spa, const char *cosname, boolean_t b_force)
{
	int err = 0;
	cos_t *cos;

	if (b_force)
		spa_vdev_state_enter(spa, SCL_ALL);

	spa_cos_enter(spa);

	if ((cos = spa_lookup_cos_by_name(spa, cosname)) != NULL) {
		if (cos_refcount(cos) == 0) {
			list_remove(&spa->spa_cos_list, cos);
		} else {
			if (b_force == B_TRUE) {
				int i;
				/*
				 * walk the device tree and the aux devices,
				 * check cos and remove as needed
				 */
				cos_vdev_walk(spa->spa_root_vdev, cos_free_cb,
				    (void *)cos);
				for (i = 0; i < spa->spa_l2cache.sav_count;
				    i++) {
					vdev_t *vd =
					    spa->spa_l2cache.sav_vdevs[i];
					cos_free_cb(vd, (void *)cos);
				}
				for (i = 0; i < spa->spa_spares.sav_count;
				    i++) {
					vdev_t *vd =
					    spa->spa_spares.sav_vdevs[i];
					cos_free_cb(vd, (void *)cos);
				}
				list_remove(&spa->spa_cos_list, cos);
			} else {
				err = SET_ERROR(EBUSY);
			}
		}
	} else {
		err = ENOENT;
	}

	spa_cos_exit(spa);

	if (b_force)
		(void) spa_vdev_state_exit(spa, NULL, 0);

	if (err == 0) {
		kmem_free(cos, sizeof (cos_t));
		if (b_force)
			return (spa_vdev_props_sync_task_do(spa) &&
			    cos_sync_task_do(spa, COS_FEATURE_DECR));
		else
			return (cos_sync_task_do(spa, COS_FEATURE_DECR));
	}

	return (err);
}

int
spa_list_cos(spa_t *spa, nvlist_t *nvl)
{
	cos_t *cos;
	int err = 0;

	spa_cos_enter(spa);
	for (cos = list_head(&spa->spa_cos_list); cos != NULL;
	    cos = list_next(&spa->spa_cos_list, cos)) {
		VERIFY(nvlist_add_uint64(nvl, cos->cos_name,
			cos->cos_guid) == 0);
	}
	spa_cos_exit(spa);

	return (err);
}

void
spa_cos_init(spa_t *spa)
{
	spa_cos_enter(spa);
	list_create(&spa->spa_cos_list, sizeof (cos_t), offsetof(cos_t,
	    cos_list_node));
	spa_cos_exit(spa);
}

/* ARGSUSED */
static boolean_t
cos_remove(cos_t *cos, void *data)
{
	spa_t *spa = cos->cos_spa;

	ASSERT(MUTEX_HELD(&spa->spa_cos_props_lock));

	list_remove(&spa->spa_cos_list, cos);
	kmem_free(cos, sizeof (cos_t));

	return (B_FALSE);
}

void
spa_cos_fini(spa_t *spa)
{
	spa_cos_enter(spa);
	(void) spa_foreach_cos(spa, cos_remove, NULL);
	list_destroy(&spa->spa_cos_list);
	spa_cos_exit(spa);
}

uint64_t
cos_get_prop_uint64(cos_t *cos, cos_prop_t p)
{
	uint64_t val = 0;
	zio_priority_t zprio = 0;

	switch (p) {
	case COS_PROP_READ_MINACTIVE:
	case COS_PROP_AREAD_MINACTIVE:
	case COS_PROP_WRITE_MINACTIVE:
	case COS_PROP_AWRITE_MINACTIVE:
	case COS_PROP_SCRUB_MINACTIVE:
	case COS_PROP_RESILVER_MINACTIVE:
		zprio = COS_PROP_TO_ZIO_PRIO_MIN(p);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(zprio));
		val = cos->cos_min_active[zprio];
		break;
	case COS_PROP_READ_MAXACTIVE:
	case COS_PROP_AREAD_MAXACTIVE:
	case COS_PROP_WRITE_MAXACTIVE:
	case COS_PROP_AWRITE_MAXACTIVE:
	case COS_PROP_SCRUB_MAXACTIVE:
	case COS_PROP_RESILVER_MAXACTIVE:
		zprio = COS_PROP_TO_ZIO_PRIO_MAX(p);
		ASSERT(ZIO_PRIORITY_QUEUEABLE_VALID(zprio));
		val = cos->cos_max_active[zprio];
		break;
	case COS_PROP_PREFERRED_READ:
		val = cos->cos_preferred_read;
		break;
	default:
		panic("Non-numeric property requested\n");
		return (0);
	}

	return (val);
}
