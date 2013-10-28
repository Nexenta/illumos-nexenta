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
 * Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
 * Copyright (c) 2013 by Delphix. All rights reserved.
 * Copyright (c) 2013 Steven Hartland. All rights reserved.
 */

/*
 * LibZFS_Core (lzc) is intended to replace most functionality in libzfs.
 * It has the following characteristics:
 *
 *  - Thread Safe.  libzfs_core is accessible concurrently from multiple
 *  threads.  This is accomplished primarily by avoiding global data
 *  (e.g. caching).  Since it's thread-safe, there is no reason for a
 *  process to have multiple libzfs "instances".  Therefore, we store
 *  our few pieces of data (e.g. the file descriptor) in global
 *  variables.  The fd is reference-counted so that the libzfs_core
 *  library can be "initialized" multiple times (e.g. by different
 *  consumers within the same process).
 *
 *  - Committed Interface.  The libzfs_core interface will be committed,
 *  therefore consumers can compile against it and be confident that
 *  their code will continue to work on future releases of this code.
 *  Currently, the interface is Evolving (not Committed), but we intend
 *  to commit to it once it is more complete and we determine that it
 *  meets the needs of all consumers.
 *
 *  - Programatic Error Handling.  libzfs_core communicates errors with
 *  defined error numbers, and doesn't print anything to stdout/stderr.
 *
 *  - Thin Layer.  libzfs_core is a thin layer, marshaling arguments
 *  to/from the kernel ioctls.  There is generally a 1:1 correspondence
 *  between libzfs_core functions and ioctls to /dev/zfs.
 *
 *  - Clear Atomicity.  Because libzfs_core functions are generally 1:1
 *  with kernel ioctls, and kernel ioctls are general atomic, each
 *  libzfs_core function is atomic.  For example, creating multiple
 *  snapshots with a single call to lzc_snapshot() is atomic -- it
 *  can't fail with only some of the requested snapshots created, even
 *  in the event of power loss or system crash.
 *
 *  - Continued libzfs Support.  Some higher-level operations (e.g.
 *  support for "zfs send -R") are too complicated to fit the scope of
 *  libzfs_core.  This functionality will continue to live in libzfs.
 *  Where appropriate, libzfs will use the underlying atomic operations
 *  of libzfs_core.  For example, libzfs may implement "zfs send -R |
 *  zfs receive" by using individual "send one snapshot", rename,
 *  destroy, and "receive one snapshot" operations in libzfs_core.
 *  /sbin/zfs and /zbin/zpool will link with both libzfs and
 *  libzfs_core.  Other consumers should aim to use only libzfs_core,
 *  since that will be the supported, stable interface going forwards.
 */

#include <libzfs_core.h>
#include <ctype.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/nvpair.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/zfs_ioctl.h>

static int g_fd;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static int g_refcount;

int
libzfs_core_init(void)
{
	(void) pthread_mutex_lock(&g_lock);
	if (g_refcount == 0) {
		g_fd = open("/dev/zfs", O_RDWR);
		if (g_fd < 0) {
			(void) pthread_mutex_unlock(&g_lock);
			return (errno);
		}
	}
	g_refcount++;
	(void) pthread_mutex_unlock(&g_lock);
	return (0);
}

void
libzfs_core_fini(void)
{
	(void) pthread_mutex_lock(&g_lock);
	ASSERT3S(g_refcount, >, 0);
	g_refcount--;
	if (g_refcount == 0)
		(void) close(g_fd);
	(void) pthread_mutex_unlock(&g_lock);
}

static int
lzc_ioctl(zfs_ioc_t ioc, const char *name,
    nvlist_t *source, nvlist_t **resultp)
{
	zfs_cmd_t zc = { 0 };
	int error = 0;
	char *packed;
	size_t size = 0;

	ASSERT3S(g_refcount, >, 0);

	if (name != NULL)
		(void) strlcpy(zc.zc_name, name, sizeof (zc.zc_name));

	if (source != NULL) {
		packed = fnvlist_pack(source, &size);
		zc.zc_nvlist_src = (uint64_t)(uintptr_t)packed;
		zc.zc_nvlist_src_size = size;
	} else {
		packed = NULL;
	}

	if (resultp != NULL) {
		*resultp = NULL;
		zc.zc_nvlist_dst_size = MAX(size * 2, 128 * 1024);
		zc.zc_nvlist_dst = (uint64_t)(uintptr_t)
		    malloc(zc.zc_nvlist_dst_size);
		if (zc.zc_nvlist_dst == NULL) {
			error = ENOMEM;
			goto out;
		}
	}

	while (ioctl(g_fd, ioc, &zc) != 0) {
		if (errno == ENOMEM && resultp != NULL) {
			free((void *)(uintptr_t)zc.zc_nvlist_dst);
			zc.zc_nvlist_dst_size *= 2;
			zc.zc_nvlist_dst = (uint64_t)(uintptr_t)
			    malloc(zc.zc_nvlist_dst_size);
			if (zc.zc_nvlist_dst == NULL) {
				error = ENOMEM;
				goto out;
			}
		} else {
			error = errno;
			break;
		}
	}
	if (zc.zc_nvlist_dst_filled) {
		*resultp = fnvlist_unpack((void *)(uintptr_t)zc.zc_nvlist_dst,
		    zc.zc_nvlist_dst_size);
	}

	free((void *)(uintptr_t)zc.zc_nvlist_dst);
out:
	if (packed != NULL)
		fnvlist_pack_free(packed, size);
	return (error);
}

int
lzc_pool_stats(const char *poolname, nvlist_t **stats)
{
	if (poolname == NULL || stats == NULL)
		return (EINVAL);

	return (lzc_ioctl(ZFS_IOC_POOL_STATS_NVL, poolname, NULL, stats));
}

/*
 * Generation IDs are used to determine whether the config is already known to
 * the caller. If they match, the ioctl will return EEXIST and a NULL config. If
 * we get back configs, we always extract and remove the generation number after
 * update. We have to keep state via the generation number, which is passed back
 * via configs, so neither can be NULL.
 */
int
lzc_pool_configs(uint64_t *generation, nvlist_t **configs)
{
	nvlist_t *args;
	int ret;

	if (generation == NULL || configs == NULL)
		return (EINVAL);

	args = fnvlist_alloc();
	fnvlist_add_uint64(args, "generation", *generation);
	ret = lzc_ioctl(ZFS_IOC_POOL_CONFIGS_NVL, NULL, args, configs);
	if (ret == 0) {
		*generation = fnvlist_lookup_uint64(*configs, "_generation");
		fnvlist_remove(*configs, "_generation");
	} else {
		ASSERT3P(configs, ==, NULL);
	}
	nvlist_free(args);

	return (ret);
}

int
lzc_pool_get_props(const char *poolname, nvlist_t **props)
{
	if (poolname == NULL || props == NULL)
		return (EINVAL);

	return (lzc_ioctl(ZFS_IOC_POOL_GET_PROPS_NVL, poolname, NULL, props));
}

int
lzc_create(const char *fsname, dmu_objset_type_t type, nvlist_t *props)
{
	int error;
	nvlist_t *args = fnvlist_alloc();
	fnvlist_add_int32(args, "type", type);
	if (props != NULL)
		fnvlist_add_nvlist(args, "props", props);
	error = lzc_ioctl(ZFS_IOC_CREATE, fsname, args, NULL);
	nvlist_free(args);
	return (error);
}

int
lzc_clone(const char *fsname, const char *origin,
    nvlist_t *props)
{
	int error;
	nvlist_t *args = fnvlist_alloc();
	fnvlist_add_string(args, "origin", origin);
	if (props != NULL)
		fnvlist_add_nvlist(args, "props", props);
	error = lzc_ioctl(ZFS_IOC_CLONE, fsname, args, NULL);
	nvlist_free(args);
	return (error);
}

/*
 * Creates snapshots.
 *
 * The keys in the snaps nvlist are the snapshots to be created.
 * They must all be in the same pool.
 *
 * The props nvlist is properties to set.  Currently only user properties
 * are supported.  { user:prop_name -> string value }
 *
 * The returned results nvlist will have an entry for each snapshot that failed.
 * The value will be the (int32) error code.
 *
 * The return value will be 0 if all snapshots were created, otherwise it will
 * be the errno of a (unspecified) snapshot that failed.
 */
int
lzc_snapshot(nvlist_t *snaps, nvlist_t *props, nvlist_t **errlist)
{
	nvpair_t *elem;
	nvlist_t *args;
	int error;
	char pool[MAXNAMELEN];

	*errlist = NULL;

	/* determine the pool name */
	elem = nvlist_next_nvpair(snaps, NULL);
	if (elem == NULL)
		return (0);
	(void) strlcpy(pool, nvpair_name(elem), sizeof (pool));
	pool[strcspn(pool, "/@")] = '\0';

	args = fnvlist_alloc();
	fnvlist_add_nvlist(args, "snaps", snaps);
	if (props != NULL)
		fnvlist_add_nvlist(args, "props", props);

	error = lzc_ioctl(ZFS_IOC_SNAPSHOT, pool, args, errlist);
	nvlist_free(args);

	return (error);
}

/*
 * Destroys snapshots.
 *
 * The keys in the snaps nvlist are the snapshots to be destroyed.
 * They must all be in the same pool.
 *
 * Snapshots that do not exist will be silently ignored.
 *
 * If 'defer' is not set, and a snapshot has user holds or clones, the
 * destroy operation will fail and none of the snapshots will be
 * destroyed.
 *
 * If 'defer' is set, and a snapshot has user holds or clones, it will be
 * marked for deferred destruction, and will be destroyed when the last hold
 * or clone is removed/destroyed.
 *
 * The return value will be 0 if all snapshots were destroyed (or marked for
 * later destruction if 'defer' is set) or didn't exist to begin with.
 *
 * Otherwise the return value will be the errno of a (unspecified) snapshot
 * that failed, no snapshots will be destroyed, and the errlist will have an
 * entry for each snapshot that failed.  The value in the errlist will be
 * the (int32) error code.
 */
int
lzc_destroy_snaps(nvlist_t *snaps, boolean_t defer, nvlist_t **errlist)
{
	nvpair_t *elem;
	nvlist_t *args;
	int error;
	char pool[MAXNAMELEN];

	/* determine the pool name */
	elem = nvlist_next_nvpair(snaps, NULL);
	if (elem == NULL)
		return (0);
	(void) strlcpy(pool, nvpair_name(elem), sizeof (pool));
	pool[strcspn(pool, "/@")] = '\0';

	args = fnvlist_alloc();
	fnvlist_add_nvlist(args, "snaps", snaps);
	if (defer)
		fnvlist_add_boolean(args, "defer");

	error = lzc_ioctl(ZFS_IOC_DESTROY_SNAPS, pool, args, errlist);
	nvlist_free(args);

	return (error);
}

int
lzc_snaprange_space(const char *firstsnap, const char *lastsnap,
    uint64_t *usedp)
{
	nvlist_t *args;
	nvlist_t *result;
	int err;
	char fs[MAXNAMELEN];
	char *atp;

	/* determine the fs name */
	(void) strlcpy(fs, firstsnap, sizeof (fs));
	atp = strchr(fs, '@');
	if (atp == NULL)
		return (EINVAL);
	*atp = '\0';

	args = fnvlist_alloc();
	fnvlist_add_string(args, "firstsnap", firstsnap);

	err = lzc_ioctl(ZFS_IOC_SPACE_SNAPS, lastsnap, args, &result);
	nvlist_free(args);
	if (err == 0)
		*usedp = fnvlist_lookup_uint64(result, "used");
	fnvlist_free(result);

	return (err);
}

/* nvlist functions return pointers to nvlists, so we dup to extract */
static nvlist_t *
lzc_extract_nvl(nvlist_t *nvl, const char *propname)
{
	return (fnvlist_dup(fnvlist_lookup_nvlist(nvl, propname)));
}

/* nvlist functions return pointers to strings, so we copy to extract */
static int
lzc_extract_name(nvlist_t *nvl, const char *propname, char **name)
{
	int ret = 0;
	char *p;

	p = fnvlist_lookup_string(nvl, propname);
	errno = 0;
	if ((*name = strdup(p)) == NULL)
		ret = errno;

	return (ret);
}

/*
 * We have to know our dataset and offset and optionally accept the name of the
 * next snapshot and its stats and props.
 */
int
lzc_snapshot_list_next(const char *dataset, uint64_t *offset, char **nextsnap,
    nvlist_t **stats, nvlist_t **props)
{
	int ret;
	nvlist_t *args, *result;

	if (dataset == NULL || offset == NULL)
		return (EINVAL);

	args = fnvlist_alloc();
	fnvlist_add_uint64(args, "offset", *offset);
	if ((ret = lzc_ioctl(ZFS_IOC_SNAPSHOT_LIST_NEXT_NVL, dataset, args,
	    &result)) == 0) {
		if (nextsnap != NULL) {
			if ((ret = lzc_extract_name(result, "nextsnap",
			    nextsnap)) != 0)
				goto out;
		}
		if (stats != NULL)
			*stats = lzc_extract_nvl(result, "stats");
		if (props != NULL)
			*props = lzc_extract_nvl(result, "props");
		*offset = fnvlist_lookup_uint64(result, "offset");
	}

out:
	if (result != NULL)
		nvlist_free(result);
	nvlist_free(args);

	return (ret);
}

/*
 * Dataset name alone can be used alone for an existence test. We can ignore
 * stats and props. type is optional to verify type and existence. If type is
 * specified but a dataset of the same name but different type exists, returns
 * EEXIST, setting only type, indicating actual.
 */
int
lzc_objset_stats(const char *dataset, dmu_objset_type_t *type, nvlist_t **stats,
    nvlist_t **props)
{
	int ret;
	nvlist_t *args = NULL;
	nvlist_t *result;

	if (dataset == NULL)
		return (EINVAL);
	if (type != NULL) {
		args = fnvlist_alloc();
		fnvlist_add_uint8(args, "type", (uint8_t)*type);
	}
	ret = lzc_ioctl(ZFS_IOC_OBJSET_STATS_NVL, dataset, args, &result);
	if (args != NULL)
		nvlist_free(args);
	if (ret == 0) {
		if (stats != NULL)
			*stats = lzc_extract_nvl(result, "stats");
		if (props != NULL)
			*props = lzc_extract_nvl(result, "props");
	} else if (ret != EEXIST) {
		return (ret);
	}
	if (type != NULL)
		*type = fnvlist_lookup_uint8_t(result, "type");
	if (result != NULL)
		nvlist_free(result);

	return (ret);
}

boolean_t
lzc_exists(const char *dataset)
{
	/*
	 * The objset_stats ioctl is still legacy, so we need to construct our
	 * own zfs_cmd_t rather than using zfsc_ioctl().
	 */
	zfs_cmd_t zc = { 0 };

	(void) strlcpy(zc.zc_name, dataset, sizeof (zc.zc_name));
	return (ioctl(g_fd, ZFS_IOC_OBJSET_STATS, &zc) == 0);
}

boolean_t
lzc_has_snaps(const char *dataset)
{
	uint64_t offset = 0;
	return (lzc_snapshot_list_next(dataset, &offset, NULL, NULL, NULL));
}

/*
 * Create "user holds" on snapshots.  If there is a hold on a snapshot,
 * the snapshot can not be destroyed.  (However, it can be marked for deletion
 * by lzc_destroy_snaps(defer=B_TRUE).)
 *
 * The keys in the nvlist are snapshot names.
 * The snapshots must all be in the same pool.
 * The value is the name of the hold (string type).
 *
 * If cleanup_fd is not -1, it must be the result of open("/dev/zfs", O_EXCL).
 * In this case, when the cleanup_fd is closed (including on process
 * termination), the holds will be released.  If the system is shut down
 * uncleanly, the holds will be released when the pool is next opened
 * or imported.
 *
 * Holds for snapshots which don't exist will be skipped and have an entry
 * added to errlist, but will not cause an overall failure.
 *
 * The return value will be 0 if all holds, for snapshots that existed,
 * were succesfully created.
 *
 * Otherwise the return value will be the errno of a (unspecified) hold that
 * failed and no holds will be created.
 *
 * In all cases the errlist will have an entry for each hold that failed
 * (name = snapshot), with its value being the error code (int32).
 */
int
lzc_hold(nvlist_t *holds, int cleanup_fd, nvlist_t **errlist)
{
	char pool[MAXNAMELEN];
	nvlist_t *args;
	nvpair_t *elem;
	int error;

	/* determine the pool name */
	elem = nvlist_next_nvpair(holds, NULL);
	if (elem == NULL)
		return (0);
	(void) strlcpy(pool, nvpair_name(elem), sizeof (pool));
	pool[strcspn(pool, "/@")] = '\0';

	args = fnvlist_alloc();
	fnvlist_add_nvlist(args, "holds", holds);
	if (cleanup_fd != -1)
		fnvlist_add_int32(args, "cleanup_fd", cleanup_fd);

	error = lzc_ioctl(ZFS_IOC_HOLD, pool, args, errlist);
	nvlist_free(args);
	return (error);
}

/*
 * Release "user holds" on snapshots.  If the snapshot has been marked for
 * deferred destroy (by lzc_destroy_snaps(defer=B_TRUE)), it does not have
 * any clones, and all the user holds are removed, then the snapshot will be
 * destroyed.
 *
 * The keys in the nvlist are snapshot names.
 * The snapshots must all be in the same pool.
 * The value is a nvlist whose keys are the holds to remove.
 *
 * Holds which failed to release because they didn't exist will have an entry
 * added to errlist, but will not cause an overall failure.
 *
 * The return value will be 0 if the nvl holds was empty or all holds that
 * existed, were successfully removed.
 *
 * Otherwise the return value will be the errno of a (unspecified) hold that
 * failed to release and no holds will be released.
 *
 * In all cases the errlist will have an entry for each hold that failed to
 * to release.
 */
int
lzc_release(nvlist_t *holds, nvlist_t **errlist)
{
	char pool[MAXNAMELEN];
	nvpair_t *elem;

	/* determine the pool name */
	elem = nvlist_next_nvpair(holds, NULL);
	if (elem == NULL)
		return (0);
	(void) strlcpy(pool, nvpair_name(elem), sizeof (pool));
	pool[strcspn(pool, "/@")] = '\0';

	return (lzc_ioctl(ZFS_IOC_RELEASE, pool, holds, errlist));
}

/*
 * Retrieve list of user holds on the specified snapshot.
 *
 * On success, *holdsp will be set to a nvlist which the caller must free.
 * The keys are the names of the holds, and the value is the creation time
 * of the hold (uint64) in seconds since the epoch.
 */
int
lzc_get_holds(const char *snapname, nvlist_t **holdsp)
{
	int error;
	nvlist_t *innvl = fnvlist_alloc();
	error = lzc_ioctl(ZFS_IOC_GET_HOLDS, snapname, innvl, holdsp);
	fnvlist_free(innvl);
	return (error);
}

/*
 * If fromsnap is NULL, a full (non-incremental) stream will be sent.
 */
int
lzc_send(const char *snapname, const char *fromsnap, int fd)
{
	nvlist_t *args;
	int err;

	args = fnvlist_alloc();
	fnvlist_add_int32(args, "fd", fd);
	if (fromsnap != NULL)
		fnvlist_add_string(args, "fromsnap", fromsnap);
	err = lzc_ioctl(ZFS_IOC_SEND_NEW, snapname, args, NULL);
	nvlist_free(args);
	return (err);
}

/*
 * If fromsnap is NULL, a full (non-incremental) stream will be estimated.
 */
int
lzc_send_space(const char *snapname, const char *fromsnap, uint64_t *spacep)
{
	nvlist_t *args;
	nvlist_t *result;
	int err;

	args = fnvlist_alloc();
	if (fromsnap != NULL)
		fnvlist_add_string(args, "fromsnap", fromsnap);
	err = lzc_ioctl(ZFS_IOC_SEND_SPACE, snapname, args, &result);
	nvlist_free(args);
	if (err == 0)
		*spacep = fnvlist_lookup_uint64(result, "space");
	nvlist_free(result);
	return (err);
}

static int
recv_read(int fd, void *buf, int ilen)
{
	char *cp = buf;
	int rv;
	int len = ilen;

	do {
		rv = read(fd, cp, len);
		cp += rv;
		len -= rv;
	} while (rv > 0);

	if (rv < 0 || len != 0)
		return (EIO);

	return (0);
}

/*
 * The simplest receive case: receive from the specified fd, creating the
 * specified snapshot.  Apply the specified properties a "received" properties
 * (which can be overridden by locally-set properties).  If the stream is a
 * clone, its origin snapshot must be specified by 'origin'.  The 'force'
 * flag will cause the target filesystem to be rolled back or destroyed if
 * necessary to receive.
 *
 * Return 0 on success or an errno on failure.
 *
 * Note: this interface does not work on dedup'd streams
 * (those with DMU_BACKUP_FEATURE_DEDUP).
 */
int
lzc_receive(const char *snapname, nvlist_t *props, const char *origin,
    boolean_t force, int fd)
{
	/*
	 * The receive ioctl is still legacy, so we need to construct our own
	 * zfs_cmd_t rather than using zfsc_ioctl().
	 */
	zfs_cmd_t zc = { 0 };
	char *atp;
	char *packed = NULL;
	size_t size;
	dmu_replay_record_t drr;
	int error;

	ASSERT3S(g_refcount, >, 0);

	/* zc_name is name of containing filesystem */
	(void) strlcpy(zc.zc_name, snapname, sizeof (zc.zc_name));
	atp = strchr(zc.zc_name, '@');
	if (atp == NULL)
		return (EINVAL);
	*atp = '\0';

	/* if the fs does not exist, try its parent. */
	if (!lzc_exists(zc.zc_name)) {
		char *slashp = strrchr(zc.zc_name, '/');
		if (slashp == NULL)
			return (ENOENT);
		*slashp = '\0';

	}

	/* zc_value is full name of the snapshot to create */
	(void) strlcpy(zc.zc_value, snapname, sizeof (zc.zc_value));

	if (props != NULL) {
		/* zc_nvlist_src is props to set */
		packed = fnvlist_pack(props, &size);
		zc.zc_nvlist_src = (uint64_t)(uintptr_t)packed;
		zc.zc_nvlist_src_size = size;
	}

	/* zc_string is name of clone origin (if DRR_FLAG_CLONE) */
	if (origin != NULL)
		(void) strlcpy(zc.zc_string, origin, sizeof (zc.zc_string));

	/* zc_begin_record is non-byteswapped BEGIN record */
	error = recv_read(fd, &drr, sizeof (drr));
	if (error != 0)
		goto out;
	zc.zc_begin_record = drr.drr_u.drr_begin;

	/* zc_cookie is fd to read from */
	zc.zc_cookie = fd;

	/* zc guid is force flag */
	zc.zc_guid = force;

	/* zc_cleanup_fd is unused */
	zc.zc_cleanup_fd = -1;

	error = ioctl(g_fd, ZFS_IOC_RECV, &zc);
	if (error != 0)
		error = errno;

out:
	if (packed != NULL)
		fnvlist_pack_free(packed, size);
	free((void*)(uintptr_t)zc.zc_nvlist_dst);
	return (error);
}

/*
 * Roll back this filesystem or volume to its most recent snapshot.
 * If snapnamebuf is not NULL, it will be filled in with the name
 * of the most recent snapshot.
 *
 * Return 0 on success or an errno on failure.
 */
int
lzc_rollback(const char *fsname, char *snapnamebuf, int snapnamelen)
{
	nvlist_t *args;
	nvlist_t *result;
	int err;

	args = fnvlist_alloc();
	err = lzc_ioctl(ZFS_IOC_ROLLBACK, fsname, args, &result);
	nvlist_free(args);
	if (err == 0 && snapnamebuf != NULL) {
		const char *snapname = fnvlist_lookup_string(result, "target");
		(void) strlcpy(snapnamebuf, snapname, snapnamelen);
	}
	return (err);
}
