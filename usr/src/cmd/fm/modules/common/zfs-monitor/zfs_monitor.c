/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may  only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy is of the CDDL is also available via the Internet
 * at http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2013 Nexenta Systems, Inc. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libzfs.h>
#include <errno.h>
#include <note.h>
#include <fcntl.h>
#include <unistd.h>
#include <fm/fmd_api.h>
#include <sys/fs/zfs.h>
#include <sys/fm/protocol.h>
#include <sys/fm/fs/zfs.h>
#include <sys/dkio.h>

typedef struct zm {
	fmd_hdl_t	*fhdl;
	libzfs_handle_t	*zhdl;
	fmd_xprt_t	*xprt;
	id_t		tid;
	hrtime_t	interval;
	boolean_t	exit;
} zm_t;

static boolean_t
zm_read_disk(zm_t *zm, char *path)
{
	char *block;
	char rpath[MAXPATHLEN];
	const char *func;
	struct dk_minfo_ext minfo_ext;
	int fd;
	uint_t bsize = DEV_BSIZE;

	(void) snprintf(rpath, sizeof (rpath), "/dev/rdsk/%s", path);

	func = "open";
	if ((fd = open(rpath, O_RDONLY | O_NDELAY)) < 0)
		goto err_open;

	if (ioctl(fd, DKIOCGMEDIAINFOEXT, &minfo_ext) != -1)
		bsize = minfo_ext.dki_lbsize;

	func = "malloc";
	if ((block = malloc(bsize)) == NULL)
		goto err_malloc;

	func = "read";
	if (read(fd, block, bsize) != bsize)
		goto err_read;

	(void) close(fd);
	free(block);
	return (B_TRUE);

err_read:
	free(block);
err_malloc:
	(void) close(fd);
err_open:
	fmd_hdl_debug(zm->fhdl, "device %s failed: %s\n", func,
	    strerror(errno));
	return (B_FALSE);
}

static void
zm_process_tree(zm_t *zm, zpool_handle_t *zph, nvlist_t *vd)
{
	nvlist_t	**child;
	uint_t		nchild, c;
	vdev_stat_t	*vs;
	uint64_t	pguid, vguid;
	int		ret;
	boolean_t	leaf = B_TRUE;
	nvlist_t	*er;	/* ereport */
	nvlist_t	*dt;	/* detector */
	uint64_t	ena;
	char		*class;
	char		*path;
	char		*vtype;

	/*
	 * If we have children devices, then we're not a physical
	 * vdev.  We only really want to be monitoring real physical
	 * devices, but we do recurse down to find all the real
	 * devices.
	 */

	/*
	 * NB: ZIL devices (LOG devices) are in the CHILDREN array,
	 * but are distinguished by a special nvpair "is_log".  We
	 * don't bother to distinguish the two.
	 */
	if (nvlist_lookup_nvlist_array(vd, ZPOOL_CONFIG_CHILDREN, &child,
	    &nchild) == 0) {
		for (c = 0; c < nchild; c++) {
			zm_process_tree(zm, zph, child[c]);
		}
		leaf = B_FALSE;
	}
	if (nvlist_lookup_nvlist_array(vd, ZPOOL_CONFIG_L2CACHE, &child,
	    &nchild) == 0) {
		for (c = 0; c < nchild; c++) {
			zm_process_tree(zm, zph, child[c]);
		}
		leaf = B_FALSE;
	}
	if (nvlist_lookup_nvlist_array(vd, ZPOOL_CONFIG_SPARES, &child,
	    &nchild) == 0) {
		for (c = 0; c < nchild; c++) {
			zm_process_tree(zm, zph, child[c]);
		}
		leaf = B_FALSE;
	}

	/*
	 * Only process physical disk devices.
	 */
	if ((!leaf) ||
	    (nvlist_lookup_string(vd, ZPOOL_CONFIG_TYPE, &vtype) != 0) ||
	    (strcmp(vtype, VDEV_TYPE_DISK) != 0) ||
	    (nvlist_lookup_string(vd, ZPOOL_CONFIG_PATH, &path) != 0) ||
	    (strncmp(path, "/dev/dsk/", 9) != 0)) {
		return;
	}

	ret = nvlist_lookup_uint64_array(vd, ZPOOL_CONFIG_VDEV_STATS,
	    (uint64_t **)&vs, &c);
	assert(ret == 0);

	switch (vs->vs_state) {
	case VDEV_STATE_HEALTHY:
	case VDEV_STATE_DEGRADED:
		/*
		 * We only care to look at states where ZFS thinks
		 * that the device is ready to go.  Its unclear what
		 * DEGRADED would mean in the presence of a real disk,
		 * but lets try to handle it too.
		 */
		break;
	default:
		/*
		 * For devices that are already in some kind of
		 * offline state, we have nothing to do, ZFS already
		 * should have brought in a spare, or whatever.
		 */
		fmd_hdl_debug(zm->fhdl, "device state %d not healthy\n",
		    vs->vs_state);
		return;
	}

	if (zm_read_disk(zm, path + 9))
		return;

	/*
	 * From this point on, we know that the vdev is failed or
	 * non-responsive, but ZFS doesn't realize it yet.  Lets
	 * trigger an FMA ereport, which the ZFS diagnostic engine will
	 * recognize.
	 *
	 * Note that because of the way zfs_de.c works, we need to put the
	 * VDEV into faulted state first, otherwise the diagnosis engine
	 * won't do anything with it.
	 */

	class = FM_EREPORT_CLASS "." ZFS_ERROR_CLASS "."
	    FM_EREPORT_ZFS_DEVICE_OPEN_FAILED;
	ena = fmd_event_ena_create(zm->fhdl);
	pguid = zpool_get_prop_int(zph, ZPOOL_PROP_GUID, NULL);
	ret = nvlist_lookup_uint64(vd, ZPOOL_CONFIG_GUID, &vguid);
	assert(ret == 0);

	ret = zpool_vdev_fault(zph, vguid, VDEV_AUX_OPEN_FAILED);
	if (ret != 0) {
		fmd_hdl_debug(zm->fhdl, "can't fault vdev %llx: %d, %d, %s\n",
		    (unsigned long long)vguid, ret, errno, strerror(errno));
	}

	dt = fmd_nvl_alloc(zm->fhdl, FMD_SLEEP);
	(void) nvlist_add_uint8(dt, FM_VERSION, ZFS_SCHEME_VERSION0);
	(void) nvlist_add_string(dt, FM_FMRI_SCHEME, FM_FMRI_SCHEME_ZFS);
	(void) nvlist_add_uint64(dt, FM_FMRI_ZFS_POOL, pguid);
	(void) nvlist_add_uint64(dt, FM_FMRI_ZFS_VDEV, vguid);

	er = fmd_nvl_alloc(zm->fhdl, FMD_SLEEP);
	(void) nvlist_add_string(er, FM_CLASS, class);
	(void) nvlist_add_uint8(er, FM_VERSION, FM_EREPORT_VERSION);
	(void) nvlist_add_uint64(er, FM_EREPORT_ENA, ena);
	(void) nvlist_add_nvlist(er, FM_EREPORT_DETECTOR, dt);
	(void) nvlist_add_string(er, FM_EREPORT_PAYLOAD_ZFS_POOL,
	    zpool_get_name(zph));
	(void) nvlist_add_uint64(er, FM_EREPORT_PAYLOAD_ZFS_POOL_GUID, pguid);
	(void) nvlist_add_uint64(er, FM_EREPORT_PAYLOAD_ZFS_VDEV_GUID, vguid);
	(void) nvlist_add_uint64(er, FM_EREPORT_PAYLOAD_ZFS_POOL_CONTEXT,
	    SPA_LOAD_NONE);
	(void) nvlist_add_string(er, FM_EREPORT_PAYLOAD_ZFS_VDEV_TYPE, vtype);

	/*
	 * Note that it would appear that kernel events include other
	 * payload items, but for vdev ereports, the diagnosis engine
	 * doesn't need them.  Arguably, we could have skipped the
	 * entire zfs diagnosis engine, but this way we keep the same
	 * code paths as other ereports.
	 */
	fmd_xprt_post(zm->fhdl, zm->xprt, er, 0);
	fmd_hdl_debug(zm->fhdl, "posted ereport: %s for %s\n", class, path);
}

static int
zm_pool_iter(zpool_handle_t *zph, void *arg)
{
	zm_t		*zm = arg;
	nvlist_t	*cfg;
	nvlist_t	*vd;

	cfg = zpool_get_config(zph, NULL);
	if (nvlist_lookup_nvlist(cfg, ZPOOL_CONFIG_VDEV_TREE, &vd) == 0) {
		zm_process_tree(zm, zph, vd);
	} else {
		fmd_hdl_debug(zm->fhdl, "missing vdev tree?!?\n");
	}
	zpool_close(zph);
	return (0);
}

static void
zm_timeout(fmd_hdl_t *hdl, id_t id, void *arg)
{
	zm_t		*zm = arg;
	_NOTE(ARGUNUSED(hdl));
	_NOTE(ARGUNUSED(id));

	if (zm->exit)
		return;
	(void) zpool_iter(zm->zhdl, zm_pool_iter, zm);
	zm->tid = fmd_timer_install(hdl, zm, NULL, zm->interval);
}

static const fmd_hdl_ops_t fmd_ops = {
	NULL,		/* fmdo_recv */
	zm_timeout,	/* fmdo_timeout */
	NULL,		/* fmdo_close */
	NULL,		/* fmdo_stats */
	NULL,		/* fmdo_gc */
	NULL,		/* fmdo_send */
	NULL,		/* fmdo_topo_change */
};

static const fmd_prop_t fmd_props[] = {
	{ "interval", FMD_TYPE_TIME, "10sec" },
	{ NULL, 0, NULL }
};

static const fmd_hdl_info_t fmd_info = {
	"ZFS Disk Monitor", "1.0", &fmd_ops, fmd_props
};

void
_fmd_init(fmd_hdl_t *fhdl)
{
	zm_t	*zm;

	if (fmd_hdl_register(fhdl, FMD_API_VERSION, &fmd_info) != 0) {
		return;
	}

	zm = fmd_hdl_alloc(fhdl, sizeof (*zm), FMD_SLEEP);

	zm->fhdl = fhdl;

	if ((zm->zhdl = libzfs_init()) == NULL)
		return;

	fmd_hdl_setspecific(fhdl, zm);
	zm->interval = fmd_prop_get_int64(fhdl, "interval");
	zm->xprt = fmd_xprt_open(fhdl, FMD_XPRT_RDONLY, NULL, NULL);
	zm->exit = B_FALSE;
	fmd_hdl_debug(fhdl, "interval: %llu\n",
	    (unsigned long long)zm->interval);
	zm->tid = fmd_timer_install(fhdl, zm, NULL, zm->interval);
}

void
_fmd_fini(fmd_hdl_t *fhdl)
{
	zm_t	*zm;

	zm = fmd_hdl_getspecific(fhdl);
	zm->exit = B_TRUE;

	(void) fmd_timer_remove(fhdl, zm->tid);
	fmd_xprt_close(fhdl, zm->xprt);

	libzfs_fini(zm->zhdl);

	fmd_hdl_free(fhdl, zm, sizeof (*zm));
}
