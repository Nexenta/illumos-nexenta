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
 */

#include <sys/param.h>
#include <sys/types.h>
#include <sys/systm.h>
#include <sys/cred.h>
#include <sys/buf.h>
#include <sys/vfs.h>
#include <sys/vnode.h>
#include <sys/uio.h>
#include <sys/errno.h>
#include <sys/sysmacros.h>
#include <sys/statvfs.h>
#include <sys/kmem.h>
#include <sys/dirent.h>
#include <rpc/types.h>
#include <rpc/auth.h>
#include <rpc/rpcsec_gss.h>
#include <rpc/svc.h>
#include <sys/strsubr.h>
#include <sys/strsun.h>
#include <sys/sdt.h>

#include <nfs/nfs.h>
#include <nfs/export.h>
#include <nfs/nfs4.h>
#include <nfs/nfs_cmd.h>

#include <nfs/nfs4_attrmap.h>
#include <nfs/nfs4_srv_readdir.h>
#include <nfs/nfs4_srv_attr.h>

/*
 * RFS4_MINLEN_ENTRY4: XDR-encoded size of smallest possible dirent.
 *	This is used to return NFS4ERR_TOOSMALL when clients specify
 *	maxcount that isn't large enough to hold the smallest possible
 *	XDR encoded dirent.
 *
 *	    sizeof cookie (8 bytes) +
 *	    sizeof name_len (4 bytes) +
 *	    sizeof smallest (padded) name (4 bytes) +
 *	    sizeof bitmap4_len (12 bytes) +   NOTE: we always encode len=2 bm4
 *	    sizeof attrlist4_len (4 bytes) +
 *	    sizeof next boolean (4 bytes)
 *
 * RFS4_MINLEN_RDDIR4: XDR-encoded size of READDIR op reply containing
 * the smallest possible entry4 (assumes no attrs requested).
 *	sizeof nfsstat4 (4 bytes) +
 *	sizeof verifier4 (8 bytes) +
 *	sizeof entsecond_to_ry4list bool (4 bytes) +
 *	sizeof entry4 	(36 bytes) +
 *	sizeof eof bool  (4 bytes)
 *
 * RFS4_MINLEN_RDDIR_BUF: minimum length of buffer server will provide to
 *	VOP_READDIR.  Its value is the size of the maximum possible dirent
 *	for solaris.  The DIRENT64_RECLEN macro returns	the size of dirent
 *	required for a given name length.  MAXNAMELEN is the maximum
 *	filename length allowed in Solaris.  The first two DIRENT64_RECLEN()
 *	macros are to allow for . and .. entries -- just a minor tweak to try
 *	and guarantee that buffer we give to VOP_READDIR will be large enough
 *	to hold ., .., and the largest possible solaris dirent64.
 */
#define	RFS4_MINLEN_ENTRY4 36
#define	RFS4_MINLEN_RDDIR4 (4 + NFS4_VERIFIER_SIZE + 4 + RFS4_MINLEN_ENTRY4 + 4)
#define	RFS4_MINLEN_RDDIR_BUF \
	(DIRENT64_RECLEN(1) + DIRENT64_RECLEN(2) + DIRENT64_RECLEN(MAXNAMELEN))


#ifdef	nextdp
#undef nextdp
#endif
#define	nextdp(dp)	((struct dirent64 *)((char *)(dp) + (dp)->d_reclen))

verifier4	Readdir4verf = 0x0;

nfs_ftype4 vt_to_nf4[] = {
	0, NF4REG, NF4DIR, NF4BLK, NF4CHR, NF4LNK, NF4FIFO, 0, 0, NF4SOCK, 0
};

attrmap4 rfs4_minimal_rd_attrmap = {RFS4_MINIMAL_RD_MASK, 0};
attrmap4 rfs4_minimal_rd_fileid_attrmap =
	{FATTR4_RDATTR_ERROR_MASK | FATTR4_FILEID_MASK, 0};
attrmap4 rfs4_minimal_rd_mntfileid_attrmap =
	{FATTR4_RDATTR_ERROR_MASK | FATTR4_MOUNTED_ON_FILEID_MASK, 0};

int
nfs4_readdir_getvp(vnode_t *dvp, char *d_name, vnode_t **vpp,
		struct exportinfo **exi, struct svc_req *req,
		struct compound_state *cs, int expseudo)
{
	int error;
	int ismntpt;
	fid_t fid;
	vnode_t *vp, *pre_tvp;
	nfsstat4 status;
	struct exportinfo *newexi, *saveexi;
	cred_t *scr;

	*vpp = vp = NULL;

	if (error = VOP_LOOKUP(dvp, d_name, &vp, NULL, 0, NULL, cs->cr,
	    NULL, NULL, NULL))
		return (error);

	/*
	 * If the directory is a referral point, don't return the
	 * attrs, instead set rdattr_error to MOVED.
	 */
	if (vn_is_nfs_reparse(vp, cs->cr) && !client_is_downrev(cs->instp, req)) {
		VN_RELE(vp);
		DTRACE_PROBE2(nfs4serv__func__referral__moved,
		    vnode_t *, vp, char *, "nfs4_readdir_getvp");
		return (NFS4ERR_MOVED);
	}

	/* Is this object mounted upon? */
	ismntpt = vn_ismntpt(vp);

	/*
	 * Nothing more to do if object is not a mount point or
	 * a possible LOFS shadow of an LOFS mount (which won't
	 * have v_vfsmountedhere set)
	 */
	if (ismntpt == 0 && dvp->v_vfsp == vp->v_vfsp && expseudo == 0) {
		*vpp = vp;
		return (0);
	}

	if (ismntpt) {
		/*
		 * Something is mounted here. Traverse and manage the
		 * namespace
		 */
		pre_tvp = vp;
		VN_HOLD(pre_tvp);

		if ((error = traverse(&vp)) != 0) {
			VN_RELE(pre_tvp);
			return (error);
		}
		if (vn_is_nfs_reparse(vp, cs->cr)) {
			VN_RELE(vp);
			VN_RELE(pre_tvp);
			DTRACE_PROBE2(nfs4serv__func__referral__moved,
			    vnode_t *, vp, char *, "nfs4_readdir_getvp");
			return (NFS4ERR_MOVED);
		}
	}

	bzero(&fid, sizeof (fid));
	fid.fid_len = MAXFIDSZ;

	/*
	 * If VOP_FID not supported by underlying fs (mntfs, procfs,
	 * etc.), then return attrs for stub instead of VROOT object.
	 * If it fails for any other reason, then return the error.
	 */
	if (error = VOP_FID(vp, &fid, NULL)) {
		if (ismntpt == 0) {
			VN_RELE(vp);
			return (error);
		}

		if (error != ENOSYS && error != ENOTSUP) {
			VN_RELE(vp);
			VN_RELE(pre_tvp);
			return (error);
		}
		/* go back to vnode that is "under" mount */
		VN_RELE(vp);
		*vpp = pre_tvp;
		return (0);
	}

	newexi = checkexport4(&vp->v_vfsp->vfs_fsid, &fid, vp);
	if (newexi == NULL) {
		if (ismntpt == 0) {
			*vpp = vp;
		} else {
			VN_RELE(vp);
			*vpp = pre_tvp;
		}
		return (0);
	}

	if (ismntpt)
		VN_RELE(pre_tvp);

	/* Save the exi and present the new one to checkauth4() */
	saveexi = cs->exi;
	cs->exi = newexi;

	/* Get the right cred like lookup does */
	scr = cs->cr;
	cs->cr = crdup(cs->basecr);

	status = call_checkauth4(cs, req);

	crfree(cs->cr);
	cs->cr = scr;
	cs->exi = saveexi;

	/* Reset what call_checkauth4() may have set */
	*cs->statusp = NFS4_OK;

	if (status != NFS4_OK) {
		VN_RELE(vp);
		if (status == NFS4ERR_DELAY)
			status = NFS4ERR_ACCESS;
		return (status);
	}
	*vpp = vp;
	*exi = newexi;

	return (0);
}

int
rfs4_get_pc_encode(vnode_t *vp, rfs4_pc_encode_t *pce, attrmap4 *ar, cred_t *cr)
{
	int error;
	ulong_t pc_val;

	pce->maxfilesize = 0;
	pce->maxlink = 0;
	pce->maxname = 0;

	if (ATTR_ISSET(*ar, MAXFILESIZE)) {
		/* Maximum File Size */
		error = VOP_PATHCONF(vp, _PC_FILESIZEBITS, &pc_val, cr, NULL);
		if (error)
			return (error);

		/*
		 * If the underlying file system does not support
		 * _PC_FILESIZEBITS, return a reasonable default. Note that
		 * error code on VOP_PATHCONF will be 0, even if the underlying
		 * file system does not support _PC_FILESIZEBITS.
		 */
		if (pc_val == (ulong_t)-1) {
			pce->maxfilesize = MAXOFF32_T;
		} else {
			if (pc_val >= (sizeof (uint64_t) * 8))
				pce->maxfilesize = INT64_MAX;
			else
				pce->maxfilesize = ((1LL << (pc_val - 1)) - 1);
		}
	}

	if (ATTR_ISSET(*ar, MAXLINK)) {
		/* Maximum Link Count */
		error = VOP_PATHCONF(vp, _PC_LINK_MAX, &pc_val, cr, NULL);
		if (error)
			return (error);

		pce->maxlink = pc_val;
	}

	if (ATTR_ISSET(*ar, MAXNAME)) {
		/* Maximum Name Length */
		error = VOP_PATHCONF(vp, _PC_NAME_MAX, &pc_val, cr, NULL);
		if (error)
			return (error);

		pce->maxname = pc_val;
	}

	return (0);
}

int
rfs4_get_sb_encode(vfs_t *vfsp, rfs4_sb_encode_t *psbe)
{
	int error;
	struct statvfs64 sb;

	/* Grab the per filesystem info */
	if (error = VFS_STATVFS(vfsp, &sb)) {
		return (error);
	}

	/* Calculate space available */
	if (sb.f_bavail != (fsblkcnt64_t)-1) {
		psbe->space_avail =
		    (fattr4_space_avail) sb.f_frsize *
		    (fattr4_space_avail) sb.f_bavail;
	} else {
		psbe->space_avail =
		    (fattr4_space_avail) sb.f_bavail;
	}

	/* Calculate space free */
	if (sb.f_bfree != (fsblkcnt64_t)-1) {
		psbe->space_free =
		    (fattr4_space_free) sb.f_frsize *
		    (fattr4_space_free) sb.f_bfree;
	} else {
		psbe->space_free =
		    (fattr4_space_free) sb.f_bfree;
	}

	/* Calculate space total */
	if (sb.f_blocks != (fsblkcnt64_t)-1) {
		psbe->space_total =
		    (fattr4_space_total) sb.f_frsize *
		    (fattr4_space_total) sb.f_blocks;
	} else {
		psbe->space_total =
		    (fattr4_space_total) sb.f_blocks;
	}

	/* For use later on attr encode */
	psbe->fa = sb.f_favail;
	psbe->ff = sb.f_ffree;
	psbe->ft = sb.f_files;

	return (0);
}

/*
 * If readdir only needs to return FILEID, we can take it from the
 * dirent struct and save doing the lookup.
 */
/* ARGSUSED */
void
rfs4_op_readdir(nfs_argop4 *argop, nfs_resop4 *resop,
	struct svc_req *req, struct compound_state *cs)
{
	READDIR4args *args = &argop->nfs_argop4_u.opreaddir;
	READDIR4res *resp = &resop->nfs_resop4_u.opreaddir;
	struct exportinfo *newexi = NULL;
	int error;
	mblk_t *mp;
	uint_t mpcount;
	int alloc_err = 0;
	vnode_t *dvp = cs->vp;
	vnode_t *vp;
	vattr_t va;
	struct dirent64 *dp;
	rfs4_sb_encode_t dsbe, sbe;
	int vfs_different;
	int rddir_data_len, rddir_result_size;
	caddr_t rddir_data;
	offset_t rddir_next_offset;
	int dircount;
	int no_space;
	int iseofdir;
	uint_t eof;
	struct iovec iov;
	struct uio uio;
	int tsize;
	int check_visible;
	int expseudo = 0;

	uint32_t *ptr, *ptr_redzone;
	uint32_t *beginning_ptr;
	uint32_t *lastentry_ptr;
	uint32_t attrmask_len;
	uint32_t *attrmask_ptr;
	uint32_t *attr_offset_ptr;
	uint32_t attr_length;
	uint32_t rndup;
	uint32_t namelen;
	uint32_t rddirattr_error = 0;
	int nents;
	attrmap4 ar;
	attrmap4 ae;
	attrmap4 minrddir;
	rfs4_pc_encode_t dpce, pce;
	ulong_t pc_val;
	uint64_t maxread;
	uint64_t maxwrite;
	uint_t true = TRUE;
	uint_t false = FALSE;
	uid_t lastuid;
	gid_t lastgid;
	int lu_set, lg_set;
	utf8string owner, group;
	int owner_error, group_error;
	struct sockaddr *ca;
	char *name = NULL;
	attrvers_t avers;

	DTRACE_NFSV4_2(op__readdir__start, struct compound_state *, cs,
	    READDIR4args *, args);

	avers = RFS4_ATTRVERS(cs);
	ar = args->attr_request;
	ATTRMAP_MASK(ar, RFS4_RDDIR_SUPP_ATTRMAP(avers));
	minrddir = ar;
	if (ATTR_ISSET(ar, MOUNTED_ON_FILEID)) {
		ATTRMAP_MASK(minrddir, RFS4_MINRDDIR_MNTFILEID(avers));
	} else {
		ATTRMAP_MASK(minrddir, RFS4_MINRDDIR_FILEID(avers));
	}

	lu_set = lg_set = 0;
	owner.utf8string_len = group.utf8string_len = 0;
	owner.utf8string_val = group.utf8string_val = NULL;

	resp->mblk = NULL;

	/* Maximum read and write size */
	maxread = maxwrite = rfs4_tsize(req);

	if (dvp == NULL) {
		*cs->statusp = resp->status = NFS4ERR_NOFILEHANDLE;
		goto out;
	}

	/*
	 * If there is an unshared filesystem mounted on this vnode,
	 * do not allow readdir in this directory.
	 */
	if (vn_ismntpt(dvp)) {
		*cs->statusp = resp->status = NFS4ERR_ACCESS;
		goto out;
	}

	if (dvp->v_type != VDIR) {
		*cs->statusp = resp->status = NFS4ERR_NOTDIR;
		goto out;
	}

	if (args->maxcount <= RFS4_MINLEN_RDDIR4) {
		*cs->statusp = resp->status = NFS4ERR_TOOSMALL;
		goto out;
	}

	/*
	 * If write-only attrs are requested, then fail the readdir op
	 */
	if (ATTR_ISSET(ar, TIME_MODIFY_SET) ||
	    ATTR_ISSET(ar, TIME_ACCESS_SET)) {
		*cs->statusp = resp->status = NFS4ERR_INVAL;
		goto out;
	}

	error = VOP_ACCESS(dvp, VREAD, 0, cs->cr, NULL);
	if (error) {
		*cs->statusp = resp->status = puterrno4(error);
		goto out;
	}

	if (args->cookieverf != Readdir4verf) {
		*cs->statusp = resp->status = NFS4ERR_NOT_SAME;
		goto out;
	}

	/* Is there pseudo-fs work that is needed for this readdir? */
	check_visible = PSEUDO(cs->exi) ||
	    ! is_exported_sec(cs->nfsflavor, cs->exi) ||
	    cs->access & CS_ACCESS_LIMITED;

	/* Check the requested attributes and only do the work if needed */

	if (ATTR_ISSET(ar, MAXFILESIZE) ||
	    ATTR_ISSET(ar, MAXLINK) ||
	    ATTR_ISSET(ar, MAXNAME)) {
		if (error = rfs4_get_pc_encode(cs->vp, &dpce, &ar, cs->cr)) {
			*cs->statusp = resp->status = puterrno4(error);
			goto out;
		}
		pce = dpce;
	}

	/* If there is statvfs data requested, pick it up once */
	if (ATTRMAP_TST(ar, RFS4_FS_SPACE_ATTRMAP(avers))) {
		if (error = rfs4_get_sb_encode(dvp->v_vfsp, &dsbe)) {
			*cs->statusp = resp->status = puterrno4(error);
			goto out;
		}
		sbe = dsbe;
	}

	/*
	 * Max transfer size of the server is the absolute limite.
	 * If the client has decided to max out with something really
	 * tiny, then return toosmall.  Otherwise, move forward and
	 * see if a single entry can be encoded.
	 */
	tsize = rfs4_tsize(req);
	if (args->maxcount > tsize)
		args->maxcount = tsize;
	else if (args->maxcount < RFS4_MINLEN_RDDIR_BUF) {
		if (args->maxcount < RFS4_MINLEN_ENTRY4) {
			*cs->statusp = resp->status = NFS4ERR_TOOSMALL;
			goto out;
		}
	}

	/*
	 * How large should the mblk be for outgoing encoding.
	 */
	if (args->maxcount < MAXBSIZE)
		mpcount = MAXBSIZE;
	else
		mpcount = args->maxcount;

	/*
	 * mp will contain the data to be sent out in the readdir reply.
	 * It will be freed after the reply has been sent.
	 * Let's roundup the data to a BYTES_PER_XDR_UNIX multiple,
	 * so that the call to xdrmblk_putmblk() never fails.
	 */
	mp = allocb(RNDUP(mpcount), BPRI_MED);

	if (mp == NULL) {
		/*
		 * The allocation of the client's requested size has
		 * failed.  It may be that the size is too large for
		 * current system utilization; step down to a "common"
		 * size and wait for the allocation to occur.
		 */
		if (mpcount > MAXBSIZE)
			args->maxcount = mpcount = MAXBSIZE;
		mp = allocb_wait(RNDUP(mpcount), BPRI_MED,
		    STR_NOSIG, &alloc_err);
	}

	ASSERT(mp != NULL);
	ASSERT(alloc_err == 0);

	resp->mblk = mp;

	ptr = beginning_ptr = (uint32_t *)mp->b_datap->db_base;

	/*
	 * The "redzone" at the end of the encoding buffer is used
	 * to deal with xdr encoding length.  Instead of checking
	 * each encoding of an attribute value before it is done,
	 * make the assumption that it will fit into the buffer and
	 * check occasionally.
	 *
	 * The largest block of attributes that are encoded without
	 * checking the redzone is 18 * BYTES_PER_XDR_UNIT (72 bytes)
	 * "round" to 128 as the redzone size.
	 */
	if (args->maxcount < (mpcount - 128))
		ptr_redzone =
		    (uint32_t *)(((char *)ptr) + RNDUP(args->maxcount));
	else
		ptr_redzone =
		    (uint32_t *)((((char *)ptr) + RNDUP(mpcount)) - 128);

	/*
	 * Set the dircount; this will be used as the size for the
	 * readdir of the underlying filesystem.  First make sure
	 * that it is large enough to do a reasonable readdir (client
	 * may have short changed us - it is an advisory number);
	 * then make sure that it isn't too large.
	 * After all of that, if maxcount is "small" then just use
	 * that for the dircount number.
	 */
	dircount = (args->dircount < MAXBSIZE) ? MAXBSIZE : args->dircount;
	dircount = (dircount > tsize) ? tsize : dircount;
	if (dircount > args->maxcount)
		dircount = args->maxcount;
	if (args->maxcount <= MAXBSIZE) {
		if (args->maxcount < RFS4_MINLEN_RDDIR_BUF)
			dircount = RFS4_MINLEN_RDDIR_BUF;
		else
			dircount = args->maxcount;
	}

	/* number of entries fully encoded in outgoing buffer */
	nents = 0;

	/* ENCODE READDIR4res.cookieverf */
	IXDR_PUT_HYPER(ptr, Readdir4verf);

	rddir_data_len = dircount;
	rddir_data = kmem_alloc(rddir_data_len, KM_NOSLEEP);
	if (rddir_data == NULL) {
		/* The allocation failed; downsize and wait for it this time */
		if (rddir_data_len > MAXBSIZE)
			rddir_data_len = dircount = MAXBSIZE;
		rddir_data = kmem_alloc(rddir_data_len, KM_SLEEP);
	}

	rddir_next_offset = (offset_t)args->cookie;

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;

readagain:

	no_space = FALSE;
	iseofdir = FALSE;

	vp = NULL;

	/* Move on to reading the directory contents */
	iov.iov_base = rddir_data;
	iov.iov_len = rddir_data_len;
	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_CACHED;
	uio.uio_loffset = rddir_next_offset;
	uio.uio_resid = rddir_data_len;

	(void) VOP_RWLOCK(dvp, V_WRITELOCK_FALSE, NULL);

	error = VOP_READDIR(dvp, &uio, cs->cr, &iseofdir, NULL, 0);

	VOP_RWUNLOCK(dvp, V_WRITELOCK_FALSE, NULL);

	if (error) {
		kmem_free((caddr_t)rddir_data, rddir_data_len);
		freeb(resp->mblk);
		resp->mblk = NULL;
		resp->data_len = 0;
		*cs->statusp = resp->status = puterrno4(error);
		goto out;
	}


	rddir_result_size = rddir_data_len - uio.uio_resid;

	/* No data were read. Check if we reached the end of the directory. */
	if (rddir_result_size == 0) {
		/* encode the BOOLEAN marking no further entries */
		IXDR_PUT_U_INT32(ptr, false);
		/* encode the BOOLEAN signifying end of directory */
		IXDR_PUT_U_INT32(ptr, iseofdir ? true : false);
		resp->data_len = (char *)ptr - (char *)beginning_ptr;
		resp->mblk->b_wptr += resp->data_len;
		kmem_free((caddr_t)rddir_data, rddir_data_len);
		*cs->statusp = resp->status = NFS4_OK;
		goto out;
	}

	lastentry_ptr = ptr;
	no_space = 0;
	for (dp = (struct dirent64 *)rddir_data;
	    !no_space && rddir_result_size > 0; dp = nextdp(dp)) {

		/* reset expseudo */
		expseudo = 0;

		if (vp) {
			VN_RELE(vp);
			vp = NULL;
		}

		if (newexi)
			newexi = NULL;

		rddir_result_size -= dp->d_reclen;

		/* skip "." and ".." entries */
		if (dp->d_ino == 0 || NFS_IS_DOTNAME(dp->d_name)) {
			rddir_next_offset = dp->d_off;
			continue;
		}

		if (check_visible &&
		    !nfs_visible_inode(cs->exi, dp->d_ino, &expseudo)) {
			rddir_next_offset = dp->d_off;
			continue;
		}

		/*
		 * Only if the client requested attributes...
		 * If the VOP_LOOKUP fails ENOENT, then skip this entry
		 * for the readdir response.  If there was another error,
		 * then set the rddirattr_error and the error will be
		 * encoded later in the "attributes" section.
		 */
		ae = ar;
		if (ATTRMAP_EMPTY(ar))
			goto reencode_attrs;

		error = nfs4_readdir_getvp(dvp, dp->d_name,
		    &vp, &newexi, req, cs, expseudo);
		if (error == ENOENT) {
			rddir_next_offset = dp->d_off;
			continue;
		}

		rddirattr_error = error;

		/*
		 * The vp obtained from above may be from a
		 * different filesystem mount and the vfs-like
		 * attributes should be obtained from that
		 * different vfs; only do this if appropriate.
		 */
		if (vp &&
		    (vfs_different =
		    (dvp->v_vfsp != vp->v_vfsp))) {	
			if (ATTRMAP_TST(ar,
			    RFS4_FS_SPACE_ATTRMAP(avers))) {
				if (error =
				    rfs4_get_sb_encode(dvp->v_vfsp,
				    &sbe)) {
					/* Remove attrs from encode */
					ATTRMAP_CLR(ae,
					    RFS4_FS_SPACE_ATTRMAP(
					    avers));
					rddirattr_error = error;
				}
				if (ATTR_ISSET(ar, MAXFILESIZE) ||
				    ATTR_ISSET(ar, MAXLINK) ||
				    ATTR_ISSET(ar, MAXNAME)) {
					if (error =
					    rfs4_get_pc_encode(cs->vp,
					    &pce, &ar, cs->cr)) {
						ATTR_CLR(ar, MAXFILESIZE);
						ATTR_CLR(ar, MAXLINK);
						ATTR_CLR(ar, MAXNAME);
						rddirattr_error = error;
					}
				}
			}
		}

reencode_attrs:
		/* encode the BOOLEAN for the existence of the next entry */
		IXDR_PUT_U_INT32(ptr, true);
		/* encode the COOKIE for the entry */
		IXDR_PUT_U_HYPER(ptr, dp->d_off);

		name = nfscmd_convname(ca, cs->exi, dp->d_name,
		    NFSCMD_CONV_OUTBOUND, MAXPATHLEN + 1);

		if (name == NULL) {
			rddir_next_offset = dp->d_off;
			continue;
		}
		/* Calculate the dirent name length */
		namelen = strlen(name);

		rndup = RNDUP(namelen) / BYTES_PER_XDR_UNIT;

		/* room for LENGTH + string ? */
		if ((ptr + (1 + rndup)) > ptr_redzone) {
			no_space = TRUE;
			continue;
		}

		/* encode the LENGTH of the name */
		IXDR_PUT_U_INT32(ptr, namelen);
		/* encode the RNDUP FILL first */
		ptr[rndup - 1] = 0;
		/* encode the NAME of the entry */
		bcopy(name, (char *)ptr, namelen);
		/* now bump the ptr after... */
		ptr += rndup;

		if (name != dp->d_name)
			kmem_free(name, MAXPATHLEN + 1);

		/*
		 * Keep checking on the dircount to see if we have
		 * reached the limit; from the RFC, dircount is to be
		 * the XDR encoded limit of the cookie plus name.
		 * So the count is the name, XDR_UNIT of length for
		 * that name and 2 * XDR_UNIT bytes of cookie;
		 * However, use the regular DIRENT64 to match most
		 * client's APIs.
		 */
		dircount -= DIRENT64_RECLEN(namelen);
		if (nents != 0 && dircount < 0) {
			no_space = TRUE;
			continue;
		}

		/*
		 * Attributes requested?
		 * Gather up the attribute info and the previous VOP_LOOKUP()
		 * succeeded; if an error occurs on the VOP_GETATTR() then
		 * return just the error (again if it is requested).
		 * Note that the previous VOP_LOOKUP() could have failed
		 * itself which leaves this code without anything for
		 * a VOP_GETATTR().
		 * Also note that the readdir_attr_error is left in the
		 * encoding mask if requested and so is the mounted_on_fileid.
		 */
		if (! ATTRMAP_EMPTY(ae)) {
			if (!vp) {
				ae = ar;
				ATTRMAP_MASK(ae,
				    RFS4_MINRDDIR_ATTRMAP(avers));
			} else {
				va.va_mask = AT_ALL;
				rddirattr_error =
				    VOP_GETATTR(vp, &va, 0, cs->cr, NULL);
				if (rddirattr_error) {
					ae = ar;
					ATTRMAP_MASK(ae,
					    RFS4_MINRDDIR_ATTRMAP(avers));
				} else {
					/*
					 * We may lie about the object
					 * type for a referral
					 */
					if (vn_is_nfs_reparse(vp, cs->cr) &&
					    client_is_downrev(cs->instp, req))
						va.va_type = VLNK;
				}
			}
		}

		/* START OF ATTRIBUTE ENCODING */

		/* encode the BITMAP4 */
		IXDR_PUT_FATTR4_BITMAP(ptr, ae, attrmask_ptr, attrmask_len,
		    avers);
		attr_offset_ptr = ptr;
		/* encode the default LENGTH of the attributes for entry */
		IXDR_PUT_U_INT32(ptr, 0);

		if (ptr > ptr_redzone) {
			no_space = TRUE;
			continue;
		}

		/* Check if any of the first 32 attributes are being encoded */
		if (ae.w.w0) {
			/*
			 * [SUPPORTED_ATTRS - RDATTR_ERROR]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 18 * BYTES_PER_XDR_UNIT of data
			 */
			if (ATTR_ISSET(ae, SUPPORTED_ATTRS)) {
				IXDR_PUT_BITMAP4(ptr,
				    RFS4_SUPP_ATTRMAP(avers));
			}
			if (ATTR_ISSET(ae, TYPE)) {
				uint_t ftype = vt_to_nf4[va.va_type];
				if (dvp->v_flag & V_XATTRDIR) {
					if (va.va_type == VDIR)
						ftype = NF4ATTRDIR;
					else
						ftype = NF4NAMEDATTR;
				}
				IXDR_PUT_U_INT32(ptr, ftype);
			}
			if (ATTR_ISSET(ae, FH_EXPIRE_TYPE)) {
				uint_t expire_type = FH4_PERSISTENT;
				IXDR_PUT_U_INT32(ptr, expire_type);
			}
			if (ATTR_ISSET(ae, CHANGE)) {
				u_longlong_t change;
				NFS4_SET_FATTR4_CHANGE(change,
				    va.va_ctime);
				IXDR_PUT_HYPER(ptr, change);
			}
			if (ATTR_ISSET(ae, SIZE)) {
				u_longlong_t size = va.va_size;
				IXDR_PUT_HYPER(ptr, size);
			}
			if (ATTR_ISSET(ae, LINK_SUPPORT)) {
				IXDR_PUT_U_INT32(ptr, true);
			}
			if (ATTR_ISSET(ae, SYMLINK_SUPPORT)) {
				IXDR_PUT_U_INT32(ptr, true);
			}
			if (ATTR_ISSET(ae, NAMED_ATTR)) {
				uint_t isit;
				int sattr_error;
				pc_val = FALSE;

				if (!(vp->v_vfsp->vfs_flag & VFS_XATTR)) {
					isit = FALSE;
				} else {
					sattr_error = VOP_PATHCONF(vp,
					    _PC_SATTR_EXISTS,
					    &pc_val, cs->cr, NULL);
					if (sattr_error || pc_val == 0)
						(void) VOP_PATHCONF(vp,
						    _PC_XATTR_EXISTS,
						    &pc_val,
						    cs->cr, NULL);
				}
				isit = (pc_val ? TRUE : FALSE);
				IXDR_PUT_U_INT32(ptr, isit);
			}
			if (ATTR_ISSET(ae, FSID)) {
				u_longlong_t major, minor;
				struct exportinfo *exi;

				exi = newexi ? newexi : cs->exi;
				if (exi->exi_volatile_dev) {
					int *pmaj = (int *)&major;

					pmaj[0] = exi->exi_fsid.val[0];
					pmaj[1] = exi->exi_fsid.val[1];
					minor = 0;
				} else {
					major = getmajor(va.va_fsid);
					minor = getminor(va.va_fsid);
				}
				IXDR_PUT_HYPER(ptr, major);
				IXDR_PUT_HYPER(ptr, minor);
			}
			if (ATTR_ISSET(ae, UNIQUE_HANDLES)) {
				IXDR_PUT_U_INT32(ptr, false);
			}
			if (ATTR_ISSET(ae, LEASE_TIME)) {
				uint_t lt = rfs4_lease_time;
				IXDR_PUT_U_INT32(ptr, lt);
			}
			if (ATTR_ISSET(ae, RDATTR_ERROR)) {
				rddirattr_error = (rddirattr_error == 0 ? 0 :
				    puterrno4(rddirattr_error));
				IXDR_PUT_U_INT32(ptr, rddirattr_error);
			}

			/*
			 * [SUPPORTED_ATTRS - RDATTR_ERROR]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}

			/*
			 * [ACL - CHOWN_RESTRICTED]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 4 * BYTES_PER_XDR_UNIT of data.
			 * NOTE: that if ACLs are supported that the
			 * redzone calculations will need to change.
			 */
			ASSERT(ATTR_ISSET(ae, ACL) == 0);
			ASSERT(ATTR_ISSET(ae, ACLSUPPORT) == 0);
			ASSERT(ATTR_ISSET(ae, ARCHIVE) == 0);

			if (ATTR_ISSET(ae, CANSETTIME)) {
				IXDR_PUT_U_INT32(ptr, true);
			}
			if (ATTR_ISSET(ae, CASE_INSENSITIVE)) {
				IXDR_PUT_U_INT32(ptr, false);
			}
			if (ATTR_ISSET(ae, CASE_PRESERVING)) {
				IXDR_PUT_U_INT32(ptr, true);
			}
			if (ATTR_ISSET(ae, CHOWN_RESTRICTED)) {
				uint_t isit;
				pc_val = FALSE;
				(void) VOP_PATHCONF(vp, _PC_CHOWN_RESTRICTED,
				    &pc_val, cs->cr, NULL);
				isit = (pc_val ? TRUE : FALSE);
				IXDR_PUT_U_INT32(ptr, isit);
			}
			/*
			 * [ACL - CHOWN_RESTRICTED]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}

			/*
			 * Redzone check is done before the filehandle
			 * is encoded.
			 */
			if (ATTR_ISSET(ae, FILEHANDLE)) {
				struct {
					uint_t len;
					char *val;
					char fh[NFS_FH4_LEN];
				} fh;
				fh.len = 0;
				fh.val = fh.fh;
				(void) makefh4((nfs_fh4 *)&fh, vp,
				    (newexi ? newexi : cs->exi));

				if (!xdr_inline_encode_nfs_fh4(
				    &ptr, ptr_redzone,
				    (nfs_fh4_fmt_t *)fh.val)) {
					if (nents ||
					    IS_MIN_ATTRMAP(ar)) {
						no_space = TRUE;
						continue;
					}
					MINIMIZE_ATTRMAP(ar, minrddir);
					ae = ar;
					ptr = lastentry_ptr;
					goto reencode_attrs;
				}
			}
			if (ATTR_ISSET(ae, FILEID)) {
				IXDR_PUT_HYPER(ptr, va.va_nodeid);
			}
			/*
			 * [FILEHANDLE - FILEID]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}

			/*
			 * [FILES_AVAIL - MAXWRITE]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 15 * BYTES_PER_XDR_UNIT of data.
			 */
			if (ATTR_ISSET(ae, FILES_AVAIL)) {
				IXDR_PUT_HYPER(ptr, sbe.fa);
			}
			if (ATTR_ISSET(ae, FILES_FREE)) {
				IXDR_PUT_HYPER(ptr, sbe.ff);
			}
			if (ATTR_ISSET(ae, FILES_TOTAL)) {
				IXDR_PUT_HYPER(ptr, sbe.ft);
			}
			ASSERT(ATTR_ISSET(ae, FS_LOCATIONS) == 0);
			ASSERT(ATTR_ISSET(ae, HIDDEN) == 0);

			if (ATTR_ISSET(ae, HOMOGENEOUS)) {
				IXDR_PUT_U_INT32(ptr, true);
			}
			if (ATTR_ISSET(ae, MAXFILESIZE)) {
				IXDR_PUT_HYPER(ptr, pce.maxfilesize);
			}
			if (ATTR_ISSET(ae, MAXLINK)) {
				IXDR_PUT_U_INT32(ptr, pce.maxlink);
			}
			if (ATTR_ISSET(ae, MAXNAME)) {
				IXDR_PUT_U_INT32(ptr, pce.maxname);
			}
			if (ATTR_ISSET(ae, MAXREAD)) {
				IXDR_PUT_HYPER(ptr, maxread);
			}
			if (ATTR_ISSET(ae, MAXWRITE)) {
				IXDR_PUT_HYPER(ptr, maxwrite);
			}
			/*
			 * [FILES_AVAIL - MAXWRITE]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}
		}

		if (ae.w.w1) {
			/*
			 * [MIMETYPE - NUMLINKS]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 3 * BYTES_PER_XDR_UNIT of data.
			 */
			if (ATTR_ISSET(ae, MIMETYPE) ||
			    ATTR_ISSET(ae, MODE) ||
			    ATTR_ISSET(ae, NO_TRUNC) ||
			    ATTR_ISSET(ae, NUMLINKS)) {

				ASSERT(ATTR_ISSET(ae, MIMETYPE) == 0);

				if (ATTR_ISSET(ae, MODE)) {
					uint_t m = va.va_mode;
					IXDR_PUT_U_INT32(ptr, m);
				}
				if (ATTR_ISSET(ae, NO_TRUNC)) {
					IXDR_PUT_U_INT32(ptr, true);
				}

				if (ATTR_ISSET(ae, NUMLINKS)) {
					IXDR_PUT_U_INT32(ptr, va.va_nlink);
				}
				/*
				 * [MIMETYPE - NUMLINKS]
				 * Check the redzone boundary
				 */
				if (ptr > ptr_redzone) {
					if (nents || IS_MIN_ATTRMAP(ar)) {
						no_space = TRUE;
						continue;
					}
					MINIMIZE_ATTRMAP(ar, minrddir);
					ae = ar;
					ptr = lastentry_ptr;
					goto reencode_attrs;
				}
			}
			/*
			 * OWNER
			 * Redzone check is done before the encoding of the
			 * owner string since the length is indeterminate.
			 */
			if (ATTR_ISSET(ae, OWNER)) {
				if (!lu_set) {
					owner_error =
					    nfs_idmap_uid_str(va.va_uid,
					    &owner, TRUE);
					if (!owner_error) {
						lu_set = TRUE;
						lastuid = va.va_uid;
					}
				} else if (va.va_uid != lastuid) {
					if (owner.utf8string_len != 0) {
						kmem_free(
						    owner.utf8string_val,
						    owner.utf8string_len);
						owner.utf8string_len = 0;
						owner.utf8string_val = NULL;
					}
					owner_error = nfs_idmap_uid_str(
					    va.va_uid, &owner, TRUE);
					if (!owner_error) {
						lastuid = va.va_uid;
					} else {
						lu_set = FALSE;
					}
				}
				if (!owner_error) {
					if ((ptr +
					    (owner.utf8string_len /
					    BYTES_PER_XDR_UNIT)
					    + 2) > ptr_redzone) {
						if (nents ||
						    IS_MIN_ATTRMAP(ar)) {
							no_space = TRUE;
							continue;
						}
						MINIMIZE_ATTRMAP(ar, minrddir);
						ae = ar;
						ptr = lastentry_ptr;
						goto reencode_attrs;
					}
					/* encode the LENGTH of owner string */
					IXDR_PUT_U_INT32(ptr,
					    owner.utf8string_len);
					/* encode the RNDUP FILL first */
					rndup = RNDUP(owner.utf8string_len) /
					    BYTES_PER_XDR_UNIT;
					ptr[rndup - 1] = 0;
					/* encode the OWNER */
					bcopy(owner.utf8string_val, ptr,
					    owner.utf8string_len);
					ptr += rndup;
				}
			}
			/*
			 * OWNER_GROUP
			 * Redzone check is done before the encoding of the
			 * group string since the length is indeterminate.
			 */
			if (ATTR_ISSET(ae, OWNER_GROUP)) {
				if (!lg_set) {
					group_error = nfs_idmap_gid_str(
					    va.va_gid, &group, TRUE);
					if (!group_error) {
						lg_set = TRUE;
						lastgid = va.va_gid;
					}
				} else if (va.va_gid != lastgid) {
					if (group.utf8string_len != 0) {
						kmem_free(
						    group.utf8string_val,
						    group.utf8string_len);
						group.utf8string_len = 0;
						group.utf8string_val = NULL;
					}
					group_error =
					    nfs_idmap_gid_str(va.va_gid,
					    &group, TRUE);
					if (!group_error)
						lastgid = va.va_gid;
					else
						lg_set = FALSE;
				}
				if (!group_error) {
					if ((ptr +
					    (group.utf8string_len /
					    BYTES_PER_XDR_UNIT)
					    + 2) > ptr_redzone) {
						if (nents ||
						    IS_MIN_ATTRMAP(ar)) {
							no_space = TRUE;
							continue;
						}
						MINIMIZE_ATTRMAP(ar, minrddir);
						ae = ar;
						ptr = lastentry_ptr;
						goto reencode_attrs;
					}
					/* encode the LENGTH of owner string */
					IXDR_PUT_U_INT32(ptr,
					    group.utf8string_len);
					/* encode the RNDUP FILL first */
					rndup = RNDUP(group.utf8string_len) /
					    BYTES_PER_XDR_UNIT;
					ptr[rndup - 1] = 0;
					/* encode the OWNER */
					bcopy(group.utf8string_val, ptr,
					    group.utf8string_len);
					ptr += rndup;
				}
			}

			ASSERT(ATTR_ISSET(ae, QUOTA_AVAIL_HARD) == 0);
			ASSERT(ATTR_ISSET(ae, QUOTA_AVAIL_SOFT) == 0);
			ASSERT(ATTR_ISSET(ae, QUOTA_USED) == 0);

			/*
			 * [RAWDEV - SYSTEM]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 10 * BYTES_PER_XDR_UNIT of data.
			 */
			if (ATTR_ISSET(ae, RAWDEV)) {
				fattr4_rawdev rd;
				rd.specdata1 = (uint32)getmajor(va.va_rdev);
				rd.specdata2 = (uint32)getminor(va.va_rdev);
				IXDR_PUT_U_INT32(ptr, rd.specdata1);
					IXDR_PUT_U_INT32(ptr, rd.specdata2);
			}
			if (ATTR_ISSET(ae, SPACE_AVAIL)) {
				IXDR_PUT_HYPER(ptr, sbe.space_avail);
			}
			if (ATTR_ISSET(ae, SPACE_FREE)) {
				IXDR_PUT_HYPER(ptr, sbe.space_free);
			}
			if (ATTR_ISSET(ae, SPACE_TOTAL)) {
				IXDR_PUT_HYPER(ptr, sbe.space_total);
			}
			if (ATTR_ISSET(ae, SPACE_USED)) {
				u_longlong_t su;
				su = (fattr4_space_used) DEV_BSIZE *
				    (fattr4_space_used) va.va_nblocks;
				IXDR_PUT_HYPER(ptr, su);
			}
			ASSERT(ATTR_ISSET(ae, SYSTEM) == 0);

			/*
			 * [RAWDEV - SYSTEM]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}

			/*
			 * [TIME_ACCESS - MOUNTED_ON_FILEID]
			 * Redzone check is done at the end of this section.
			 * This particular section will encode a maximum of
			 * 14 * BYTES_PER_XDR_UNIT of data.
			 */
			if (ATTR_ISSET(ae, TIME_ACCESS)) {
				u_longlong_t sec =
				    (u_longlong_t)va.va_atime.tv_sec;
				uint_t nsec = (uint_t)va.va_atime.tv_nsec;
				IXDR_PUT_HYPER(ptr, sec);
				IXDR_PUT_INT32(ptr, nsec);
			}
			ASSERT(ATTR_ISSET(ae, TIME_ACCESS_SET) == 0);
			ASSERT(ATTR_ISSET(ae, TIME_BACKUP) == 0);
			ASSERT(ATTR_ISSET(ae, TIME_CREATE) == 0);

			if (ATTR_ISSET(ae, TIME_DELTA)) {
				u_longlong_t sec = 0;
				uint_t nsec = 1000;
				IXDR_PUT_HYPER(ptr, sec);
				IXDR_PUT_INT32(ptr, nsec);
			}
			if (ATTR_ISSET(ae, TIME_METADATA)) {
				u_longlong_t sec =
				    (u_longlong_t)va.va_ctime.tv_sec;
				uint_t nsec = (uint_t)va.va_ctime.tv_nsec;
				IXDR_PUT_HYPER(ptr, sec);
				IXDR_PUT_INT32(ptr, nsec);
			}
			if (ATTR_ISSET(ae, TIME_MODIFY)) {
				u_longlong_t sec =
				    (u_longlong_t)va.va_mtime.tv_sec;
				uint_t nsec = (uint_t)va.va_mtime.tv_nsec;
				IXDR_PUT_HYPER(ptr, sec);
				IXDR_PUT_INT32(ptr, nsec);
			}
			ASSERT(ATTR_ISSET(ae, TIME_MODIFY_SET) == 0);

			if (ATTR_ISSET(ae, MOUNTED_ON_FILEID)) {
				IXDR_PUT_HYPER(ptr, dp->d_ino);
			}
			/*
			 * [TIME_ACCESS - MOUNTED_ON_FILEID]
			 * Check the redzone boundary
			 */
			if (ptr > ptr_redzone) {
				if (nents || IS_MIN_ATTRMAP(ar)) {
					no_space = TRUE;
					continue;
				}
				MINIMIZE_ATTRMAP(ar, minrddir);
				ae = ar;
				ptr = lastentry_ptr;
				goto reencode_attrs;
			}
		}

		/* Reset to directory's vfs info when encoding complete */
		if (vfs_different) {
			dsbe = sbe;
			dpce = pce;
			vfs_different = 0;
		}

		/* "go back" and encode the attributes' length */
		attr_length =
		    (char *)ptr -
		    (char *)attr_offset_ptr -
		    BYTES_PER_XDR_UNIT;
		IXDR_PUT_U_INT32(attr_offset_ptr, attr_length);

		/*
		 * If there was trouble obtaining a mapping for either
		 * the owner or group attributes, then remove them from
		 * bitmap4 for this entry and reset the bitmap value
		 * in the data stream.
		 */
		if (owner_error || group_error) {
			if (owner_error)
				ATTR_CLR(ae, OWNER);
			if (group_error)
				ATTR_CLR(ae, OWNER_GROUP);
			IXDR_REWRITE_FATTR4_BITMAP(attrmask_ptr, ae,
			    attrmask_len, avers);
		}

		/* END OF ATTRIBUTE ENCODING */

		lastentry_ptr = ptr;
		nents++;
		rddir_next_offset = dp->d_off;
	}

	/*
	 * Check for the case that another VOP_READDIR() has to be done.
	 * - no space encoding error
	 * - no entry successfully encoded
	 * - still more directory to read
	 */
	if (!no_space && nents == 0 && !iseofdir)
		goto readagain;

	*cs->statusp = resp->status = NFS4_OK;

	/*
	 * If no_space is set then we terminated prematurely,
	 * rewind to the last entry and this can never be EOF.
	 */
	if (no_space) {
		ptr = lastentry_ptr;
		eof = FALSE; /* ended encoded prematurely */
	} else {
		eof = (iseofdir ? TRUE : FALSE);
	}

	/*
	 * If we have entries, always return them, otherwise only error
	 * if we ran out of space.
	 */
	if (nents || !no_space) {
		ASSERT(ptr != NULL);
		/* encode the BOOLEAN marking no further entries */
		IXDR_PUT_U_INT32(ptr, false);
		/* encode the BOOLEAN signifying end of directory */
		IXDR_PUT_U_INT32(ptr, eof);

		resp->data_len = (char *)ptr - (char *)beginning_ptr;
		resp->mblk->b_wptr += resp->data_len;
	} else {
		freeb(mp);
		resp->mblk = NULL;
		resp->data_len = 0;
		*cs->statusp = resp->status = NFS4ERR_TOOSMALL;
	}

	kmem_free((caddr_t)rddir_data, rddir_data_len);
	if (vp)
		VN_RELE(vp);
	if (owner.utf8string_len != 0)
		kmem_free(owner.utf8string_val,	owner.utf8string_len);
	if (group.utf8string_len != 0)
		kmem_free(group.utf8string_val, group.utf8string_len);

out:
	DTRACE_NFSV4_2(op__readdir__done, struct compound_state *, cs,
	    READDIR4res *, resp);
}
