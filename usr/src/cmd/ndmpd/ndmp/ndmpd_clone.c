/*
 * CDDL HEADER START
 *
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2016 Nexenta Systems, Inc. All rights reserved.
 */

#include <syslog.h>
#include <stdio.h>
#include <string.h>
#include "ndmpd.h"
#include <libzfs.h>
#include <zlib.h>

/*
 * ndmp_clone_snapshot
 *
 * Given a snapshot name in the file system, create a clone and
 * and mount it in a well known place for ndmpd to traverse it.
 *
 * Parameters:
 *   snapshot_name (input) - name of the snapshot
 *   clone_name    (input) - name of the clone for the snapshot
 *
 * Returns:
 *   0: on success
 *   -1: otherwise
 */
int
ndmp_clone_snapshot(char *snapshot_name, char *clone_name)
{
	int		res = 0;
	int		err;
	zfs_handle_t	*zhp;
	zfs_handle_t	*clone;
	nvlist_t	*props = NULL;
	char clone_mount_point[PATH_MAX];

	if ((zhp = zfs_open(zlibh, snapshot_name, ZFS_TYPE_SNAPSHOT)) == NULL) {
		syslog(LOG_ERR,
		    "Could not open snapshot [%s]\n", snapshot_name);
		return (-1);
	}
	syslog(LOG_DEBUG, "Clone [%s]\n", snapshot_name);

	(void) snprintf(clone_mount_point, sizeof (clone_mount_point),
	    "/%s", clone_name);

	if ((nvlist_alloc(&props, NV_UNIQUE_NAME, 0) != 0) ||
	    (nvlist_add_string(props, zfs_prop_to_name(ZFS_PROP_MOUNTPOINT),
	    clone_mount_point) != 0)) {
		nvlist_free(props);
		syslog(LOG_ERR, "could not create snapshot clone "
		    "%s: out of memory\n", clone_name);
		zfs_close(zhp);
		return (-1);
	}

	err = zfs_clone(zhp, clone_name, props);
	zfs_close(zhp);
	nvlist_free(props);

	if (err != 0) {
		syslog(LOG_ERR, "zfs_clone error [%d]\n", err);
		return (-1);
	}

	if ((clone = zfs_open(zlibh, clone_name, ZFS_TYPE_DATASET)) == NULL) {
		syslog(LOG_ERR,
		    "zfs_open failed on clone_name [%s]\n", clone_name);
		return (-1);
	}

	if (zfs_mount(clone, NULL, 0) != 0) {
		syslog(LOG_ERR, "could not mount ZFS clone "
		    "%s\n", zfs_get_name(clone));
		res = -1;
	}
	zfs_close(clone);
	return (res);
}
