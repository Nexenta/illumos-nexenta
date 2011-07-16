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
 * Copyright 2011 Nexenta Systems, Inc. All rights reserved.
 */

#include <sys/types.h>
#include <sys/uio.h>
#include <rpc/xdr.h>
#include <nfs/nnode_proxy.h>
#include <nfs/ds_prot.h>

static void
borrow_from_iovecs(struct iovec *iov, int vecs,
    unsigned char *buf, unsigned int n)
{
	int i = 0;

	while (i < vecs && n) {
		unsigned int m = iov[i].iov_len;

		if (m > n)
			m = n;

		bcopy(iov[i].iov_base, buf, m);
		iov[i].iov_base += m;
		iov[i].iov_len -= m;
		buf += m;
		n -= m;
		i++;
	}
}

bool_t
xdr_DS_WRITEargs_send(XDR *xdrs, ds_write_t *wr)
{
	DS_WRITEargs *objp = &wr->args;
	int i;

	if (!xdr_nfs_fh4(xdrs, &objp->fh))
		return (FALSE);
	if (!xdr_stable_how4(xdrs, &objp->stable))
		return (FALSE);
	if (!xdr_offset4(xdrs, &objp->offset))
		return (FALSE);

	if (!xdr_uint32_t(xdrs, &wr->count))
		return (FALSE);

	for (i = 0; i < wr->iov_count; i++) {
		struct iovec *iov = &wr->iov[i];
		int rest;

		if (iov->iov_len == 0)
			continue;

		rest = iov->iov_len % BYTES_PER_XDR_UNIT;
		if (!xdr_opaque(xdrs, iov->iov_base, iov->iov_len - rest))
			return (FALSE);

		if (rest) {
			unsigned char buf[BYTES_PER_XDR_UNIT] = {0};

			bcopy(iov->iov_base + iov->iov_len - rest, buf, rest);

			if (i + 1 < wr->iov_count)
				borrow_from_iovecs(&wr->iov[i + 1],
				    wr->iov_count - (i + 1), buf + rest,
				    BYTES_PER_XDR_UNIT - rest);

			if (!xdr_opaque(xdrs, (void *)buf, BYTES_PER_XDR_UNIT))
				return (FALSE);
		}
	}
	return (TRUE);
}
