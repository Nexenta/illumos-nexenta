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
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 * Copyright 2011 Nexenta Systems, Inc. All rights reserved.
 */

#include <sys/rwlock.h>
#include <sys/vnode.h>

#include <nfs/nfs4.h>
#include <nfs/mds_odl.h>
#include <nfs/mds_state.h>
#include <nfs/nfs41_layout.h>
#include <nfs/nfs41_ds_addr.h>
#include <nfs/nfs_config.h>

/*
 * -----------------------------------------------
 * MDS: Layout tables.
 * -----------------------------------------------
 */

static mds_layout_t *mds_add_layout(layout_core_t *);
static void mds_delete_layout(vnode_t *);

static rfs4_table_t *layout_vnode_tab;
static rfs4_index_t *layout_vnode_idx;

struct layout_vnode {
	rfs4_dbe_t	*dbe;
	mds_layout_t	*layout;
	vnode_t		*vnode;
};

struct layout_arg {
	vnode_t		*la_vnode;
	layout_core_t	*la_lcore;
};

static uint32_t
mds_layout_hash(void *key)
{
	layout_core_t	*lc = (layout_core_t *)key;
	int		i;
	uint32_t	hash = 0;

	if (lc->lc_stripe_count == 0)
		return (0);

	/*
	 * Hash the first mds_sid
	 */
	for (i = 0; i < lc->lc_mds_sids[0].len; i++) {
		hash <<= 1;
		hash += (uint_t)lc->lc_mds_sids[0].val[i];
	}

	return (hash);
}

static bool_t
mds_layout_compare(rfs4_entry_t entry, void *key)
{
	mds_layout_t	*lp = (mds_layout_t *)entry;
	layout_core_t	*lc = (layout_core_t *)key;

	int		i;

	if (lc->lc_stripe_unit == lp->mlo_lc.lc_stripe_unit) {
		if (lc->lc_stripe_count ==
		    lp->mlo_lc.lc_stripe_count) {
			for (i = 0; i < lc->lc_stripe_count; i++) {
				if (lc->lc_mds_sids[i].len !=
				    lp->mlo_lc.lc_mds_sids[i].len) {
					return (0);
				}

				if (bcmp(lc->lc_mds_sids[i].val,
				    lp->mlo_lc.lc_mds_sids[i].val,
				    lc->lc_mds_sids[i].len)) {
					return (0);
				}
			}

			/*
			 * Everything matches!
			 */
			return (1);
		}
	}

	return (0);
}

static void *
mds_layout_mkkey(rfs4_entry_t entry)
{
	mds_layout_t *lp = (mds_layout_t *)entry;

	return ((void *)&lp->mlo_lc);
}

static uint32_t
mds_layout_id_hash(void *key)
{
	return ((uint32_t)(uintptr_t)key);
}

static bool_t
mds_layout_id_compare(rfs4_entry_t entry, void *key)
{
	mds_layout_t *lp = (mds_layout_t *)entry;

	return (lp->mlo_id == (int)(uintptr_t)key);
}

static void *
mds_layout_id_mkkey(rfs4_entry_t entry)
{
	mds_layout_t *lp = (mds_layout_t *)entry;

	return ((void *)(uintptr_t)lp->mlo_id);
}

typedef struct {
	uint32_t			id;
	nfsv4_1_file_layout_ds_addr4	*ds_addr4;
} mds_addmpd_t;

/*
 * ================================================================
 *	XXX: Both mds_gather_mds_sids and mds_gen_default_layout
 *	have been left in to support installations with no
 *	policies defined. In short, we do not force people to
 *	set up a policy system. Whenever the SMF portion of the
 *	code comes along, we will nuke these functions and
 *	force a real default to exist.
 *  ================================================================
 */

struct mds_gather_args {
	layout_core_t	lc;
	int 		found;
};

static void
mds_gather_mds_sids(rfs4_entry_t entry, void *arg)
{
	ds_guid_info_t		*pgi = (ds_guid_info_t *)entry;
	struct mds_gather_args	*gap = (struct mds_gather_args *)arg;

	int i, j;

	if (rfs4_dbe_skip_or_invalid(pgi->dbe))
		return;

	if (gap->found < gap->lc.lc_stripe_count) {
		/*
		 * Insert in order.
		 */
		for (i = 0; i < gap->found; i++) {
			if ((pgi->ds_guid.ds_guid_u.zfsguid.zfsguid_len <
			    gap->lc.lc_mds_sids[i].len) ||
			    (pgi->ds_guid.ds_guid_u.zfsguid.zfsguid_len ==
			    gap->lc.lc_mds_sids[i].len &&
			    bcmp(pgi->ds_guid.ds_guid_u.zfsguid.zfsguid_val,
			    gap->lc.lc_mds_sids[i].val,
			    gap->lc.lc_mds_sids[i].len) < 0)) {
				for (j = gap->found; j > i; j--) {
					gap->lc.lc_mds_sids[j].len =
					    gap->lc.lc_mds_sids[j - 1].len;
					gap->lc.lc_mds_sids[j - 1].val =
					    gap->lc.lc_mds_sids[j].val;
				}

				break;
			}
		}

		/*
		 * Either we found it and i is where it goes or we didn't
		 * find it and i is the tail. Either way, same thing happens!
		 */
		gap->lc.lc_mds_sids[i].len =
		    pgi->ds_guid.ds_guid_u.zfsguid.zfsguid_len;
		gap->lc.lc_mds_sids[i].val =
		    kmem_alloc(gap->lc.lc_mds_sids[i].len, KM_SLEEP);
		bcopy(pgi->ds_guid.ds_guid_u.zfsguid.zfsguid_val,
		    gap->lc.lc_mds_sids[i].val,
		    gap->lc.lc_mds_sids[i].len);

		gap->found++;
	}
}

int mds_default_stripe = 32;

mds_layout_t *
mds_gen_default_layout(nfs_server_instance_t *instp, vnode_t *vp)
{
	struct mds_gather_args	gap;
	mds_layout_t		*lp;
	int			i;
	int num = instp->ds_guid_info_count;

	bzero(&gap, sizeof (gap));

	gap.found = 0;

	rw_enter(&instp->ds_guid_info_lock, RW_READER);
	gap.lc.lc_stripe_count = num;
	rw_exit(&instp->ds_guid_info_lock);

	gap.lc.lc_mds_sids = kmem_zalloc(num * sizeof (mds_sid), KM_SLEEP);

	rw_enter(&instp->ds_guid_info_lock, RW_READER);
	rfs4_dbe_walk(instp->ds_guid_info_tab, mds_gather_mds_sids, &gap);
	rw_exit(&instp->ds_guid_info_lock);

	/*
	 * If we didn't find any devices then we do no service
	 */
	if (gap.found == 0) {
		kmem_free(gap.lc.lc_mds_sids, num * sizeof (mds_sid));
		return (NULL);
	}

	gap.lc.lc_stripe_count = gap.found;
	gap.lc.lc_stripe_unit = mds_default_stripe * 1024;

	lp = pnfs_add_mds_layout(vp, &gap.lc);

	for (i = 0; i < num; i++) {
		kmem_free(gap.lc.lc_mds_sids[i].val,
		    gap.lc.lc_mds_sids[i].len);
	}

	kmem_free(gap.lc.lc_mds_sids, num * sizeof (mds_sid));
	return (lp);
}

/* ================================================================ */


/*
 * Given a layout, which now is comprised of mds_dataset_ids, instead of
 * devices, generate the list of devices...
 */
static mds_mpd_t *
mds_gen_mpd(nfs_server_instance_t *instp, mds_layout_t *lp)
{
	nfsv4_1_file_layout_ds_addr4	ds_dev;

	/*
	 * The key to understanding the way these data structures
	 * interact is that map points to ds_dev. And map is stuck
	 * into the mds_mpd_idx database.
	 */
	mds_addmpd_t	map = { .id = 0, .ds_addr4 = &ds_dev };
	mds_mpd_t	*mp = NULL;
	uint_t		len;
	int		 i, iLoaded = 0;
	uint32_t	*sivp;
	multipath_list4	*mplp;

	ds_addrlist_t	**adp = NULL;

	ASSERT(instp->mds_mpd_id_space != NULL);
	map.id = id_alloc(instp->mds_mpd_id_space);

	/*
	 * build a nfsv4_1_file_layout_ds_addr4, encode it and
	 * cache it in state_store.
	 */
	len = lp->mlo_lc.lc_stripe_count;

	/* allocate space for the indices */
	sivp = ds_dev.nflda_stripe_indices.nflda_stripe_indices_val =
	    kmem_zalloc(len * sizeof (uint32_t), KM_SLEEP);

	ds_dev.nflda_stripe_indices.nflda_stripe_indices_len = len;

	/* populate the stripe indices */
	for (i = 0; i < len; i++)
		sivp[i] = i;

	/*
	 * allocate space for the multipath_list4 (for now we just
	 * have the one path)
	 */
	mplp = ds_dev.nflda_multipath_ds_list.nflda_multipath_ds_list_val =
	    kmem_zalloc(len * sizeof (multipath_list4), KM_SLEEP);

	ds_dev.nflda_multipath_ds_list.nflda_multipath_ds_list_len = len;

	adp = kmem_zalloc(len * sizeof (ds_addrlist_t *), KM_SLEEP);

	/*
	 * Now populate the netaddrs using the stashed ds_addr
	 * pointers
	 */
	for (i = 0; i < len; i++) {
		ds_addrlist_t	*dp;

		mplp[i].multipath_list4_len = 1;
		dp = mds_find_ds_addrlist_by_mds_sid(
		    &lp->mlo_lc.lc_mds_sids[i]);
		if (!dp) {
			iLoaded = i;
			goto cleanup;
		}

		mplp[i].multipath_list4_val = &dp->dev_addr;
		adp[i] = dp;
	}

	iLoaded = len;

	/*
	 * Add the multipath_list4, this will encode and cache
	 * the result.
	 */
	rw_enter(&instp->mds_mpd_lock, RW_WRITER);

	/*
	 * XXX: Each layout has its own mpd.
	 *
	 * Note that we should fix this....
	 */
	mp = (mds_mpd_t *)rfs4_dbcreate(instp->mds_mpd_idx, (void *)&map);
	if (mp) {
		lp->mlo_mpd_id = mp->mpd_id;

		/*
		 * Put the layout on the layouts list.
		 * Note that we don't decrement the refcnt
		 * here, we keep a hold on it for inserting
		 * this layout on it.
		 */
		list_insert_tail(&mp->mpd_layouts_list, lp);
	}

	rw_exit(&instp->mds_mpd_lock);

cleanup:

	for (i = 0; i < iLoaded; i++) {
		rfs4_dbe_rele(adp[i]->dbe);
	}

	kmem_free(adp, len * sizeof (ds_addrlist_t *));
	kmem_free(mplp, len * sizeof (multipath_list4));
	kmem_free(sivp, len * sizeof (uint32_t));

	if (mp == NULL)
		id_free(instp->mds_mpd_id_space, map.id);

	return (mp);
}

void
mds_nuke_layout(nfs_server_instance_t *instp, uint32_t mlo_id)
{
	bool_t create = FALSE;
	rfs4_entry_t e;

	rw_enter(&instp->mds_layout_lock, RW_WRITER);
	if ((e = rfs4_dbsearch(instp->mds_layout_ID_idx,
	    (void *)(uintptr_t)mlo_id,
	    &create,
	    NULL,
	    RFS4_DBS_VALID)) != NULL) {
		rfs4_dbe_invalidate(e->dbe);
		rfs4_dbe_rele(e->dbe);
	}
	rw_exit(&instp->mds_layout_lock);
}

/*ARGSUSED*/
static bool_t
mds_layout_create(rfs4_entry_t u_entry, void *arg)
{
	mds_layout_t	*lp = (mds_layout_t *)u_entry;
	layout_core_t	*lc = (layout_core_t *)arg;

	nfs_server_instance_t *instp;
	int i;
	bool_t rc = TRUE;

	instp = dbe_to_instp(lp->mlo_dbe);

	lp->mlo_id = rfs4_dbe_getid(lp->mlo_dbe);

	lp->mlo_type = LAYOUT4_NFSV4_1_FILES;
	lp->mlo_lc.lc_stripe_unit = lc->lc_stripe_unit;
	lp->mlo_lc.lc_stripe_count = lc->lc_stripe_count;

	lp->mlo_lc.lc_mds_sids = kmem_zalloc(lp->mlo_lc.lc_stripe_count *
	    sizeof (mds_sid), KM_SLEEP);

	for (i = 0; i < lp->mlo_lc.lc_stripe_count; i++) {
		lp->mlo_lc.lc_mds_sids[i].len = lc->lc_mds_sids[i].len;
		lp->mlo_lc.lc_mds_sids[i].val =
		    kmem_alloc(lp->mlo_lc.lc_mds_sids[i].len, KM_SLEEP);
		bcopy(lc->lc_mds_sids[i].val, lp->mlo_lc.lc_mds_sids[i].val,
		    lp->mlo_lc.lc_mds_sids[i].len);
	}

	/* Need to generate a device for this layout */
	lp->mlo_mpd = mds_gen_mpd(instp, lp);
	if (lp->mlo_mpd == NULL) {
		for (i = 0; i < lp->mlo_lc.lc_stripe_count; i++) {
			kmem_free(lp->mlo_lc.lc_mds_sids[i].val,
			    lp->mlo_lc.lc_mds_sids[i].len);
		}

		kmem_free(lp->mlo_lc.lc_mds_sids, lp->mlo_lc.lc_stripe_count *
		    sizeof (mds_sid));
		lp->mlo_lc.lc_mds_sids = NULL;
		rc = FALSE;
	}

	return (rc);
}

/*ARGSUSED*/
static void
mds_layout_destroy(rfs4_entry_t u_entry)
{
	mds_layout_t		*lp = (mds_layout_t *)u_entry;
	nfs_server_instance_t	*instp;
	int			i;

	instp = dbe_to_instp(u_entry->dbe);

	rw_enter(&instp->mds_mpd_lock, RW_WRITER);
	if (lp->mlo_mpd != NULL) {
		list_remove(&lp->mlo_mpd->mpd_layouts_list, lp);
		rfs4_dbe_rele(lp->mlo_mpd->mpd_dbe);
		lp->mlo_mpd = NULL;
	}
	rw_exit(&instp->mds_mpd_lock);

	if (lp->mlo_lc.lc_mds_sids != NULL) {
		for (i = 0; i < lp->mlo_lc.lc_stripe_count; i++) {
			kmem_free(lp->mlo_lc.lc_mds_sids[i].val,
			    lp->mlo_lc.lc_mds_sids[i].len);
		}

		kmem_free(lp->mlo_lc.lc_mds_sids, lp->mlo_lc.lc_stripe_count *
		    sizeof (mds_sid));
		lp->mlo_lc.lc_mds_sids = NULL;
	}
}

static mds_layout_t *
mds_add_layout(layout_core_t *lc)
{
	bool_t create = TRUE;
	mds_layout_t *lp;

	rw_enter(&mds_server->mds_layout_lock, RW_WRITER);

	lp = (mds_layout_t *)rfs4_dbsearch(mds_server->mds_layout_idx,
	    (void *)lc, &create, (void *)lc, RFS4_DBS_VALID);

	rw_exit(&mds_server->mds_layout_lock);

	if (lp == NULL) {
		printf("mds_add_layout: failed\n");
		(void) set_errno(EFAULT);
	}

	return (lp);
}

static char *
mds_read_odl(char *path, int *size)
{
	struct uio uio;
	struct iovec iov;

	char *odlp;
	vnode_t *vp;
	vattr_t va;
	int sz, err, bad_file;

	*size = 0;
	if (path == NULL)
		return (NULL);

	/*
	 * open the layout file.
	 */
	if ((err = vn_open(path, UIO_SYSSPACE, FREAD, 0, &vp, 0, 0)) != 0) {
		return (NULL);
	}

	if (vp->v_type != VREG) {
		(void) VOP_CLOSE(vp, FREAD, 1, (offset_t)0, CRED(), NULL);
		VN_RELE(vp);
		return (NULL);
	}

	(void) VOP_RWLOCK(vp, V_WRITELOCK_FALSE, NULL);

	/*
	 * get the file size.
	 */
	va.va_mask = AT_SIZE;
	err = VOP_GETATTR(vp, &va, 0, CRED(), NULL);

	sz = va.va_size;
	bad_file = (sz == 0 || sz < sizeof (odl_t));

	if (err || bad_file) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);
		(void) VOP_CLOSE(vp, FREAD, 1, (offset_t)0, CRED(), NULL);
		VN_RELE(vp);
		return (NULL);
	}

	odlp = kmem_alloc(sz, KM_SLEEP);

	/*
	 * build iovec to read in the file.
	 */
	iov.iov_base = (caddr_t)odlp;
	iov.iov_len = sz;

	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_loffset = 0;
	uio.uio_resid = iov.iov_len;

	if (err = VOP_READ(vp, &uio, FREAD, CRED(), NULL)) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);
		(void) VOP_CLOSE(vp, FREAD, 1, (offset_t)0, CRED(), NULL);
		VN_RELE(vp);
		kmem_free(odlp, sz);
		return (NULL);
	}

	VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);
	(void) VOP_CLOSE(vp, FREAD, 1, (offset_t)0, CRED(), NULL);
	VN_RELE(vp);
	*size = sz;

	return (odlp);
}

/*
 * blah
 */
static int
mds_write_odl(char *path, char *odlp, int size)
{
	int ioflag, err;
	struct uio uio;
	struct iovec iov;
	vnode_t *vp;

	if (path == NULL)
		return (-1);

	if (vn_open(path, UIO_SYSSPACE, FCREAT|FWRITE|FTRUNC, 0644, &vp,
	    CRCREAT, 0)) {
		return (-1);
	}

	iov.iov_base = (caddr_t)odlp;
	iov.iov_len = size;

	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_loffset = 0;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_llimit = (rlim64_t)MAXOFFSET_T;
	uio.uio_resid = size;

	ioflag = uio.uio_fmode = (FWRITE|FSYNC);
	uio.uio_extflg = UIO_COPY_DEFAULT;

	(void) VOP_RWLOCK(vp, V_WRITELOCK_TRUE, NULL);
	err = VOP_WRITE(vp, &uio, ioflag, CRED(), NULL);
	VOP_RWUNLOCK(vp, V_WRITELOCK_TRUE, NULL);

	(void) VOP_CLOSE(vp, FWRITE, 1, (offset_t)0, CRED(), NULL);
	VN_RELE(vp);

	return (err);
}

static void
mds_remove_odl(char *path)
{
	(void) vn_remove(path, UIO_SYSSPACE, RMFILE);
}

#define	ODL_DIR	"/var/nfs/v4_state/layouts"

int
mds_mkdir(char *parent, char *dirnm)
{
	int err;
	vnode_t *dvp, *vp;
	struct vattr vap;
	cred_t *cr = CRED();

/*
 *	if (err = lookupname(parent, UIO_SYSSPACE, NO_FOLLOW, NULLVPP, &dvp))
 */
	if ((err = vn_open(parent, UIO_SYSSPACE, FREAD, 0, &dvp, 0, 0)))
		return (1);

	vap.va_mask = AT_UID|AT_GID|AT_TYPE|AT_MODE;
	vap.va_uid = crgetuid(cr);
	vap.va_gid = crgetgid(cr);
	vap.va_type = VDIR;
	vap.va_mode = 0755;
	err = VOP_MKDIR(dvp, dirnm, &vap, &vp, cr, NULL, 0, NULL);

	(void) VOP_CLOSE(dvp, FREAD, 1, (offset_t)0, CRED(), NULL);
	VN_RELE(dvp);

	if (err)
		return (1);

	VN_RELE(vp);

	return (0);
}

/*
 * Pathname will be /var/nfs/v4_state/layouts/<fsid>/<fid>
 */
char *
mds_create_name(vnode_t *vp, int *len)
{
	static int parent_created = 0;
	int plen, err;
	fid_t fid;
	statvfs64_t svfs;
	vnode_t *dvp = NULL;
	uint64_t name = 0;
	char *pname;
	char dir[65];

	*len = 0;
	if (!parent_created) {
		if (vn_open(ODL_DIR, UIO_SYSSPACE, FREAD, 0, &dvp, 0, 0)) {
			err = mds_mkdir("/var/nfs/v4_state", "layouts");
			if (err)
				return (NULL);
		} else {
			(void) VOP_CLOSE(dvp, FREAD, 1, (offset_t)0,
			    CRED(), NULL);
			VN_RELE(dvp);
		}
		parent_created = 1;
	}

	/*
	 * fsid = vp->v_vfsp->vfs_fsid;
	 * zfs changes vfs_fsid on reboot, so we can't use it.
	 */
	err = VFS_STATVFS(vp->v_vfsp, &svfs);
	if (err) {
		return (NULL);
	}

	(void) snprintf(dir, 65, "%llx", (long long)svfs.f_fsid);

	plen = MAXPATHLEN;
	pname = kmem_alloc(plen, KM_SLEEP);
	(void) snprintf(pname, plen, "%s/%s", ODL_DIR, dir);

	/* does this dir already exist */
	if (vn_open(pname, UIO_SYSSPACE, FREAD, 0, &dvp, 0, 0)) {
		err = mds_mkdir(ODL_DIR, dir);
		if (err) {
			kmem_free(pname, plen);
			return (NULL);
		}
	} else {
		(void) VOP_CLOSE(dvp, FREAD, 1, (offset_t)0, CRED(), NULL);
		VN_RELE(dvp);
	}

	bzero(&fid, sizeof (fid));
	fid.fid_len = MAXFIDSZ;
	err = VOP_FID(vp, &fid, NULL);
	if (err || fid.fid_len == 0) {
		kmem_free(pname, plen);
		return (NULL);
	}

	bcopy(fid.fid_data, &name, fid.fid_len);

	(void) snprintf(pname, plen, "%s/%s/%llx", ODL_DIR, dir,
	    (long long)name);

	*len = plen;
	return (pname);
}

/* xdr encode a mds_layout to the on-disk layout */
static char *
xdr_convert_layout(mds_layout_t *lp, int *size)
{
	int xdr_size;
	char *xdr_buf;
	XDR xdr;
	odl on_disk;
	odl_t odlt;

	/* otw_flo.nfl_first_stripe_index hard coded to 0 */
	odlt.start_idx = 0;
	odlt.unit_size = lp->mlo_lc.lc_stripe_unit;

	/* offset and length are currently hard coded, as well */
	odlt.offset = 0;
	odlt.length = -1;

	odlt.sid.sid_len = lp->mlo_lc.lc_stripe_count;
	odlt.sid.sid_val = lp->mlo_lc.lc_mds_sids;

	on_disk.odl_type = PNFS;
	on_disk.odl_u.odl_pnfs.odl_vers = VERS_1;
	on_disk.odl_u.odl_pnfs.odl_lo_u.odl_content.odl_content_len = 1;
	on_disk.odl_u.odl_pnfs.odl_lo_u.odl_content.odl_content_val = &odlt;

	xdr_size = xdr_sizeof(xdr_odl, (char *)&on_disk);
	xdr_buf = kmem_zalloc(xdr_size, KM_SLEEP);

	xdrmem_create(&xdr, xdr_buf, xdr_size, XDR_ENCODE);

	if (xdr_odl(&xdr, &on_disk) == FALSE) {
		*size = 0;
		kmem_free(xdr_buf, xdr_size);
		return (NULL);
	}

	*size = xdr_size;
	return (xdr_buf);
}

/* xdr decode an on-disk layout to an odl struct */
/*ARGSUSED*/
static odl *
xdr_convert_odl(char *odlp, int size)
{
	int sz;
	char *unxdr_buf;
	XDR xdr;

	sz = sizeof (odl);
	unxdr_buf = kmem_zalloc(sz, KM_SLEEP);

	xdrmem_create(&xdr, odlp, size, XDR_DECODE);

	if (xdr_odl(&xdr, (odl *)unxdr_buf) == FALSE) {
		kmem_free(unxdr_buf, sz);
		return (NULL);
	}

	return ((odl *)unxdr_buf);
}

int
odl_already_written(char *name)
{
	vnode_t	*vp;

	ASSERT(name != NULL);

	if (vn_open(name, UIO_SYSSPACE, FREAD, 0, &vp, 0, 0))
		return (0);	/* does not exist */

	(void) VOP_CLOSE(vp, FREAD, 1, (offset_t)0, CRED(), NULL);
	VN_RELE(vp);
	return (1);	/* has already been written */
}

static int
mds_save_layout(mds_layout_t *lp, vnode_t *vp)
{
	char *odlp;
	char *name;
	int len, size, err;

	if (lp == NULL) {
		return (-2);
	}

	name = mds_create_name(vp, &len);
	if (name == NULL) {
		return (-1);
	}

	if (odl_already_written(name)) {
		kmem_free(name, len);
		return (0);
	}

	/* mythical xdr encode routine */
	odlp = xdr_convert_layout(lp, &size);
	if (odlp == NULL) {
		kmem_free(name, len);
		return (-1);
	}

	err = mds_write_odl(name, odlp, size);

	kmem_free(name, len);
	kmem_free(odlp, size);

	return (err);
}

int
mds_get_odl(vnode_t *vp, mds_layout_t **plp)
{
	char	*odlp;
	int	len, size;
	int	i;
	char	*name;

	mds_layout_t	*lp;
	layout_core_t	lc;

	odl	*on_disk;
	odl_t	*odlt;

	ASSERT(plp != NULL);

	name = mds_create_name(vp, &len);
	if (name == NULL)
		return (NFS4ERR_LAYOUTTRYLATER);

	odlp = mds_read_odl(name, &size);
	if (odlp == NULL) {
		kmem_free(name, len);
		return (NFS4ERR_LAYOUTTRYLATER);
	}

	/* the magic xdr decode routine */
	on_disk = xdr_convert_odl(odlp, size);

	kmem_free(name, len);
	kmem_free(odlp, size);

	if (on_disk == NULL)
		return (NFS4ERR_LAYOUTTRYLATER);

	odlt = on_disk->odl_u.odl_pnfs.odl_lo_u.odl_content.odl_content_val;

	lc.lc_stripe_unit = odlt->unit_size;
	lc.lc_stripe_count = odlt->sid.sid_len;
	lc.lc_mds_sids = odlt->sid.sid_val;

	lp = mds_add_layout(&lc);

	/* these were allocated by the xdr decode process */

	for (i = 0; i < odlt->sid.sid_len; i++) {
		kmem_free(odlt->sid.sid_val[i].val, odlt->sid.sid_val[i].len);
	}

	kmem_free(odlt->sid.sid_val, (odlt->sid.sid_len * sizeof (mds_sid)));
	kmem_free(odlt, sizeof (odl_t));
	kmem_free(on_disk, sizeof (odl));

	if (lp == NULL)
		return (NFS4ERR_LAYOUTTRYLATER);

	*plp = lp;

	return (NFS4_OK);
}

static void
mds_delete_layout(vnode_t *vp)
{
	int len;
	char *name;

	name = mds_create_name(vp, &len);
	if (name == NULL) {
		return;
	}

	mds_remove_odl(name);

	kmem_free(name, len);
}

void
mds_layout_get(mds_layout_t *l)
{
	rfs4_dbe_hold(l->mlo_dbe);
}

void
mds_layout_put(mds_layout_t *l)
{
	rfs4_dbe_rele(l->mlo_dbe);
}

/* Find vnode <-> layout */

/*
 * Get layout: get from cache or read from disk
 */

static struct layout_vnode *
lookup_layout_vnode(vnode_t *vp, layout_core_t *lc, bool_t *create)
{
	struct layout_vnode *lnode;
	struct layout_arg larg;
	rfs4_entry_t e;

	larg.la_vnode = vp;
	larg.la_lcore = lc;

	e = rfs4_dbsearch(layout_vnode_idx, vp, create, &larg, RFS4_DBS_VALID);
	if (e == NULL)
		return (NULL);

	lnode = (struct layout_vnode *)e;
	mds_layout_get(lnode->layout);

	return (lnode);
}

mds_layout_t *
pnfs_get_mds_layout(vnode_t *vp)
{
	struct layout_vnode *lnode;
	mds_layout_t *layout = NULL;
	bool_t yes = TRUE;

	lnode = lookup_layout_vnode(vp, NULL, &yes);
	if (lnode) {
		layout = lnode->layout;
		rfs4_dbe_rele(lnode->dbe);
	}

	return (layout);
}

mds_layout_t *
pnfs_add_mds_layout(vnode_t *vp, layout_core_t *lc)
{
	struct layout_vnode *lnode;
	mds_layout_t *layout = NULL;
	bool_t yes = TRUE;

	lnode = lookup_layout_vnode(vp, lc, &yes);
	if (lnode) {
		layout = lnode->layout;
		rfs4_dbe_rele(lnode->dbe);
	}

	/* If something fail, will try in checkstate */
	mds_save_layout(layout, vp);

	return (layout);
}

int
pnfs_save_mds_layout(mds_layout_t *layout, vnode_t *vp)
{
	int ret;

	ret = mds_save_layout(layout, vp);
	return (ret);
}

mds_layout_t *
pnfs_delete_mds_layout(vnode_t *vp)
{
	struct layout_vnode *lnode;
	mds_layout_t *layout = NULL;
	bool_t nocreate = FALSE;

	lnode = lookup_layout_vnode(vp, NULL, &nocreate);
	if (lnode) {
		layout = lnode->layout;
		rfs4_dbe_invalidate(lnode->dbe);
		rfs4_dbe_rele(lnode->dbe);
	}

	mds_delete_layout(vp);
	return (layout);
}

static bool_t
layout_vnode_create(rfs4_entry_t e, void *arg)
{
	struct layout_vnode *lnode = (struct layout_vnode *)e;
	struct layout_arg *larg = (struct layout_arg *)arg;
	layout_core_t *lcore;
	vnode_t *vp;
	int res;

	vp = larg->la_vnode;
	lcore = larg->la_lcore;

	if (lcore == NULL) {
		/* Read from disk */
		res = mds_get_odl(vp, &lnode->layout);
		if (res)
			return (FALSE);
	} else {
		mds_layout_t *layout;

		layout = mds_add_layout(lcore);
		if (layout == NULL)
			return (FALSE);

		/* refcnt was got early */
		lnode->layout = layout;
	}

	VN_HOLD(vp);
	lnode->vnode = vp;

	return (TRUE);
}

static void
layout_vnode_destroy(rfs4_entry_t e)
{
	struct layout_vnode *lnode = (struct layout_vnode *)e;

	VN_RELE(lnode->vnode);
	mds_layout_put(lnode->layout);
}

static void *
layout_vnode_mkkey(rfs4_entry_t e)
{
	struct layout_vnode *lnode = (struct layout_vnode *)e;

	return (lnode->vnode);
}

static uint32_t
layout_vnode_hash(void *key)
{
	return ((uint32_t)(uintptr_t)key);
}

static bool_t
layout_vnode_cmp(rfs4_entry_t e, void *key)
{
	struct layout_vnode *p = (struct layout_vnode *)e;

	return (p->vnode == key);
}

/*
 * Multipath devices.
 */
static uint32_t
mds_mpd_hash(void *key)
{
	return ((uint32_t)(uintptr_t)key);
}

static bool_t
mds_mpd_compare(rfs4_entry_t u_entry, void *key)
{
	mds_mpd_t *mp = (mds_mpd_t *)u_entry;

	return (mp->mpd_id == (id_t)(uintptr_t)key);
}

static void *
mds_mpd_mkkey(rfs4_entry_t u_entry)
{
	mds_mpd_t *mp = (mds_mpd_t *)u_entry;

	return ((void*)(uintptr_t)mp->mpd_id);
}

void
mds_mpd_encode(nfsv4_1_file_layout_ds_addr4 *ds_dev, uint_t *len, char **val)
{
	char *xdr_ds_dev;
	int  xdr_size = 0;
	XDR  xdr;

	ASSERT(val);

	xdr_size = xdr_sizeof(xdr_nfsv4_1_file_layout_ds_addr4, ds_dev);

	ASSERT(xdr_size);

	xdr_ds_dev = kmem_alloc(xdr_size, KM_SLEEP);

	xdrmem_create(&xdr, xdr_ds_dev, xdr_size, XDR_ENCODE);

	if (xdr_nfsv4_1_file_layout_ds_addr4(&xdr, ds_dev) == FALSE) {
		*len = 0;
		*val = NULL;
		kmem_free(xdr_ds_dev, xdr_size);
		return;
	}

	*len = xdr_size;
	*val = xdr_ds_dev;
}

/*ARGSUSED*/
static bool_t
mds_mpd_create(rfs4_entry_t u_entry, void *arg)
{
	mds_mpd_t *mp = (mds_mpd_t *)u_entry;
	mds_addmpd_t *maap = (mds_addmpd_t *)arg;

	mp->mpd_id = maap->id;
	mds_mpd_encode(maap->ds_addr4, &(mp->mpd_encoded_len),
	    &(mp->mpd_encoded_val));
	list_create(&mp->mpd_layouts_list, sizeof (mds_layout_t),
	    offsetof(mds_layout_t, mpd_layouts_next));

	return (TRUE);
}


/*ARGSUSED*/
static void
mds_mpd_destroy(rfs4_entry_t u_entry)
{
	mds_mpd_t		*mp = (mds_mpd_t *)u_entry;
	nfs_server_instance_t	*instp;

	instp = dbe_to_instp(u_entry->dbe);
	ASSERT(instp->mds_mpd_id_space != NULL);
	id_free(instp->mds_mpd_id_space, mp->mpd_id);

	kmem_free(mp->mpd_encoded_val, mp->mpd_encoded_len);

#ifdef	DEBUG
	/*
	 * We should never get here as the layouts
	 * entries should be holding a reference against
	 * this mpd!
	 */
	rw_enter(&instp->mds_mpd_lock, RW_WRITER);
	ASSERT(list_is_empty(&mp->mpd_layouts_list));
	rw_exit(&instp->mds_mpd_lock);
#endif
	list_destroy(&mp->mpd_layouts_list);
}

/*
 * The OTW device id is 128bits in length, we however are
 * still using a uint_32 internally.
 */
mds_mpd_t *
mds_find_mpd(nfs_server_instance_t *instp, id_t id)
{
	mds_mpd_t *mp;
	bool_t create = FALSE;

	mp = (mds_mpd_t *)rfs4_dbsearch(instp->mds_mpd_idx,
	    (void *)(uintptr_t)id, &create, NULL, RFS4_DBS_VALID);
	return (mp);
}

/*
 * Plop kernel deviceid into the 128bit OTW deviceid
 */
void
mds_set_deviceid(id_t did, deviceid4 *otw_id)
{
	ba_devid_t d;

	bzero(&d, sizeof (d));
	d.i.did = did;
	bcopy(&d, otw_id, sizeof (d));
}

/*
 * Used by the walker to populate the deviceid list.
 */
void
mds_mpd_list(rfs4_entry_t entry, void *arg)
{
	mds_mpd_t		*mp = (mds_mpd_t *)entry;
	mds_device_list_t	*mdl = (mds_device_list_t *)arg;

	deviceid4   *dlip;

	/*
	 * If this entry is invalid or we should skip it
	 * go to the next one..
	 */
	if (rfs4_dbe_skip_or_invalid(mp->mpd_dbe))
		return;

	dlip = &(mdl->mdl_dl[mdl->mdl_count]);

	mds_set_deviceid(mp->mpd_id, dlip);

	/*
	 * bump to the next devlist_item4
	 */
	mdl->mdl_count++;
}


/*
 * Multipath Device table.
 */
void
nfs41_device_init(nfs_server_instance_t *instp)
{
	uint32_t	maxentries = MDS_MAXTABSZ;
	id_t		start = 200;

	/*
	 * A mpd might be in use by many layouts. So, when one
	 * layout is done with a mpd, it can not invalidate the
	 * state. Also, as a mpd is created, it is immeadiately
	 * assigned to a layout, and thus the refcnt will stay at
	 * 2. Thus, if the refcnt is ever 1, that means no layout
	 * has a reference and as such, the entry can be reclaimed.
	 */
	instp->mds_mpd_tab = rfs4_table_create(instp,
	    "mpd", instp->reap_time, 1, mds_mpd_create,
	    mds_mpd_destroy, NULL,
	    sizeof (mds_mpd_t), MDS_TABSIZE, maxentries, start);

	instp->mds_mpd_idx = rfs4_index_create(instp->mds_mpd_tab,
	    "mpd-idx", mds_mpd_hash, mds_mpd_compare,
	    mds_mpd_mkkey, TRUE);

	if (MDS_MAXTABSZ + (uint32_t)start > (uint32_t)INT32_MAX)
		maxentries = INT32_MAX - start;

	instp->mds_mpd_id_space =
	    id_space_create("mds_mpd_id_space", start, maxentries + start);
}

void
nfs41_layout_init(nfs_server_instance_t *instp)
{
	/*
	 * pNFS layout table.
	 */
	rw_init(&instp->mds_layout_lock, NULL, RW_DEFAULT, NULL);

	/*
	 * A layout might be in use by many files. So, when one
	 * file is done with a layout, it can not invlaidate the
	 * state. Also, as a layout is created, it is immeadiately
	 * assigned to a file, and thus the refcnt will stay at
	 * 2. Thus, if the refcnt is ever 1, that means no file
	 * has a reference and as such, the entry can be reclaimed.
	 */
	instp->mds_layout_tab = rfs4_table_create(instp,
	    "Layout", instp->reap_time, 2, mds_layout_create,
	    mds_layout_destroy, NULL, sizeof (mds_layout_t),
	    MDS_TABSIZE, MDS_MAXTABSZ, 100);

	instp->mds_layout_idx = rfs4_index_create(instp->mds_layout_tab,
	    "layout-idx", mds_layout_hash, mds_layout_compare, mds_layout_mkkey,
	    TRUE);

	instp->mds_layout_ID_idx =
	    rfs4_index_create(instp->mds_layout_tab,
	    "layout-ID-idx", mds_layout_id_hash,
	    mds_layout_id_compare, mds_layout_id_mkkey, FALSE);

	instp->mds_layout_default_idx = 0;

	/*  For global searching layouts by vnode */
	layout_vnode_tab = rfs4_table_create(instp,
	    "Layout_vnode", instp->reap_time, 1, layout_vnode_create,
	    layout_vnode_destroy, NULL, sizeof (struct layout_vnode),
	    MDS_TABSIZE, MDS_MAXTABSZ, 100);

	layout_vnode_idx =
	    rfs4_index_create(layout_vnode_tab,
	    "Layout_vnode_idx", layout_vnode_hash,
	    layout_vnode_cmp, layout_vnode_mkkey, TRUE);
}
