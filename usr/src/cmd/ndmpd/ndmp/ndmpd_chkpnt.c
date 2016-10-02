/*
 * Copyright (c) 2007, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright (c) 2013 by Delphix. All rights reserved.
 * Copyright (c) 2013 Steven Hartland. All rights reserved.
 * Copyright (c) 2016 Martin Matuska. All rights reserved.
 * Copyright 2016 Nexenta Systems, Inc. All rights reserved.
 */

/*
 * BSD 3 Clause License
 *
 * Copyright (c) 2007, The Storage Networking Industry Association.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 	- Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *
 * 	- Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in
 *	  the documentation and/or other materials provided with the
 *	  distribution.
 *
 *	- Neither the name of The Storage Networking Industry Association (SNIA)
 *	  nor the names of its contributors may be used to endorse or promote
 *	  products derived from this software without specific prior written
 *	  permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <syslog.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include "ndmpd.h"
#include <libzfs.h>

typedef struct snap_param {
	char *snp_name;
	boolean_t snp_found;
} snap_param_t;

/*
 * ndmp_create_snapshot
 *
 * This function will parse the path to get the real volume name.
 * It will then create a snapshot based on volume and job name.
 * This function should be called before the NDMP backup is started.
 *
 * Parameters:
 *   vol_name (input) - name of the volume
 *
 * Returns:
 *   0: on success
 *   -1: otherwise
 */
int
ndmp_create_snapshot(char *vol_name, char *jname)
{
	char vol[ZFS_MAXNAMELEN];

	if (vol_name != NULL) {
		if (get_zfsvolname(vol,
		    sizeof (vol), vol_name) == -1) {
			syslog(LOG_ERR,
			    "Cannot get volume from [%s] on create",
			    vol_name);
			return (-1);
		}
	} else {
		return (-1);
	}
	return (backup_dataset_create(vol,
	    jname, B_FALSE, B_TRUE));
}

/*
 * ndmp_remove_snapshot
 *
 * This function will parse the path to get the real volume name.
 * It will then remove the snapshot for that volume and job name.
 * This function should be called after NDMP backup is finished.
 *
 * Parameters:
 *   vol_name (input) - name of the volume
 *
 * Returns:
 *   0: on success
 *   -1: otherwise
 */
int
ndmp_remove_snapshot(ndmp_bkup_size_arg_t *sarg)
{
	char vol[ZFS_MAXNAMELEN];

	if (sarg->bs_path != NULL) {
		if (get_zfsvolname(vol,
		    sizeof (vol), sarg->bs_path) == -1) {
			syslog(LOG_ERR,
			    "Cannot get volume from [%s] on remove",
			    sarg->bs_path);
			return (-1);
		}
	} else {
		return (-1);
	}
	return (backup_dataset_destroy(vol,
	    sarg->bs_jname, B_FALSE, B_TRUE, NULL));
}

/*
 * Put a hold on snapshot
 */
int
snapshot_hold(char *volname, char *snapname, char *jname, boolean_t recursive)
{
	zfs_handle_t *zhp;
	char *p;

	if ((zhp = zfs_open(zlibh, volname, ZFS_TYPE_DATASET)) == 0) {
		syslog(LOG_ERR, "Cannot open volume %s.", volname);
		return (-1);
	}
	p = strchr(snapname, '@') + 1;
	/*
	 * The -1 tells the lower levels there are no snapshots
	 * to clean up.
	 */
	if (zfs_hold(zhp, p, jname, recursive, -1) != 0) {
		syslog(LOG_ERR, "Cannot hold snapshot %s", p);
		zfs_close(zhp);
		return (-1);
	}
	zfs_close(zhp);
	return (0);
}

int
snapshot_release(char *volname, char *snapname, char *jname,
    boolean_t recursive)
{
	zfs_handle_t *zhp;
	char *p;
	int rv = 0;

	if ((zhp = zfs_open(zlibh, volname, ZFS_TYPE_DATASET)) == 0) {
		syslog(LOG_ERR, "Cannot open volume %s", volname);
		return (-1);
	}

	p = strchr(snapname, '@') + 1;
	if (zfs_release(zhp, p, jname, recursive) != 0) {
		syslog(LOG_DEBUG, "Cannot release snapshot %s", p);
		rv = -1;
	}
	zfs_close(zhp);
	return (rv);
}

/*
 * Create a snapshot, put a hold on it, clone it, and mount it in a
 * well known location for so the backup process can traverse its
 * directory tree structure.
 */
int
backup_dataset_create(char *volname, char *jname,
	boolean_t recursive, boolean_t hold)
{
	char snapname[ZFS_MAXNAMELEN];
	char clonename[ZFS_MAXNAMELEN];
	char zpoolname[ZFS_MAXNAMELEN];
	char *slash;
	int rv;

	if (volname == NULL || *volname == '\0') {
		return (-1);
	}

	(void) strlcpy(zpoolname, volname, sizeof (zpoolname));
	/*
	 * Pull out the pool name component from the volname
	 * to use it to build snapshot and clone names.
	 */
	slash = strchr(zpoolname, '/');
	if (slash != NULL) {
		*slash = '\0';
	}

	(void) snprintf(snapname, sizeof (snapname),
	    "%s@%s", volname, jname);
	(void) snprintf(clonename, sizeof (clonename),
	    "%s/%s", zpoolname, jname);

	(void) mutex_lock(&zlib_mtx);
	if ((rv = zfs_snapshot(zlibh, snapname, recursive, NULL)) != 0) {
		if (errno == EEXIST) {
			(void) mutex_unlock(&zlib_mtx);
			return (0);
		}
		syslog(LOG_ERR,
		    "backup_dataset_create: %s failed (err=%d): %s",
		    snapname, errno, libzfs_error_description(zlibh));
		(void) mutex_unlock(&zlib_mtx);
		return (rv);
	}
	if (hold && snapshot_hold(volname,
	    snapname, NDMP_RCF_BASENAME, recursive) != 0) {
		syslog(LOG_DEBUG,
		    "backup_dataset_create: %s hold failed (err=%d): %s",
		    snapname, errno, libzfs_error_description(zlibh));
		(void) mutex_unlock(&zlib_mtx);
		return (-1);
	}
	if (ndmp_clone_snapshot(snapname, clonename) != 0) {
		syslog(LOG_ERR,
		    "backup_dataset_create: %s clone failed (err=%d): %s",
		    snapname, errno, libzfs_error_description(zlibh));
		(void) mutex_unlock(&zlib_mtx);
		return (-1);
	}
	(void) mutex_unlock(&zlib_mtx);
	return (0);
}

/*
 * Unmount, release, and destroy the snapshot created for backup.
 */
int
backup_dataset_destroy(char *volname, char *jname, boolean_t recursive,
    boolean_t hold, int *zfs_err)
{
	char snapname[ZFS_MAXNAMELEN];
	char clonename[ZFS_MAXNAMELEN];
	char zpoolname[ZFS_MAXNAMELEN];
	char clone_mount_point[ZFS_MAXNAMELEN];
	char *slash;
	zfs_handle_t *vol_zhp;
	zfs_handle_t *cln_zhp;
	int err;
	int rv = 0;

	if (volname == NULL || *volname == '\0') {
		return (-1);
	}

	(void) strlcpy(zpoolname, volname, sizeof (zpoolname));
	slash = strchr(zpoolname, '/');
	if (slash != NULL) {
		*slash = '\0';
	}

	if (zfs_err != NULL) {
		*zfs_err = 0;
	}

	(void) snprintf(snapname, sizeof (snapname),
	    "%s@%s", volname, jname);
	(void) snprintf(clonename, sizeof (clonename),
	    "%s/%s", zpoolname, jname);
	(void) snprintf(clone_mount_point,
	    sizeof (clone_mount_point), "/%s", clonename);

	syslog(LOG_DEBUG, "Destroy [%s]", snapname);

	/*
	 * Destroy using this sequence
	 * zfs release <volume>@<jname>
	 * zfs destroy <pool>/<jname>
	 * zfs destroy <pool>/<volume>@<jname>
	 */
	(void) mutex_lock(&zlib_mtx);

	if (hold &&
	    snapshot_release(volname,
	    snapname, NDMP_RCF_BASENAME, recursive) != 0) {
		syslog(LOG_DEBUG,
		    "backup_dataset_destroy: %s release failed (err=%d): %s",
		    clonename, errno, libzfs_error_description(zlibh));
		(void) mutex_unlock(&zlib_mtx);
		return (-1);
	}

	/*
	 * Open the clone to get descriptor
	 */
	if ((cln_zhp = zfs_open(zlibh, clonename,
	    ZFS_TYPE_VOLUME | ZFS_TYPE_FILESYSTEM)) == NULL) {
		syslog(LOG_ERR,
		    "backup_dataset_destroy: open %s failed", clonename);
		(void) mutex_unlock(&zlib_mtx);
		return (-1);
	}

	/*
	 * Open the mounted clone to get descriptor for unmount
	 */
	if ((vol_zhp = zfs_open(zlibh, volname,
	    ZFS_TYPE_VOLUME | ZFS_TYPE_FILESYSTEM)) == NULL) {
		syslog(LOG_ERR,
		    "backup_dataset_destroy: open %s failed [while trying "
		    "to promote]", volname);
		zfs_close(cln_zhp);
		(void) mutex_unlock(&zlib_mtx);
		return (-1);
	}

	/*
	 * This unmounts the clone which was just traversed for backup
	 */
	if ((err = zfs_unmount(cln_zhp, NULL, 0)) != 0) {
		syslog(LOG_INFO, "failed to unmount [%s]", clonename);
		rv = -1;
		goto _out;
	}

	/*
	 * This destroys the clone
	 */
	err = zfs_destroy(cln_zhp, B_TRUE);
	if (err) {
		syslog(LOG_ERR, "%s (destroy: %s): %d; %s; %s",
		    clonename,
		    (recursive) ? "recursive" : "non-recursive",
		    libzfs_errno(zlibh),
		    libzfs_error_action(zlibh),
		    libzfs_error_description(zlibh));

		if (zfs_err)
			*zfs_err = err;
		rv = -1;
		goto _out;
	}

	/*
	 * This destroys the snapshot of the current backup
	 */
	err = zfs_destroy_snaps(vol_zhp, jname, B_TRUE);
	if (err) {
		syslog(LOG_ERR, "%s (destroy: %d): %d; %s; %s",
		    jname,
		    recursive,
		    libzfs_errno(zlibh),
		    libzfs_error_action(zlibh),
		    libzfs_error_description(zlibh));

		if (zfs_err)
			*zfs_err = err;
		rv = -1;
		goto _out;
	}

_out:
	zfs_close(vol_zhp);
	zfs_close(cln_zhp);
	(void) mutex_unlock(&zlib_mtx);

	/*
	 * The zfs_clone() call will have mounted the snapshot
	 * in the file system at this point - so clean it up.
	 */
	if (rv == 0) {
		if (rmdir(clone_mount_point) != 0) {
			syslog(LOG_ERR,
			    "Failed to remove mount point [%s]",
			    clone_mount_point);
			return (-1);
		}
	}

	return (rv);
}
