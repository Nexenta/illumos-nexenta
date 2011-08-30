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

#include <nfs/nnode_vn.h>
#include <nfs/nnode_proxy.h>
#include <sys/vnode.h>
#include <sys/crc32.h>
#include <sys/nbmlock.h>
#include <sys/semaphore.h>

extern int nnode_vn_io_prep(void *, nnode_io_flags_t *, cred_t *,
    caller_context_t *, offset_t, size_t, bslabel_t *);
extern int nnode_vn_read(void *, nnode_io_flags_t *, cred_t *,
    caller_context_t *, uio_t *, int);
extern int nnode_vn_write(void *, nnode_io_flags_t *, uio_t *, int, cred_t *,
    caller_context_t *, wcc_data *);
extern void nnode_vn_io_release(void *, nnode_io_flags_t, caller_context_t *);
extern void nnode_vn_post_op_attr(void *, post_op_attr *);
extern void nnode_vn_wcc_data_err(void *, wcc_data *);
extern vnode_t *nnode_vn_io_getvp(void *);

static int nnode_proxy_read(void *vdata, nnode_io_flags_t *flags, cred_t *cr,
    caller_context_t *ct, uio_t *uiop, int ioflag);
static int nnode_proxy_write(void *vdata, nnode_io_flags_t *flags, uio_t *uiop,
    int ioflags, cred_t *cr, caller_context_t *ct, wcc_data *wcc);
static void nnode_proxy_data_free(void *vdata);
static void nnode_proxy_update(void *vdata, nnode_io_flags_t flags, cred_t *cr,
    caller_context_t *ct, off64_t off);

extern  bool_t xdr_DS_WRITEargs_send(XDR *, ds_write_t *);

static nnode_data_ops_t proxy_data_ops = {
	.ndo_io_prep = nnode_vn_io_prep,
	.ndo_read = nnode_proxy_read,
	.ndo_write = nnode_proxy_write,
	.ndo_update = nnode_proxy_update,
	.ndo_io_release = nnode_vn_io_release,
	.ndo_post_op_attr = nnode_vn_post_op_attr,
	.ndo_wcc_data_err = nnode_vn_wcc_data_err,
	.ndo_getvp = nnode_vn_io_getvp,
	.ndo_free = nnode_proxy_data_free
};

static kmem_cache_t *nnode_proxy_data_cache;

extern nfsstat4 mds_get_file_layout(vnode_t *, mds_layout_t **);

/* proxy I/O nnode ops */

/*ARGSUSED*/
static int
proxy_get_layout(nnode_proxy_data_t *mnd, mds_layout_t **lp)
{
	nfsstat4 stat;

	stat = mds_get_file_layout(mnd->mnd_vp, lp);
	if (*lp == NULL || stat != NFS4_OK)
		return (NFS4ERR_LAYOUTUNAVAILABLE);
	return (0);
}

/*ARGSUSED*/
void
proxy_free_layout(mds_layout_t *lp)
{
	rfs4_dbe_rele(lp->mlo_dbe);
}

/*
 * Prepare strategy pointed by @sp
 */
static int
proxy_init_strategy(nnode_proxy_data_t *mnd, const uio_t *uiop,
    const mds_layout_t *lp, mds_strategy_t *sp)
{
	int io_array_size;
	ds_io_t *io_array;
	uint64_t segstart, segend, relstart, maxsize;
	int i, segidx, startidx;
	offset_t offset;
	ssize_t len;
	unsigned int minreq = 0;

	bzero(sp, sizeof (mds_strategy_t));

	/*
	 * XXX
	 * When we have multiple layout segments per file, we need
	 * to find (from somewhere) the start and end offset for the
	 * segment we need, so that the code below can stay to the
	 * maximum limit. This is not currently in the mds_layout_t.
	 */
	segstart = 0;
	segend = -1;		/* to EOF */
	offset = uiop->uio_loffset;
	ASSERT(offset >= segstart);

	/*
	 * XXX
	 * We "know" (hard-code) the first index in the layout
	 * segment to be zero - this won't always be true.
	 * We should be able to find this in mds_layout_t, too.
	 */
	segidx = 0;

	/* Cap the length of the I/O to not spill over layout segment */
	len = uiop->uio_resid;
	if (segend != -1)
		len = MIN(offset + len, segend) - offset;

	/* Figure out first DS to hit */
	relstart = offset - segstart;
	startidx = (segidx + (relstart / lp->mlo_lc.lc_stripe_unit)) %
	    lp->mlo_lc.lc_stripe_count;

	/* Allocate space for our DS filehandles and devices */
	io_array_size = lp->mlo_lc.lc_stripe_count * sizeof (ds_io_t);
	io_array = kmem_zalloc(io_array_size, KM_SLEEP);

	sp->offset = offset;
	sp->len = len;
	sp->startidx = startidx;
	sp->stripe_unit = lp->mlo_lc.lc_stripe_unit;
	sp->stripe_count = 0;
	sp->io_array_size = io_array_size;
	sp->io_array = io_array;

	/* XXX - this is good for one big honking buffer. */
	/* Get our DS filehandles and dev descriptors */
	for (i = 0; i < lp->mlo_lc.lc_stripe_count; i++) {
		int e;
		unsigned int reqsz;

		e = mds_alloc_ds_fh(mnd->mnd_fsid, &mnd->mnd_fid,
		    &lp->mlo_lc.lc_mds_sids[i], &io_array[i].fh);
		if (e)
			return (NFS4ERR_LAYOUTTRYLATER);

		io_array[i].ds = mds_find_ds_addrlist_by_mds_sid(
		    &lp->mlo_lc.lc_mds_sids[i]);
		if (io_array[i].ds == NULL) {
			/* We can only cleanup a complete "row" */
			kmem_free(io_array[i].fh.nfs_fh4_val,
			    io_array[i].fh.nfs_fh4_len);
			return (NFS4ERR_LAYOUTUNAVAILABLE);
		}

		reqsz = io_array[i].ds->ds_owner->max_req_size;
		if (minreq > reqsz || minreq == 0)
			minreq = reqsz;

		/* Keep track of how many loaded error-free */
		sp->stripe_count++;
	}

	maxsize = minreq * sp->stripe_count;
	if (sp->len > maxsize)
		sp->len = maxsize;

	return (0);
}

void
proxy_free_strategy(mds_strategy_t *sp)
{
	int i;

	for (i = 0; i < sp->stripe_count; i++) {
		mds_ds_addrlist_rele(sp->io_array[i].ds);
		kmem_free(sp->io_array[i].fh.nfs_fh4_val,
		    sp->io_array[i].fh.nfs_fh4_len);
	}

	if (sp->io_array)
		kmem_free(sp->io_array, sp->io_array_size);
}

int ctl_mds_clnt_call(ds_addrlist_t *, rpcproc_t,
    xdrproc_t, void *, xdrproc_t, void *);

static struct trackerror {
	offset_t off;
	int len;
} trackerror;

extern int mds_layout_is_dense;

/*
 * Add a ds_fileseg to the request and a ds_filesegbuf to the response
 */
static void
add_read_record(uint64_t offset, int count, int stripewidth, int stripe_unit,
    char *where, DS_READargs *argp, DS_READres *resp) {
	ds_fileseg *segp;
	ds_filesegbuf *rsegp;

	segp = &argp->rdv.rdv_val[argp->rdv.rdv_len];
	rsegp = &resp->DS_READres_u.res_ok.rdv.rdv_val
	    [resp->DS_READres_u.res_ok.rdv.rdv_len];
	segp->offset = (offset / stripewidth)
	    * stripe_unit
	    + (offset % stripe_unit);
	segp->count = count;
	argp->rdv.rdv_len++;
	rsegp->data.data_val = where;
	resp->DS_READres_u.res_ok.rdv.rdv_len++;
	argp->count += count;
}

/*
 * Read a large (we hope) block of data by sending a single
 * multi-valued read request to each of N data servers.
 */
static int
proxy_do_read(uio_t *uiop, mds_strategy_t *sp, int *eof)
{
	int i, j, idx;			/* loop counters */
	int segs;			/* total segment count */
	int len, ask, remain, got;	/* request/result tracking */
	int io;				/* which iov in uio */
	int stripewidth;
	int error = 0;
	uint64_t ioffset, offset;
	char *base;
	ds_addrlist_t *dp;
	DS_READargs *argp;
	DS_READres *resp;
	ds_filesegbuf *dfp;

	/* Hard-coded for dense stripes since layout doesn't tell me */
	ASSERT(mds_layout_is_dense == 1);

	len = sp->len;

	/*
	 * Guess how many {offset,count} segments need to be allocated
	 */
	segs = (len / sp->stripe_unit) + uiop->uio_iovcnt + 1;
	stripewidth = sp->stripe_unit * sp->stripe_count;

	/*
	 * Set up filehandles and storage for args and results, one per DS
	 * The filehandle is copied to each DS_READargs.
	 */
	for (idx = 0; idx < sp->stripe_count; idx++) {
		argp = &sp->io_array[idx].ds_io_u.read.args;
		resp = &sp->io_array[idx].ds_io_u.read.res;
		argp->fh.nfs_fh4_len = sp->io_array[idx].fh.nfs_fh4_len;
		argp->fh.nfs_fh4_val = sp->io_array[idx].fh.nfs_fh4_val;
		argp->rdv.rdv_len = 0;
		argp->rdv.rdv_val =
		    kmem_alloc(segs * sizeof (ds_fileseg), KM_SLEEP);
		resp->DS_READres_u.res_ok.rdv.rdv_len = 0;
		resp->DS_READres_u.res_ok.rdv.rdv_val =
		    kmem_zalloc(segs * sizeof (ds_filesegbuf), KM_SLEEP);
	}

	/*
	 * Process each of the {offset,count} pairs
	 */
	ask = len;
	io = 0;
	base = uiop->uio_iov[0].iov_base;
	remain = uiop->uio_iov[0].iov_len;
	ioffset = offset = sp->offset;
	idx = sp->startidx;
	while (ask > 0) {
		int full, l = offset % sp->stripe_unit;

		argp = &sp->io_array[idx].ds_io_u.read.args;
		resp = &sp->io_array[idx].ds_io_u.read.res;

		/* How much do we ask for from this server? */
		full = MIN(ask, sp->stripe_unit - l);

		while (full > 0) {
			int count;

			/* How much do we ask for in this segment? */
			count = MIN(full, remain);

			ASSERT(argp->rdv.rdv_len < segs);
			add_read_record(offset, count, stripewidth,
			    sp->stripe_unit, base + (offset - ioffset),
			    argp, resp);

			offset += count;
			ask -= count;
			remain -= count;
			full -= count;

			ASSERT(ask >= 0);
			if (ask == 0)
				break;
			/*
			 * If we're out of room in this iov, move to next
			 */
			if (remain == 0) {
				io++;
				ASSERT(io < uiop->uio_iovcnt);
				base = uiop->uio_iov[io].iov_base;
				remain = uiop->uio_iov[io].iov_len;
				ioffset = offset;
			}
		}

		idx = ((idx + 1) % sp->stripe_count);
	}

	/*
	 * Send the RPCs
	 * XXX synchronous calls to start
	 */
	ask = len;
	idx = sp->startidx;
	for (i = 0; i < sp->stripe_count; i++) {
		dp = sp->io_array[idx].ds;
		argp = &sp->io_array[idx].ds_io_u.read.args;
		resp = &sp->io_array[idx].ds_io_u.read.res;

		if (argp->count == 0) {
			idx = ((idx + 1) % sp->stripe_count);
			continue;
		}

		error = ctl_mds_clnt_call(dp, DS_READ,
		    xdr_DS_READargs, argp,
		    xdr_DS_READres, resp);
		if (error)
			goto out;
		if (resp->status != DS_OK) {
			error = EIO;
			goto out;
		}

		if (resp->DS_READres_u.res_ok.eof == 1) {
			*eof = 1;
			goto out;
		}
		for (j = 0; j < resp->DS_READres_u.res_ok.rdv.rdv_len; j++) {
			dfp = &resp->DS_READres_u.res_ok.rdv.rdv_val[j];
			if (!dfp) {
				error = EIO;
				goto out;
			}
			got = dfp->data.data_len;
			ask -= got;
			uiop->uio_resid -= got;
			ASSERT(ask >= 0);
			if (ask == 0)
				goto out;
		}
		idx = ((idx + 1) % sp->stripe_count);
	}
out:
	for (idx = 0; idx < sp->stripe_count; idx++) {
		argp = &sp->io_array[idx].ds_io_u.read.args;
		resp = &sp->io_array[idx].ds_io_u.read.res;
		kmem_free(argp->rdv.rdv_val, segs * sizeof (ds_fileseg));
		kmem_free(resp->DS_READres_u.res_ok.rdv.rdv_val,
		    segs * sizeof (ds_filesegbuf));
	}
	return (error);
}

static int
nnode_proxy_read(void *vdata, nnode_io_flags_t *flags, cred_t *cr,
    caller_context_t *ct, uio_t *uiop, int ioflag)
{
	nnode_proxy_data_t *mnd = vdata;
	vnode_t *vp = mnd->mnd_vp;
	vattr_t *vap = &mnd->mnd_vattr;
	mds_strategy_t sp;
	mds_layout_t *lp;
	uint64_t off;
	uint64_t moved;
	int rc, eof = 0;

	ASSERT((*flags & (NNODE_IO_FLAG_WRITE | NNODE_IO_FLAG_EOF)) == 0);

	off = uiop->uio_loffset;
	moved = uiop->uio_resid;

	mutex_enter(&mnd->mnd_lock);
	rc = proxy_get_layout(mnd, &lp);
	if (rc != 0) {
		mutex_exit(&mnd->mnd_lock);
		return (NFS4ERR_IO);
	}
	rc = proxy_init_strategy(mnd, uiop, lp, &sp);
	if (rc != 0)
		goto out;

	rc = proxy_do_read(uiop, &sp, &eof);
	if (rc != 0)
		goto out;

	moved -= uiop->uio_resid;

	vap->va_mask = AT_ALL;
	rc = VOP_GETATTR(vp, vap, 0, cr, ct);
	if (rc != 0) {
		mnd->mnd_flags &= ~NNODE_NVD_VATTR_VALID;
		goto out;
	}
	mnd->mnd_flags |= NNODE_NVD_VATTR_VALID;

	if (off + moved == vap->va_size || eof)
		*flags |= NNODE_IO_FLAG_EOF;
	else
		*flags &= ~NNODE_IO_FLAG_EOF;
out:
	proxy_free_strategy(&sp);
	proxy_free_layout(lp);
	mutex_exit(&mnd->mnd_lock);
	return (rc);
}

/*
 * Add iovec to the request
 */
static void
add_write_record(int count, char *where, ds_write_t *wr) {
	struct iovec *iov;

	iov = &wr->iov[wr->iov_count];
	iov->iov_len = count;
	iov->iov_base = where;

	wr->iov_count++;
	wr->count += count;
}

static int
proxy_do_write(uio_t *uiop, mds_strategy_t *sp)
{
	int i, idx;			/* loop counters */
	int segs;			/* total segment count */
	int len, ask, remain;		/* request/result tracking */
	int io;				/* which iov in uio */
	int stripewidth;
	int error = 0;
	uint64_t ioffset, offset;
	char *base;
	ds_addrlist_t *dp;

	/* Hard-coded for dense stripes since layout doesn't tell me */
	ASSERT(mds_layout_is_dense == 1);

	len = sp->len;

	/*
	 * Guess how many {offset,count} segments need to be
	 * doled out to sp->stripe_count sets of args.
	 */
	segs = (len / sp->stripe_unit) + uiop->uio_iovcnt + 1;
	stripewidth = sp->stripe_unit * sp->stripe_count;

	/*
	 * Set up filehandles and storage for args and results, one per DS
	 * The filehandle is copied to each DS_WRITEargs.
	 */
	offset = sp->offset;
	idx = sp->startidx;
	for (i = 0; i < sp->stripe_count; i++) {
		DS_WRITEargs *argp;
		ds_write_t *wr = &sp->io_array[idx].ds_io_u.write;
		uint64_t n;
		int l;

		n = offset / stripewidth;
		l = offset % sp->stripe_unit;

		argp = &wr->args;
		argp->offset = n * sp->stripe_unit + l;

		argp->fh.nfs_fh4_len = sp->io_array[idx].fh.nfs_fh4_len;
		argp->fh.nfs_fh4_val = sp->io_array[idx].fh.nfs_fh4_val;
		wr->iov = kmem_alloc(segs * sizeof (struct iovec), KM_SLEEP);

		/* switch offset to next DS */
		offset += sp->stripe_unit - l;
		idx = ((idx + 1) % sp->stripe_count);
	}

	/*
	 * Process each of the {offset,count} pairs
	 */
	ask = len;
	io = 0;
	base = uiop->uio_iov[0].iov_base;
	remain = uiop->uio_iov[0].iov_len;
	ioffset = offset = sp->offset;
	idx = sp->startidx;
	while (ask > 0) {
		ds_write_t *wr;
		int full, l = offset % sp->stripe_unit;

		wr = &sp->io_array[idx].ds_io_u.write;

		/* How much do we ask for from this DS? */
		full = MIN(ask, sp->stripe_unit - l);

		while (full > 0) {
			int count;

			/* How much do we ask for in this segment? */
			count = MIN(full, remain);

			ASSERT(wr->iov_count < segs);
			add_write_record(count, base + (offset - ioffset), wr);

			offset += count;
			ask -= count;
			remain -= count;
			full -= count;

			ASSERT(ask >= 0);
			if (ask == 0)
				break;
			/*
			 * If we're out of room in this iov, move to next
			 */
			if (remain == 0) {
				io++;
				ASSERT(io < uiop->uio_iovcnt);
				base = uiop->uio_iov[io].iov_base;
				remain = uiop->uio_iov[io].iov_len;
				ioffset = offset;
			}
		}

		idx = ((idx + 1) % sp->stripe_count);
	}

	/*
	 * Send the RPCs
	 * XXX synchronous calls to start
	 */
	ask = len;
	idx = sp->startidx;
	for (i = 0; i < sp->stripe_count; i++) {
		DS_WRITEres *resp;
		ds_write_t *wr;
		unsigned int sent;

		wr = &sp->io_array[idx].ds_io_u.write;
		resp = &wr->res;
		dp = sp->io_array[idx].ds;

		if (wr->count == 0) {
			idx = ((idx + 1) % sp->stripe_count);
			continue;
		}

		error = ctl_mds_clnt_call(dp, DS_WRITE,
		    xdr_DS_WRITEargs_send, wr,
		    xdr_DS_WRITEres, resp);
		if (error)
			goto out;
		if (resp->status != DS_OK) {
			error = EIO;
			goto out;
		}

		sent = resp->DS_WRITEres_u.res_ok.written;
		if (sent > wr->count)
			sent = wr->count;
		uiop->uio_resid -= sent;

		idx = ((idx + 1) % sp->stripe_count);
	}
out:
	for (i = 0; i < sp->stripe_count; i++) {
		ds_write_t *wr;

		wr = &sp->io_array[i].ds_io_u.write;
		kmem_free(wr->iov, segs * sizeof (struct iovec));
	}
	return (error);
}

static int
nnode_proxy_write(void *vdata, nnode_io_flags_t *flags, uio_t *uiop,
    int ioflags, cred_t *cr, caller_context_t *ct, wcc_data *wcc)
{
	nnode_proxy_data_t *mnd = vdata;
	vnode_t *vp = mnd->mnd_vp;
	vattr_t *vap = &mnd->mnd_vattr;
	mds_strategy_t sp;
	mds_layout_t *lp;
	vattr_t before, *beforep, *afterp;
	uint64_t off;
	uint64_t moved;
	int rc;

	ASSERT(*flags & NNODE_IO_FLAG_WRITE);

	off = uiop->uio_loffset;
	moved = uiop->uio_resid;

	mutex_enter(&mnd->mnd_lock);
	rc = proxy_get_layout(mnd, &lp);
	if (rc != 0) {
		mutex_exit(&mnd->mnd_lock);
		return (NFS4ERR_IO);
	}

	rc = proxy_init_strategy(mnd, uiop, lp, &sp);
	if (rc != 0)
		goto out;

	rc = proxy_do_write(uiop, &sp);
	if (rc != 0)
		goto out;

	moved -= uiop->uio_resid;

	if (wcc != NULL) {
		if (mnd->mnd_flags & NNODE_NVD_VATTR_VALID) {
			bcopy(&mnd->mnd_vattr, &before, sizeof (before));
			beforep = &before;
		} else {
			beforep = NULL;
		}
	}
	vap->va_mask = AT_ALL;
	if (VOP_GETATTR(vp, vap, 0, cr, ct) == 0) {
		mnd->mnd_flags |= NNODE_NVD_VATTR_VALID;
		afterp = &mnd->mnd_vattr;
	} else {
		mnd->mnd_flags &= ~NNODE_NVD_VATTR_VALID;
		afterp = NULL;
	}
	if (wcc != NULL) {
		if ((beforep != NULL) && ((beforep->va_mask &
		    (AT_SIZE | AT_MTIME | AT_SEQ)) !=
		    (AT_SIZE | AT_MTIME | AT_SEQ)))
			beforep = NULL;
		if ((beforep != NULL) && (afterp != NULL) &&
		    (beforep->va_seq + 1 != afterp->va_seq))
			beforep = NULL;
		vattr_to_wcc_data(beforep, afterp, wcc);
	}

	if (off + moved == vap->va_size)
		*flags |= NNODE_IO_FLAG_EOF;
	else
		*flags &= ~NNODE_IO_FLAG_EOF;

out:
	proxy_free_strategy(&sp);
	proxy_free_layout(lp);
	mutex_exit(&mnd->mnd_lock);
	return (rc);
}

/*ARGSUSED*/
static void
nnode_proxy_update(void *vdata, nnode_io_flags_t flags, cred_t *cr,
    caller_context_t *ct, off64_t off)
{
	nnode_proxy_data_t *mnd = vdata;
	vnode_t *vp = mnd->mnd_vp;
	vattr_t *vap = &mnd->mnd_vattr;
	uio_t uio;
	iovec_t iov;
	char null_byte;

	if (off <= vap->va_size)
		return;

	/*
	 * Modelled from mds_op_layout_commit()
	 *
	 * write a null byte at off-1 so that the size is correct.
	 * VOP_SETATTR may fail if the mode of the file is restrictive.
	 */
	null_byte = '\0';
	iov.iov_base = &null_byte;
	iov.iov_len = 1;

	bzero(&uio, sizeof (uio));
	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_offset = off - 1;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_fmode = FWRITE;
	uio.uio_extflg = 0;
	uio.uio_limit = off;
	uio.uio_resid = 1;

	(void) VOP_WRITE(vp, &uio, FWRITE, cr, ct);
}

static nnode_proxy_data_t *
nnode_proxy_data_alloc(void)
{
	nnode_proxy_data_t *rc;

	rc = kmem_cache_alloc(nnode_proxy_data_cache, KM_SLEEP);
	rc->mnd_vp = NULL;
	rc->mnd_flags = 0;

	return (rc);
}

static void
nnode_proxy_data_free(void *vdata)
{
	nnode_proxy_data_t *mnd = vdata;

	if (mnd->mnd_vp)
		VN_RELE(mnd->mnd_vp);

	kmem_cache_free(nnode_proxy_data_cache, mnd);
}

void
nnode_proxy_data_setup(nnode_seed_t *seed, vnode_t *vp, fsid_t fsid,
    int len, char *fid)
{
	nnode_proxy_data_t *pdata;

	pdata = nnode_proxy_data_alloc();
	pdata->mnd_vp = vp;
	pdata->mnd_fsid = fsid;
	pdata->mnd_fid.len = len;
	ASSERT(fid);
	bcopy(fid, pdata->mnd_fid.val, len);
	/* no need to VN_HOLD; we steal the reference */
	seed->ns_data = pdata;
	seed->ns_data_ops = &proxy_data_ops;
}

/*ARGSUSED*/
static int
nnode_proxy_data_construct(void *vdata, void *foo, int bar)
{
	nnode_proxy_data_t *mnd = vdata;

	mutex_init(&mnd->mnd_lock, NULL, MUTEX_DEFAULT, NULL);

	return (0);
}

/*ARGSUSED*/
static void
nnode_proxy_data_destroy(void *vdata, void *foo)
{
	nnode_proxy_data_t *mnd = vdata;

	mutex_destroy(&mnd->mnd_lock);
}

void
nnode_proxy_init(void)
{
	nnode_proxy_data_cache = kmem_cache_create("nnode_proxy_data_cache",
	    sizeof (nnode_proxy_data_t), 0,
	    nnode_proxy_data_construct, nnode_proxy_data_destroy, NULL,
	    NULL, NULL, 0);
}

void
nnode_proxy_fini(void)
{
	kmem_cache_destroy(nnode_proxy_data_cache);
}
