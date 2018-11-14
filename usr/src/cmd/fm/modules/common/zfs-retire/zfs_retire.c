/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2006, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright 2017 Nexenta Systems, Inc.
 */

/*
 * The ZFS retire agent is responsible for managing hot spares across all pools.
 * When we see a device fault or a device removal, we try to open the associated
 * pool and look for any hot spares.  We iterate over any available hot spares
 * and attempt a 'zpool replace' for each one.
 *
 * For vdevs diagnosed as faulty, the agent is also responsible for proactively
 * marking the vdev FAULTY (for I/O errors) or DEGRADED (for checksum errors).
 */

#include <fm/fmd_api.h>
#include <sys/fs/zfs.h>
#include <sys/fm/protocol.h>
#include <sys/fm/fs/zfs.h>
#include <libzfs.h>
#include <fm/libtopo.h>
#include <string.h>
#include <sys/int_fmtio.h>
#include <devid.h>

typedef struct zfs_retire_repaired {
	struct zfs_retire_repaired	*zrr_next;
	uint64_t			zrr_pool;
	uint64_t			zrr_vdev;
} zfs_retire_repaired_t;

typedef struct zfs_retire_data {
	libzfs_handle_t			*zrd_hdl;
	zfs_retire_repaired_t		*zrd_repaired;
} zfs_retire_data_t;

static void
zfs_retire_clear_data(fmd_hdl_t *hdl, zfs_retire_data_t *zdp)
{
	zfs_retire_repaired_t *zrp;

	while ((zrp = zdp->zrd_repaired) != NULL) {
		zdp->zrd_repaired = zrp->zrr_next;
		fmd_hdl_free(hdl, zrp, sizeof (zfs_retire_repaired_t));
	}
}

/*
 * Find a pool with a matching GUID.
 */
typedef struct find_cbdata {
	fmd_hdl_t	*cb_hdl;
	uint64_t	cb_guid;
	const char	*cb_fru;
	ddi_devid_t	cb_devid;
	zpool_handle_t	*cb_zhp;
	nvlist_t	*cb_vdev;
} find_cbdata_t;

static int
find_pool(zpool_handle_t *zhp, void *data)
{
	find_cbdata_t *cbp = data;

	if (cbp->cb_guid ==
	    zpool_get_prop_int(zhp, ZPOOL_PROP_GUID, NULL)) {
		cbp->cb_zhp = zhp;
		return (1);
	}

	zpool_close(zhp);
	return (0);
}

/*
 * Find a vdev within a tree with a matching GUID.
 */
static nvlist_t *
find_vdev(fmd_hdl_t *hdl, libzfs_handle_t *zhdl, nvlist_t *nv,
    const char *search_fru, ddi_devid_t search_devid, uint64_t search_guid)
{
	uint64_t guid;
	nvlist_t **child;
	uint_t c, children;
	nvlist_t *ret;
	char *fru, *devidstr, *path;
	ddi_devid_t devid;

	if (nvlist_lookup_string(nv, ZPOOL_CONFIG_PATH, &path) == 0)
		fmd_hdl_debug(hdl, "find_vdev: vdev path: %s", path);

	if (search_fru != NULL &&
	    nvlist_lookup_string(nv, ZPOOL_CONFIG_FRU, &fru) == 0) {
		fmd_hdl_debug(hdl, "find_vdev: found fru: %s", fru);
		if (libzfs_fru_compare(zhdl, fru, search_fru))
			return (nv);
	}

	if (search_devid != NULL &&
	    nvlist_lookup_string(nv, ZPOOL_CONFIG_DEVID, &devidstr) == 0) {
		fmd_hdl_debug(hdl, "find_vdev: found devid: %s", devidstr);

		if (devid_str_decode(devidstr, &devid, NULL) == 0) {
			if (devid_compare(search_devid, devid) == 0) {
				devid_free(devid);
				return (nv);
			}

			devid_free(devid);
		}
	}

	if (nvlist_lookup_uint64(nv, ZPOOL_CONFIG_GUID, &guid) == 0 &&
	    guid == search_guid)
		return (nv);

	if (nvlist_lookup_nvlist_array(nv, ZPOOL_CONFIG_CHILDREN,
	    &child, &children) != 0)
		return (NULL);

	for (c = 0; c < children; c++) {
		if ((ret = find_vdev(hdl, zhdl, child[c], search_fru,
		    search_devid, search_guid)) != NULL)
			return (ret);
	}

	if (nvlist_lookup_nvlist_array(nv, ZPOOL_CONFIG_L2CACHE,
	    &child, &children) != 0)
		return (NULL);

	for (c = 0; c < children; c++) {
		if ((ret = find_vdev(hdl, zhdl, child[c], search_fru,
		    search_devid, search_guid)) != NULL)
			return (ret);
	}

	return (NULL);
}

/*
 * Given a (pool, vdev) GUID pair, find the matching pool and vdev.
 */
static zpool_handle_t *
find_by_guid(fmd_hdl_t *hdl, libzfs_handle_t *zhdl, uint64_t pool_guid,
    uint64_t vdev_guid, nvlist_t **vdevp)
{
	find_cbdata_t cb;
	zpool_handle_t *zhp;
	nvlist_t *config, *nvroot;

	/*
	 * Find the corresponding pool and make sure the vdev still exists.
	 */
	cb.cb_guid = pool_guid;
	if (zpool_iter(zhdl, find_pool, &cb) != 1)
		return (NULL);

	zhp = cb.cb_zhp;
	config = zpool_get_config(zhp, NULL);
	if (nvlist_lookup_nvlist(config, ZPOOL_CONFIG_VDEV_TREE,
	    &nvroot) != 0) {
		zpool_close(zhp);
		return (NULL);
	}

	if (vdev_guid != 0) {
		if ((*vdevp = find_vdev(hdl, zhdl, nvroot, NULL, NULL,
		    vdev_guid)) == NULL) {
			zpool_close(zhp);
			return (NULL);
		}
	}

	return (zhp);
}

static int
search_pool(zpool_handle_t *zhp, void *data)
{
	find_cbdata_t *cbp = data;
	nvlist_t *config;
	nvlist_t *nvroot;

	config = zpool_get_config(zhp, NULL);
	if (nvlist_lookup_nvlist(config, ZPOOL_CONFIG_VDEV_TREE,
	    &nvroot) != 0) {
		zpool_close(zhp);
		fmd_hdl_debug(cbp->cb_hdl, "search_pool: "
		    "unable to get vdev tree");
		return (0);
	}

	if ((cbp->cb_vdev = find_vdev(cbp->cb_hdl, zpool_get_handle(zhp),
	    nvroot, cbp->cb_fru, cbp->cb_devid, cbp->cb_guid)) != NULL) {
		cbp->cb_zhp = zhp;
		return (1);
	}

	zpool_close(zhp);
	return (0);
}

/*
 * Given a FRU FMRI, devid, or guid: find the matching pool and vdev.
 */
static zpool_handle_t *
find_by_anything(fmd_hdl_t *hdl, libzfs_handle_t *zhdl, const char *fru,
    ddi_devid_t devid, uint64_t guid, nvlist_t **vdevp)
{
	find_cbdata_t cb;

	(void) memset(&cb, 0, sizeof (cb));
	cb.cb_hdl = hdl;
	cb.cb_fru = fru;
	cb.cb_devid = devid;
	cb.cb_guid = guid;
	cb.cb_zhp = NULL;

	if (zpool_iter(zhdl, search_pool, &cb) != 1)
		return (NULL);

	*vdevp = cb.cb_vdev;
	return (cb.cb_zhp);
}

/*
 * Create a solved FMD case and add the fault to it
 */
static void
generate_fault(fmd_hdl_t *hdl, nvlist_t *vdev, char *faultname)
{
	char *devid, *fdevid, *physpath, *s;
	fmd_case_t *c;
	fmd_hdl_topo_node_info_t *node;
	nvlist_t *fault = NULL;
	uint64_t wd;

	assert(hdl != NULL);
	assert(vdev != NULL);
	assert(faultname != NULL);

	if (nvlist_lookup_string(vdev, ZPOOL_CONFIG_PHYS_PATH,
	    &physpath) != 0 ||
	    nvlist_lookup_uint64(vdev, ZPOOL_CONFIG_WHOLE_DISK, &wd) != 0)
		return;

	if (nvlist_lookup_string(vdev, ZPOOL_CONFIG_DEVID,
	    &devid) == 0) {
		fdevid = strdup(devid);
	} else {
		fdevid = devid_str_from_path(physpath);
	}
	if (fdevid == NULL) {
		fmd_hdl_debug(hdl, "%s: failed to get devid", __func__);
		return;
	}

	if (wd && (s = strrchr(fdevid, '/')) != NULL)
		*s = '\0';

	c = fmd_case_open(hdl, NULL);
	if ((node = fmd_hdl_topo_node_get_by_devid(hdl, fdevid)) == NULL) {
		fault = fmd_nvl_create_fault(hdl, faultname, 100, NULL, vdev,
		    NULL);
	} else {
		fault = fmd_nvl_create_fault(hdl, faultname, 100,
		    node->resource, node->fru, node->resource);
		nvlist_free(node->fru);
		nvlist_free(node->resource);
		fmd_hdl_free(hdl, node,
		    sizeof (fmd_hdl_topo_node_info_t));
	}
	fmd_case_add_suspect(hdl, c, fault);
	fmd_case_setspecific(hdl, c, fdevid);
	fmd_case_solve(hdl, c);

	devid_str_free(fdevid);
	fmd_hdl_debug(hdl, "%s: dispatched %s", __func__, faultname);
}

/*
 * Determine if the FRU fields for the spare and the failed device match.
 */
static boolean_t
match_fru(fmd_hdl_t *hdl, char *ffru, nvlist_t *spare)
{
	char *sfru;
	boolean_t ret = B_FALSE;

	if (nvlist_lookup_string(spare, ZPOOL_CONFIG_FRU, &sfru) != 0) {
		fmd_hdl_debug(hdl, "%s: spare FRU not set", __func__);
		return (B_FALSE);
	}

	/* We match on enclosure only at the moment */
	ret = libzfs_fru_cmp_enclosure(ffru, sfru);
	if (!ret)
		fmd_hdl_debug(hdl, "%s: enclosure not matched", __func__);

	return (ret);
}

static boolean_t
do_replace(zpool_handle_t *zhp, const char *fpath, const char *spath,
    nvlist_t *spare)
{
	nvlist_t *nvroot;
	boolean_t ret = B_FALSE;

	if (nvlist_alloc(&nvroot, NV_UNIQUE_NAME, 0) != 0)
		return (B_FALSE);

	if (nvlist_add_string(nvroot, ZPOOL_CONFIG_TYPE, VDEV_TYPE_ROOT) != 0 ||
	    nvlist_add_nvlist_array(nvroot, ZPOOL_CONFIG_CHILDREN,
	    &spare, 1) != 0)
		goto fail;

	ret = (zpool_vdev_attach(zhp, fpath, spath, nvroot, B_TRUE) == 0);

fail:
	nvlist_free(nvroot);
	return (ret);
}

/*
 * Attempt to replace failed device with spare.
 *
 * Spare selection is done in the following order:
 * - If failed device has sparegroup property set, look for the spares that
 *   belongs to the same sparegroup. If no suitable spare is found, skip
 *   the spares that have sparegroup property set while doing other match types.
 * - If failed device has FRU set, look for the spares in the same enclosure.
 * - Finally, try using any available spare.
 *
 * Note that all match types do a media-type match first, so that we don't
 * replace HDD with SSD and vice versa.
 */
static void
replace_with_spare(fmd_hdl_t *hdl, zpool_handle_t *zhp, nvlist_t *vdev)
{
	nvlist_t *config, *nvroot, **spares;
	uint_t i, nspares;
	boolean_t uu1, uu2, log;
	char *devpath;
	char fdevpath[PATH_MAX];	/* devpath of failed device */
	char *ffru = NULL;		/* FRU of failed device */
	char fsg[MAXNAMELEN];		/* sparegroup of failed device */
	boolean_t use_sg = B_FALSE;	/* do sparegroup matching */
	boolean_t done_sg = B_FALSE;	/* done sparegroup matching */
	boolean_t use_fru = B_FALSE;	/* do FRU matching */
	boolean_t done_fru = B_FALSE;	/* done FRU matching */
	boolean_t fssd = B_FALSE;	/* failed device is SSD */
	uint64_t wd;

	if ((config = zpool_get_config(zhp, NULL)) == NULL ||
	    nvlist_lookup_nvlist(config, ZPOOL_CONFIG_VDEV_TREE, &nvroot) != 0)
		return;

	/* Check if there are any hot spares available in the pool */
	if (nvlist_lookup_nvlist_array(nvroot, ZPOOL_CONFIG_SPARES, &spares,
	    &nspares) != 0) {
		fmd_hdl_debug(hdl, "%s: no spares found", __func__);
		return;
	}

	if (nvlist_lookup_string(vdev, ZPOOL_CONFIG_PATH, &devpath) != 0 ||
	    nvlist_lookup_uint64(vdev, ZPOOL_CONFIG_WHOLE_DISK, &wd) != 0 ||
	    nvlist_lookup_boolean_value(vdev, ZPOOL_CONFIG_IS_SSD, &fssd) != 0)
		return;
	(void) strlcpy(fdevpath, devpath, sizeof (fdevpath));
	if (wd)
		fdevpath[strlen(fdevpath) - 2] = '\0';

	/* Spares can't replace log devices */
	(void) zpool_find_vdev(zhp, fdevpath, &uu1, &uu2, &log, NULL);
	if (log)
		return;

	/* Check if we should do sparegroup matching */
	if (vdev_get_prop(zhp, fdevpath, VDEV_PROP_SPAREGROUP, fsg,
	    sizeof (fsg)) == 0 && strcmp(fsg, "-") != 0)
		use_sg = B_TRUE;

	use_fru = (fmd_prop_get_int32(hdl, "fru_compare") == FMD_B_TRUE);
	/* Disable FRU matching if failed device doesn't have FRU set */
	if (nvlist_lookup_string(vdev, ZPOOL_CONFIG_FRU, &ffru) != 0)
		use_fru = B_FALSE;

again:
	/* Go through the spares list */
	for (i = 0; i < nspares; i++) {
		char sdevpath[PATH_MAX];	/* devpath of spare */
		char ssg[MAXNAMELEN];		/* sparegroup of spare */
		boolean_t sssd = B_FALSE;	/* spare is SSD */
		boolean_t ssg_set = B_FALSE;

		if (nvlist_lookup_string(spares[i], ZPOOL_CONFIG_PATH,
		    &devpath) != 0 ||
		    nvlist_lookup_uint64(spares[i], ZPOOL_CONFIG_WHOLE_DISK,
		    &wd) != 0)
			continue;

		(void) strlcpy(sdevpath, devpath, sizeof (sdevpath));
		if (wd)
			sdevpath[strlen(sdevpath) - 2] = '\0';

		/* Don't swap HDD for SSD and vice versa */
		if (nvlist_lookup_boolean_value(spares[i], ZPOOL_CONFIG_IS_SSD,
		    &sssd) != 0 || fssd != sssd) {
			continue;
		}

		/* Get the sparegroup property for the spare */
		if (vdev_get_prop(zhp, sdevpath, VDEV_PROP_SPAREGROUP, ssg,
		    sizeof (ssg)) == 0 && strcmp(ssg, "-") != 0)
			ssg_set = B_TRUE;

		if (use_sg) {
			if (!ssg_set || strcmp(fsg, ssg) != 0)
				continue;
			/* Found spare in the the same group */
			if (do_replace(zhp, fdevpath, sdevpath, spares[i]))
				return;
			continue;
		}

		/*
		 * If we tried matching on sparegroup and have not found
		 * any suitable spare, skip all spares with sparegroup
		 * set.
		 */
		if (done_sg && ssg_set)
			continue;

		if (use_fru) {
			if (!match_fru(hdl, ffru, spares[i]))
				continue;
			/* Found spare with matching FRU */
			if (do_replace(zhp, fdevpath, sdevpath, spares[i]))
				return;
			continue;
		}

		/*
		 * sparegroup and FRU matching was either not used or didn't
		 * find any suitable spares, use the first available one.
		 */
		if (do_replace(zhp, fdevpath, sdevpath, spares[i])) {
			/* If we tried intellegent sparing, generate fault */
			if (done_sg || done_fru) {
				generate_fault(hdl, vdev,
				    "fault.fs.zfs.vdev.dumb_spared");
			}
			return;
		}
	}

	if (use_sg) {
		done_sg = B_TRUE;
		use_sg = B_FALSE;
		goto again;
	} else if (use_fru) {
		done_fru = B_TRUE;
		use_fru = B_FALSE;
		goto again;
	}

	generate_fault(hdl, vdev, "fault.fs.zfs.vdev.not_spared");
}

/*
 * Repair this vdev if we had diagnosed a 'fault.fs.zfs.device' and
 * ASRU is now usable.  ZFS has found the device to be present and
 * functioning.
 */
/*ARGSUSED*/
void
zfs_vdev_repair(fmd_hdl_t *hdl, nvlist_t *nvl)
{
	zfs_retire_data_t *zdp = fmd_hdl_getspecific(hdl);
	zfs_retire_repaired_t *zrp;
	uint64_t pool_guid, vdev_guid;
	nvlist_t *asru;

	if (nvlist_lookup_uint64(nvl, FM_EREPORT_PAYLOAD_ZFS_POOL_GUID,
	    &pool_guid) != 0 || nvlist_lookup_uint64(nvl,
	    FM_EREPORT_PAYLOAD_ZFS_VDEV_GUID, &vdev_guid) != 0)
		return;

	/*
	 * Before checking the state of the ASRU, go through and see if we've
	 * already made an attempt to repair this ASRU.  This list is cleared
	 * whenever we receive any kind of list event, and is designed to
	 * prevent us from generating a feedback loop when we attempt repairs
	 * against a faulted pool.  The problem is that checking the unusable
	 * state of the ASRU can involve opening the pool, which can post
	 * statechange events but otherwise leave the pool in the faulted
	 * state.  This list allows us to detect when a statechange event is
	 * due to our own request.
	 */
	for (zrp = zdp->zrd_repaired; zrp != NULL; zrp = zrp->zrr_next) {
		if (zrp->zrr_pool == pool_guid &&
		    zrp->zrr_vdev == vdev_guid)
			return;
	}

	asru = fmd_nvl_alloc(hdl, FMD_SLEEP);

	(void) nvlist_add_uint8(asru, FM_VERSION, ZFS_SCHEME_VERSION0);
	(void) nvlist_add_string(asru, FM_FMRI_SCHEME, FM_FMRI_SCHEME_ZFS);
	(void) nvlist_add_uint64(asru, FM_FMRI_ZFS_POOL, pool_guid);
	(void) nvlist_add_uint64(asru, FM_FMRI_ZFS_VDEV, vdev_guid);

	/*
	 * We explicitly check for the unusable state here to make sure we
	 * aren't responding to a transient state change.  As part of opening a
	 * vdev, it's possible to see the 'statechange' event, only to be
	 * followed by a vdev failure later.  If we don't check the current
	 * state of the vdev (or pool) before marking it repaired, then we risk
	 * generating spurious repair events followed immediately by the same
	 * diagnosis.
	 *
	 * This assumes that the ZFS scheme code associated unusable (i.e.
	 * isolated) with its own definition of faulty state.  In the case of a
	 * DEGRADED leaf vdev (due to checksum errors), this is not the case.
	 * This works, however, because the transient state change is not
	 * posted in this case.  This could be made more explicit by not
	 * relying on the scheme's unusable callback and instead directly
	 * checking the vdev state, where we could correctly account for
	 * DEGRADED state.
	 */
	if (!fmd_nvl_fmri_unusable(hdl, asru) && fmd_nvl_fmri_has_fault(hdl,
	    asru, FMD_HAS_FAULT_ASRU, NULL)) {
		topo_hdl_t *thp;
		char *fmri = NULL;
		int err;

		thp = fmd_hdl_topo_hold(hdl, TOPO_VERSION);
		if (topo_fmri_nvl2str(thp, asru, &fmri, &err) == 0)
			(void) fmd_repair_asru(hdl, fmri);
		fmd_hdl_topo_rele(hdl, thp);

		topo_hdl_strfree(thp, fmri);
	}
	nvlist_free(asru);
	zrp = fmd_hdl_alloc(hdl, sizeof (zfs_retire_repaired_t), FMD_SLEEP);
	zrp->zrr_next = zdp->zrd_repaired;
	zrp->zrr_pool = pool_guid;
	zrp->zrr_vdev = vdev_guid;
	zdp->zrd_repaired = zrp;
}

static int
zfs_get_vdev_state(fmd_hdl_t *hdl, libzfs_handle_t *zhdl, zpool_handle_t *zhp,
    uint64_t vdev_guid, nvlist_t **vdev)
{
	nvlist_t *config, *nvroot;
	vdev_stat_t *vs;
	uint_t cnt;
	boolean_t missing;

	if (zpool_refresh_stats(zhp, &missing) != 0 ||
	    missing != B_FALSE) {
		fmd_hdl_debug(hdl, "zfs_get_vdev_state: can't refresh stats");
		return (VDEV_STATE_UNKNOWN);
	}

	config = zpool_get_config(zhp, NULL);
	if (nvlist_lookup_nvlist(config, ZPOOL_CONFIG_VDEV_TREE,
	    &nvroot) != 0) {
		fmd_hdl_debug(hdl, "zfs_get_vdev_state: can't get vdev tree");
		return (VDEV_STATE_UNKNOWN);
	}

	*vdev = find_vdev(hdl, zhdl, nvroot, NULL, NULL, vdev_guid);

	if (nvlist_lookup_uint64_array(*vdev, ZPOOL_CONFIG_VDEV_STATS,
	    (uint64_t **)&vs, &cnt) != 0) {
		fmd_hdl_debug(hdl, "zfs_get_vdev_state: can't get vdev stats");
		return (VDEV_STATE_UNKNOWN);
	}

	return (vs->vs_state);
}

int
zfs_retire_device(fmd_hdl_t *hdl, char *path, boolean_t retire)
{
	di_retire_t drt = {0};
	int err;

	drt.rt_abort = (void (*)(void *, const char *, ...))fmd_hdl_abort;
	drt.rt_debug = (void (*)(void *, const char *, ...))fmd_hdl_debug;
	drt.rt_hdl = hdl;

	fmd_hdl_debug(hdl, "zfs_retire_device: "
	    "attempting to %sretire %s", retire ? "" : "un", path);

	err = retire ?
	    di_retire_device(path, &drt, 0) :
	    di_unretire_device(path, &drt);

	if (err != 0)
		fmd_hdl_debug(hdl, "zfs_retire_device: ",
		    "di_%sretire_device failed: %d %s",
		    retire ? "" : "un", err, path);

	return (err);
}

/*ARGSUSED*/
static void
zfs_retire_recv(fmd_hdl_t *hdl, fmd_event_t *ep, nvlist_t *nvl,
    const char *class)
{
	uint64_t pool_guid, vdev_guid;
	zpool_handle_t *zhp;
	nvlist_t *resource, *fault, *fru, *asru;
	nvlist_t **faults;
	uint_t f, nfaults;
	zfs_retire_data_t *zdp = fmd_hdl_getspecific(hdl);
	libzfs_handle_t *zhdl = zdp->zrd_hdl;
	boolean_t fault_device, degrade_device;
	boolean_t is_repair;
	char *scheme = NULL, *fmri = NULL, *devidstr = NULL, *path = NULL;
	ddi_devid_t devid;
	nvlist_t *vdev;
	char *uuid;
	int repair_done = 0;
	boolean_t retire;
	boolean_t is_disk;
	boolean_t retire_device = B_FALSE;
	vdev_aux_t aux;
	topo_hdl_t *thp = NULL;
	int err;

	/*
	 * If this is a resource notifying us of device removal, then simply
	 * check for an available spare and continue.
	 */
	if (strcmp(class, "resource.fs.zfs.removed") == 0) {
		if (nvlist_lookup_uint64(nvl, FM_EREPORT_PAYLOAD_ZFS_POOL_GUID,
		    &pool_guid) != 0 ||
		    nvlist_lookup_uint64(nvl, FM_EREPORT_PAYLOAD_ZFS_VDEV_GUID,
		    &vdev_guid) != 0)
			return;

		if ((zhp = find_by_guid(hdl, zhdl, pool_guid, vdev_guid,
		    &vdev)) == NULL)
			return;

		if (fmd_prop_get_int32(hdl, "spare_on_remove"))
			replace_with_spare(hdl, zhp, vdev);
		zpool_close(zhp);
		return;
	}

	if (strcmp(class, FM_LIST_RESOLVED_CLASS) == 0)
		return;

	if (strcmp(class, "resource.fs.zfs.statechange") == 0 ||
	    strcmp(class,
	    "resource.sysevent.EC_zfs.ESC_ZFS_vdev_remove") == 0) {
		zfs_vdev_repair(hdl, nvl);
		return;
	}

	zfs_retire_clear_data(hdl, zdp);

	if (strcmp(class, FM_LIST_REPAIRED_CLASS) == 0)
		is_repair = B_TRUE;
	else
		is_repair = B_FALSE;

	/*
	 * We subscribe to zfs faults as well as all repair events.
	 */
	if (nvlist_lookup_nvlist_array(nvl, FM_SUSPECT_FAULT_LIST,
	    &faults, &nfaults) != 0)
		return;

	for (f = 0; f < nfaults; f++) {
		fault = faults[f];

		fault_device = B_FALSE;
		degrade_device = B_FALSE;
		is_disk = B_FALSE;

		if (nvlist_lookup_boolean_value(fault, FM_SUSPECT_RETIRE,
		    &retire) == 0 && retire == 0)
			continue;
		if (fmd_nvl_class_match(hdl, fault, "fault.io.disk.slow-io") &&
		    fmd_prop_get_int32(hdl, "slow_io_skip_retire") ==
		    FMD_B_TRUE) {
			fmd_hdl_debug(hdl, "ignoring slow io fault");
			continue;
		}

		if (fmd_nvl_class_match(hdl, fault,
		    "fault.io.disk.ssm-wearout") &&
		    fmd_prop_get_int32(hdl, "ssm_wearout_skip_retire") ==
		    FMD_B_TRUE) {
			fmd_hdl_debug(hdl, "zfs-retire: ignoring SSM fault");
			continue;
		}

		if (fmd_nvl_class_match(hdl, fault,
		    "fault.io.disk.ssm-wearout") &&
		    fmd_prop_get_int32(hdl, "ssm_wearout_skip_retire") ==
		    FMD_B_TRUE) {
			fmd_hdl_debug(hdl, "zfs-retire: ignoring SSM fault");
			continue;
		}

		/*
		 * While we subscribe to fault.fs.zfs.*, we only take action
		 * for faults targeting a specific vdev (open failure or SERD
		 * failure).  We also subscribe to fault.io.* events, so that
		 * faulty disks will be faulted in the ZFS configuration.
		 */
		if (fmd_nvl_class_match(hdl, fault, "fault.fs.zfs.vdev.io")) {
			fault_device = B_TRUE;
		} else if (fmd_nvl_class_match(hdl, fault,
		    "fault.fs.zfs.vdev.checksum")) {
			degrade_device = B_TRUE;
		} else if (fmd_nvl_class_match(hdl, fault,
		    "fault.fs.zfs.vdev.timeout")) {
			fault_device = B_TRUE;
		} else if (fmd_nvl_class_match(hdl, fault,
		    "fault.fs.zfs.device")) {
			fault_device = B_FALSE;
		} else if (fmd_nvl_class_match(hdl, fault, "fault.io.disk.*") ||
		    fmd_nvl_class_match(hdl, fault, "fault.io.scsi.*")) {
			is_disk = B_TRUE;
			fault_device = B_TRUE;
		} else {
			continue;
		}

		if (is_disk) {
			/*
			 * This is a disk fault.  Lookup the FRU and ASRU,
			 * convert them to FMRI and devid strings, and attempt
			 * to find a matching vdev. If no vdev is found, the
			 * device might still be retired/unretired.
			 */
			if (nvlist_lookup_nvlist(fault, FM_FAULT_FRU,
			    &fru) != 0 ||
			    nvlist_lookup_string(fru, FM_FMRI_SCHEME,
			    &scheme) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: unable to get FRU");
				goto nofru;
			}

			if (strcmp(scheme, FM_FMRI_SCHEME_HC) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: not hc scheme: %s",
				    scheme);
				goto nofru;
			}

			thp = fmd_hdl_topo_hold(hdl, TOPO_VERSION);
			if (topo_fmri_nvl2str(thp, fru, &fmri, &err) != 0) {
				fmd_hdl_topo_rele(hdl, thp);
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: unable to get FMRI");
				goto nofru;
			}

			fmd_hdl_debug(hdl, "zfs_retire_recv: got FMRI %s",
			    fmri);

		nofru:
			if (nvlist_lookup_nvlist(fault, FM_FAULT_ASRU,
			    &asru) != 0 ||
			    nvlist_lookup_string(asru, FM_FMRI_SCHEME,
			    &scheme) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: unable to get ASRU");
				goto nodevid;
			}

			if (strcmp(scheme, FM_FMRI_SCHEME_DEV) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: not dev scheme: %s",
				    scheme);
				goto nodevid;
			}

			if (nvlist_lookup_string(asru, FM_FMRI_DEV_ID,
			    &devidstr) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: couldn't get devid");
				goto nodevid;
			}

			fmd_hdl_debug(hdl, "zfs_retire_recv: got devid %s",
			    devidstr);

			if (devid_str_decode(devidstr, &devid, NULL) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: devid_str_decode failed");
				goto nodevid;
			}

			if (nvlist_lookup_string(asru, FM_FMRI_DEV_PATH,
			    &path) != 0) {
				fmd_hdl_debug(hdl,
				    "zfs_retire_recv: couldn't get path, "
				    "won't be able to retire device");
				goto nodevid;
			}

			fmd_hdl_debug(hdl, "zfs_retire_recv: got path %s",
			    path);

		nodevid:
			zhp = find_by_anything(hdl, zhdl, fmri, devid, 0,
			    &vdev);
			if (fmri) {
				topo_hdl_strfree(thp, fmri);
				fmd_hdl_topo_rele(hdl, thp);
			}
			if (devid)
				devid_free(devid);

			if (zhp == NULL) {
				fmd_hdl_debug(hdl, "zfs_retire_recv: no zhp");
				if (path != NULL)
					(void) zfs_retire_device(hdl, path,
					    !is_repair);
				continue;
			}

			(void) nvlist_lookup_uint64(vdev, ZPOOL_CONFIG_GUID,
			    &vdev_guid);

			fmd_hdl_debug(hdl, "zfs_retire_recv: found vdev GUID: %"
			    PRIx64, vdev_guid);

			aux = VDEV_AUX_EXTERNAL;
		} else {
			/*
			 * This is a ZFS fault.  Lookup the resource, and
			 * attempt to find the matching vdev.
			 */
			if (nvlist_lookup_nvlist(fault, FM_FAULT_RESOURCE,
			    &resource) != 0 ||
			    nvlist_lookup_string(resource, FM_FMRI_SCHEME,
			    &scheme) != 0)
				continue;

			if (strcmp(scheme, FM_FMRI_SCHEME_ZFS) != 0)
				continue;

			if (nvlist_lookup_uint64(resource, FM_FMRI_ZFS_POOL,
			    &pool_guid) != 0)
				continue;

			if (nvlist_lookup_uint64(resource, FM_FMRI_ZFS_VDEV,
			    &vdev_guid) != 0) {
				if (is_repair)
					vdev_guid = 0;
				else
					continue;
			}

			if ((zhp = find_by_guid(hdl, zhdl, pool_guid, vdev_guid,
			    &vdev)) == NULL)
				continue;

			if (fmd_nvl_class_match(hdl, fault,
			    "fault.fs.zfs.vdev.open_failed"))
				aux = VDEV_AUX_OPEN_FAILED;
			else
				aux = VDEV_AUX_ERR_EXCEEDED;
		}

		if (vdev_guid == 0) {
			/*
			 * For pool-level repair events, clear the entire pool.
			 */
			(void) zpool_clear(zhp, NULL, NULL);
			zpool_close(zhp);
			continue;
		}

		/*
		 * If this is a repair event, then mark the vdev as repaired and
		 * continue.
		 */
		if (is_repair) {
			if (is_disk && path != NULL &&
			    zfs_retire_device(hdl, path, B_FALSE) != 0)
				continue;

			repair_done = 1;
			(void) zpool_vdev_clear(zhp, vdev_guid);
			zpool_close(zhp);
			continue;
		}

		/*
		 * Actively fault the device if needed.
		 */
		if (fault_device) {
			(void) zpool_vdev_fault(zhp, vdev_guid, aux);

			if (zfs_get_vdev_state(hdl, zhdl, zhp, vdev_guid, &vdev)
			    == VDEV_STATE_FAULTED)
				retire_device = B_TRUE;
		}

		if (degrade_device)
			(void) zpool_vdev_degrade(zhp, vdev_guid, aux);

		/*
		 * Attempt to substitute a hot spare.
		 */
		replace_with_spare(hdl, zhp, vdev);
		zpool_close(zhp);

		if (is_disk && retire_device && path != NULL)
			(void) zfs_retire_device(hdl, path, B_TRUE);
	}

	if (strcmp(class, FM_LIST_REPAIRED_CLASS) == 0 && repair_done &&
	    nvlist_lookup_string(nvl, FM_SUSPECT_UUID, &uuid) == 0)
		fmd_case_uuresolved(hdl, uuid);
}

static const fmd_hdl_ops_t fmd_ops = {
	zfs_retire_recv,	/* fmdo_recv */
	NULL,			/* fmdo_timeout */
	NULL,			/* fmdo_close */
	NULL,			/* fmdo_stats */
	NULL,			/* fmdo_gc */
};

static const fmd_prop_t fmd_props[] = {
	{ "spare_on_remove", FMD_TYPE_BOOL, "true" },
	{ "slow_io_skip_retire", FMD_TYPE_BOOL, "true"},
	{ "ssm_wearout_skip_retire", FMD_TYPE_BOOL, "true"},
	{ "fru_compare", FMD_TYPE_BOOL, "true"},
	{ NULL, 0, NULL }
};

static const fmd_hdl_info_t fmd_info = {
	"ZFS Retire Agent", "1.1", &fmd_ops, fmd_props
};

void
_fmd_init(fmd_hdl_t *hdl)
{
	zfs_retire_data_t *zdp;
	libzfs_handle_t *zhdl;

	if ((zhdl = libzfs_init()) == NULL)
		return;

	if (fmd_hdl_register(hdl, FMD_API_VERSION, &fmd_info) != 0) {
		libzfs_fini(zhdl);
		return;
	}

	zdp = fmd_hdl_zalloc(hdl, sizeof (zfs_retire_data_t), FMD_SLEEP);
	zdp->zrd_hdl = zhdl;

	fmd_hdl_setspecific(hdl, zdp);
}

void
_fmd_fini(fmd_hdl_t *hdl)
{
	zfs_retire_data_t *zdp = fmd_hdl_getspecific(hdl);

	if (zdp != NULL) {
		zfs_retire_clear_data(hdl, zdp);
		libzfs_fini(zdp->zrd_hdl);
		fmd_hdl_free(hdl, zdp, sizeof (zfs_retire_data_t));
	}
}
