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
 * Copyright (c) 1994, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright (c) 2013 by Delphix. All rights reserved.
 * Copyright 2020 Nexenta by DDN Inc.  All rights reserved.
 */

/* Copyright (c) 1983, 1984, 1985, 1986, 1987, 1988, 1989 AT&T */
/* All Rights Reserved */


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
#include <sys/cmn_err.h>
#include <sys/debug.h>
#include <sys/systeminfo.h>
#include <sys/flock.h>
#include <sys/nbmlock.h>
#include <sys/policy.h>
#include <sys/sdt.h>

#include <rpc/types.h>
#include <rpc/auth.h>
#include <rpc/svc.h>
#include <rpc/rpc_rdma.h>

#include <nfs/nfs.h>
#include <nfs/export.h>
#include <nfs/nfs_cmd.h>

#include <sys/strsubr.h>
#include <sys/tsol/label.h>
#include <sys/tsol/tndb.h>

#include <sys/zone.h>

#include <inet/ip.h>
#include <inet/ip6.h>

/*
 * Zone global variables of NFSv3 server
 */
typedef struct nfs3_srv {
	writeverf3	write3verf;
} nfs3_srv_t;

/*
 * These are the interface routines for the server side of the
 * Network File System.  See the NFS version 3 protocol specification
 * for a description of this interface.
 */

static int	sattr3_to_vattr(sattr3 *, struct vattr *);
static int	vattr_to_fattr3(struct vattr *, fattr3 *);
static int	vattr_to_wcc_attr(struct vattr *, wcc_attr *);
static void	vattr_to_pre_op_attr(struct vattr *, pre_op_attr *);
static void	vattr_to_wcc_data(struct vattr *, struct vattr *, wcc_data *);
static int	rdma_setup_read_data3(READ3args *, READ3resok *);

extern int nfs_loaned_buffers;

u_longlong_t nfs3_srv_caller_id;
static zone_key_t rfs3_zone_key;

static nfs3_srv_t *
nfs3_get_srv(void)
{
	nfs_globals_t *ng = nfs_srv_getzg();
	nfs3_srv_t *srv = ng->nfs3_srv;
	ASSERT(srv != NULL);
	return (srv);
}

/* ARGSUSED */
void
rfs3_getattr(GETATTR3args *args, GETATTR3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr va;

	vp = nfs3_fhtovp(&args->object, exi);

	DTRACE_NFSV3_5(op__getattr__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    GETATTR3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	va.va_mask = AT_ALL;
	error = rfs4_delegated_getattr(vp, &va, 0, cr);

	if (!error) {
		/* Lie about the object type for a referral */
		if (vn_is_nfs_reparse(vp, cr))
			va.va_type = VLNK;

		/* overflow error if time or size is out of range */
		error = vattr_to_fattr3(&va, &resp->resok.obj_attributes);
		if (error)
			goto out;
		resp->status = NFS3_OK;

		DTRACE_NFSV3_5(op__getattr__done, struct svc_req *, req,
		    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
		    GETATTR3res *, resp);

		VN_RELE(vp);

		return;
	}

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);

	DTRACE_NFSV3_5(op__getattr__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    GETATTR3res *, resp);

	if (vp != NULL)
		VN_RELE(vp);
}

void *
rfs3_getattr_getfh(GETATTR3args *args)
{
	return (&args->object);
}

void
rfs3_setattr(SETATTR3args *args, SETATTR3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *bvap;
	struct vattr bva;
	struct vattr *avap;
	struct vattr ava;
	int flag;
	int in_crit = 0;
	struct flock64 bf;
	caller_context_t ct;

	bvap = NULL;
	avap = NULL;

	vp = nfs3_fhtovp(&args->object, exi);

	DTRACE_NFSV3_5(op__setattr__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    SETATTR3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	error = sattr3_to_vattr(&args->new_attributes, &ava);
	if (error)
		goto out;

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opsetattr__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	/*
	 * We need to specially handle size changes because of
	 * possible conflicting NBMAND locks. Get into critical
	 * region before VOP_GETATTR, so the size attribute is
	 * valid when checking conflicts.
	 *
	 * Also, check to see if the v4 side of the server has
	 * delegated this file.  If so, then we return JUKEBOX to
	 * allow the client to retrasmit its request.
	 */
	if (vp->v_type == VREG && (ava.va_mask & AT_SIZE)) {
		if (nbl_need_check(vp)) {
			nbl_start_crit(vp, RW_READER);
			in_crit = 1;
		}
	}

	bva.va_mask = AT_ALL;
	error = rfs4_delegated_getattr(vp, &bva, 0, cr);

	/*
	 * If we can't get the attributes, then we can't do the
	 * right access checking.  So, we'll fail the request.
	 */
	if (error)
		goto out;

	bvap = &bva;

	if (rdonly(ro, vp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (args->guard.check &&
	    (args->guard.obj_ctime.seconds != bva.va_ctime.tv_sec ||
	    args->guard.obj_ctime.nseconds != bva.va_ctime.tv_nsec)) {
		resp->status = NFS3ERR_NOT_SYNC;
		goto out1;
	}

	if (args->new_attributes.mtime.set_it == SET_TO_CLIENT_TIME)
		flag = ATTR_UTIME;
	else
		flag = 0;

	/*
	 * If the filesystem is exported with nosuid, then mask off
	 * the setuid and setgid bits.
	 */
	if ((ava.va_mask & AT_MODE) && vp->v_type == VREG &&
	    (exi->exi_export.ex_flags & EX_NOSUID))
		ava.va_mode &= ~(VSUID | VSGID);

	ct.cc_sysid = 0;
	ct.cc_pid = 0;
	ct.cc_caller_id = nfs3_srv_caller_id;
	ct.cc_flags = CC_DONTBLOCK;

	/*
	 * We need to specially handle size changes because it is
	 * possible for the client to create a file with modes
	 * which indicate read-only, but with the file opened for
	 * writing.  If the client then tries to set the size of
	 * the file, then the normal access checking done in
	 * VOP_SETATTR would prevent the client from doing so,
	 * although it should be legal for it to do so.  To get
	 * around this, we do the access checking for ourselves
	 * and then use VOP_SPACE which doesn't do the access
	 * checking which VOP_SETATTR does. VOP_SPACE can only
	 * operate on VREG files, let VOP_SETATTR handle the other
	 * extremely rare cases.
	 * Also the client should not be allowed to change the
	 * size of the file if there is a conflicting non-blocking
	 * mandatory lock in the region the change.
	 */
	if (vp->v_type == VREG && (ava.va_mask & AT_SIZE)) {
		if (in_crit) {
			u_offset_t offset;
			ssize_t length;

			if (ava.va_size < bva.va_size) {
				offset = ava.va_size;
				length = bva.va_size - ava.va_size;
			} else {
				offset = bva.va_size;
				length = ava.va_size - bva.va_size;
			}
			if (nbl_conflict(vp, NBL_WRITE, offset, length, 0,
			    NULL)) {
				error = EACCES;
				goto out;
			}
		}

		if (crgetuid(cr) == bva.va_uid && ava.va_size != bva.va_size) {
			ava.va_mask &= ~AT_SIZE;
			bf.l_type = F_WRLCK;
			bf.l_whence = 0;
			bf.l_start = (off64_t)ava.va_size;
			bf.l_len = 0;
			bf.l_sysid = 0;
			bf.l_pid = 0;
			error = VOP_SPACE(vp, F_FREESP, &bf, FWRITE,
			    (offset_t)ava.va_size, cr, &ct);
		}
	}

	if (!error && ava.va_mask)
		error = VOP_SETATTR(vp, &ava, flag, cr, &ct);

	/* check if a monitor detected a delegation conflict */
	if (error == EAGAIN && (ct.cc_flags & CC_WOULDBLOCK)) {
		resp->status = NFS3ERR_JUKEBOX;
		goto out1;
	}

	ava.va_mask = AT_ALL;
	avap = rfs4_delegated_getattr(vp, &ava, 0, cr) ? NULL : &ava;

	/*
	 * Force modified metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, &ct);

	if (error)
		goto out;

	if (in_crit)
		nbl_end_crit(vp);

	resp->status = NFS3_OK;
	vattr_to_wcc_data(bvap, avap, &resp->resok.obj_wcc);

	DTRACE_NFSV3_5(op__setattr__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    SETATTR3res *, resp);

	VN_RELE(vp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__setattr__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    SETATTR3res *, resp);

	if (vp != NULL) {
		if (in_crit)
			nbl_end_crit(vp);
		VN_RELE(vp);
	}
	vattr_to_wcc_data(bvap, avap, &resp->resfail.obj_wcc);
}

void *
rfs3_setattr_getfh(SETATTR3args *args)
{
	return (&args->object);
}

/* ARGSUSED */
void
rfs3_lookup(LOOKUP3args *args, LOOKUP3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *dvap;
	struct vattr dva;
	nfs_fh3 *fhp;
	struct sec_ol sec = {0, 0};
	bool_t publicfh_flag = FALSE, auth_weak = FALSE;
	struct sockaddr *ca;
	char *name = NULL;

	dvap = NULL;

	if (exi != NULL)
		exi_hold(exi);

	/*
	 * Allow lookups from the root - the default
	 * location of the public filehandle.
	 */
	if (exi != NULL && (exi->exi_export.ex_flags & EX_PUBLIC)) {
		ASSERT3U(exi->exi_zoneid, ==, curzone->zone_id);
		dvp = ZONE_ROOTVP();
		VN_HOLD(dvp);

		DTRACE_NFSV3_5(op__lookup__start, struct svc_req *, req,
		    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
		    LOOKUP3args *, args);
	} else {
		dvp = nfs3_fhtovp(&args->what.dir, exi);

		DTRACE_NFSV3_5(op__lookup__start, struct svc_req *, req,
		    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
		    LOOKUP3args *, args);

		if (dvp == NULL) {
			error = ESTALE;
			goto out;
		}
	}

	dva.va_mask = AT_ALL;
	dvap = VOP_GETATTR(dvp, &dva, 0, cr, NULL) ? NULL : &dva;

	if (args->what.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto out1;
	}

	if (args->what.name == NULL || *(args->what.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	fhp = &args->what.dir;
	ASSERT3U(curzone->zone_id, ==, exi->exi_zoneid); /* exi is non-NULL */
	if (strcmp(args->what.name, "..") == 0 &&
	    EQFID(&exi->exi_fid, FH3TOFIDP(fhp))) {
		if ((exi->exi_export.ex_flags & EX_NOHIDE) &&
		    ((dvp->v_flag & VROOT) || VN_IS_CURZONEROOT(dvp))) {
			/*
			 * special case for ".." and 'nohide'exported root
			 */
			if (rfs_climb_crossmnt(&dvp, &exi, cr) != 0) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		} else {
			resp->status = NFS3ERR_NOENT;
			goto out1;
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->what.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	/*
	 * If the public filehandle is used then allow
	 * a multi-component lookup
	 */
	if (PUBLIC_FH3(&args->what.dir)) {
		publicfh_flag = TRUE;

		exi_rele(exi);
		exi = NULL;

		error = rfs_publicfh_mclookup(name, dvp, cr, &vp,
		    &exi, &sec);

		/*
		 * Since WebNFS may bypass MOUNT, we need to ensure this
		 * request didn't come from an unlabeled admin_low client.
		 */
		if (is_system_labeled() && error == 0) {
			int		addr_type;
			void		*ipaddr;
			tsol_tpc_t	*tp;

			if (ca->sa_family == AF_INET) {
				addr_type = IPV4_VERSION;
				ipaddr = &((struct sockaddr_in *)ca)->sin_addr;
			} else if (ca->sa_family == AF_INET6) {
				addr_type = IPV6_VERSION;
				ipaddr = &((struct sockaddr_in6 *)
				    ca)->sin6_addr;
			}
			tp = find_tpc(ipaddr, addr_type, B_FALSE);
			if (tp == NULL || tp->tpc_tp.tp_doi !=
			    l_admin_low->tsl_doi || tp->tpc_tp.host_type !=
			    SUN_CIPSO) {
				VN_RELE(vp);
				error = EACCES;
			}
			if (tp != NULL)
				TPC_RELE(tp);
		}
	} else {
		error = VOP_LOOKUP(dvp, name, &vp,
		    NULL, 0, NULL, cr, NULL, NULL, NULL);
	}

	if (name != args->what.name)
		kmem_free(name, MAXPATHLEN + 1);

	if (error == 0 && vn_ismntpt(vp)) {
		error = rfs_cross_mnt(&vp, &exi);
		if (error)
			VN_RELE(vp);
	}

	if (is_system_labeled() && error == 0) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__oplookup__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp,
			    DOMINANCE_CHECK, exi)) {
				VN_RELE(vp);
				error = EACCES;
			}
		}
	}

	dva.va_mask = AT_ALL;
	dvap = VOP_GETATTR(dvp, &dva, 0, cr, NULL) ? NULL : &dva;

	if (error)
		goto out;

	if (sec.sec_flags & SEC_QUERY) {
		error = makefh3_ol(&resp->resok.object, exi, sec.sec_index);
	} else {
		error = makefh3(&resp->resok.object, vp, exi);
		if (!error && publicfh_flag && !chk_clnt_sec(exi, req))
			auth_weak = TRUE;
	}

	if (error) {
		VN_RELE(vp);
		goto out;
	}

	va.va_mask = AT_ALL;
	vap = rfs4_delegated_getattr(vp, &va, 0, cr) ? NULL : &va;

	VN_RELE(vp);

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	vattr_to_post_op_attr(dvap, &resp->resok.dir_attributes);

	/*
	 * If it's public fh, no 0x81, and client's flavor is
	 * invalid, set WebNFS status to WNFSERR_CLNT_FLAVOR now.
	 * Then set RPC status to AUTH_TOOWEAK in common_dispatch.
	 */
	if (auth_weak)
		resp->status = (enum nfsstat3)WNFSERR_CLNT_FLAVOR;

	DTRACE_NFSV3_5(op__lookup__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    LOOKUP3res *, resp);
	VN_RELE(dvp);
	exi_rele(exi);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__lookup__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    LOOKUP3res *, resp);

	if (exi != NULL)
		exi_rele(exi);

	if (dvp != NULL)
		VN_RELE(dvp);
	vattr_to_post_op_attr(dvap, &resp->resfail.dir_attributes);

}

void *
rfs3_lookup_getfh(LOOKUP3args *args)
{
	return (&args->what.dir);
}

void
rfs3_access(ACCESS3args *args, ACCESS3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	int checkwriteperm;
	boolean_t dominant_label = B_FALSE;
	boolean_t equal_label = B_FALSE;
	boolean_t admin_low_client;

	vap = NULL;

	vp = nfs3_fhtovp(&args->object, exi);

	DTRACE_NFSV3_5(op__access__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    ACCESS3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	/*
	 * If the file system is exported read only, it is not appropriate
	 * to check write permissions for regular files and directories.
	 * Special files are interpreted by the client, so the underlying
	 * permissions are sent back to the client for interpretation.
	 */
	if (rdonly(ro, vp) && (vp->v_type == VREG || vp->v_type == VDIR))
		checkwriteperm = 0;
	else
		checkwriteperm = 1;

	/*
	 * We need the mode so that we can correctly determine access
	 * permissions relative to a mandatory lock file.  Access to
	 * mandatory lock files is denied on the server, so it might
	 * as well be reflected to the server during the open.
	 */
	va.va_mask = AT_MODE;
	error = VOP_GETATTR(vp, &va, 0, cr, NULL);
	if (error)
		goto out;

	vap = &va;

	resp->resok.access = 0;

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opaccess__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if ((equal_label = do_rfs_label_check(clabel, vp,
			    EQUALITY_CHECK, exi)) == B_FALSE) {
				dominant_label = do_rfs_label_check(clabel,
				    vp, DOMINANCE_CHECK, exi);
			} else
				dominant_label = B_TRUE;
			admin_low_client = B_FALSE;
		} else
			admin_low_client = B_TRUE;
	}

	if (args->access & ACCESS3_READ) {
		error = VOP_ACCESS(vp, VREAD, 0, cr, NULL);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
		} else if (!MANDLOCK(vp, va.va_mode) &&
		    (!is_system_labeled() || admin_low_client ||
		    dominant_label))
			resp->resok.access |= ACCESS3_READ;
	}
	if ((args->access & ACCESS3_LOOKUP) && vp->v_type == VDIR) {
		error = VOP_ACCESS(vp, VEXEC, 0, cr, NULL);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
		} else if (!is_system_labeled() || admin_low_client ||
		    dominant_label)
			resp->resok.access |= ACCESS3_LOOKUP;
	}
	if (checkwriteperm &&
	    (args->access & (ACCESS3_MODIFY|ACCESS3_EXTEND))) {
		error = VOP_ACCESS(vp, VWRITE, 0, cr, NULL);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
		} else if (!MANDLOCK(vp, va.va_mode) &&
		    (!is_system_labeled() || admin_low_client || equal_label)) {
			resp->resok.access |=
			    (args->access & (ACCESS3_MODIFY|ACCESS3_EXTEND));
		}
	}
	if (checkwriteperm &&
	    (args->access & ACCESS3_DELETE) && vp->v_type == VDIR) {
		error = VOP_ACCESS(vp, VWRITE, 0, cr, NULL);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
		} else if (!is_system_labeled() || admin_low_client ||
		    equal_label)
			resp->resok.access |= ACCESS3_DELETE;
	}
	if (args->access & ACCESS3_EXECUTE) {
		error = VOP_ACCESS(vp, VEXEC, 0, cr, NULL);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
		} else if (!MANDLOCK(vp, va.va_mode) &&
		    (!is_system_labeled() || admin_low_client ||
		    dominant_label))
			resp->resok.access |= ACCESS3_EXECUTE;
	}

	va.va_mask = AT_ALL;
	vap = rfs4_delegated_getattr(vp, &va, 0, cr) ? NULL : &va;

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);

	DTRACE_NFSV3_5(op__access__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    ACCESS3res *, resp);

	VN_RELE(vp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
	DTRACE_NFSV3_5(op__access__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    ACCESS3res *, resp);
	if (vp != NULL)
		VN_RELE(vp);
	vattr_to_post_op_attr(vap, &resp->resfail.obj_attributes);
}

void *
rfs3_access_getfh(ACCESS3args *args)
{
	return (&args->object);
}

/* ARGSUSED */
void
rfs3_readlink(READLINK3args *args, READLINK3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	struct iovec iov;
	struct uio uio;
	char *data;
	struct sockaddr *ca;
	char *name = NULL;
	int is_referral = 0;

	vap = NULL;

	vp = nfs3_fhtovp(&args->symlink, exi);

	DTRACE_NFSV3_5(op__readlink__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READLINK3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	va.va_mask = AT_ALL;
	error = VOP_GETATTR(vp, &va, 0, cr, NULL);
	if (error)
		goto out;

	vap = &va;

	/* We lied about the object type for a referral */
	if (vn_is_nfs_reparse(vp, cr))
		is_referral = 1;

	if (vp->v_type != VLNK && !is_referral) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	if (MANDLOCK(vp, va.va_mode)) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opreadlink__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	data = kmem_alloc(MAXPATHLEN + 1, KM_SLEEP);

	if (is_referral) {
		char *s;
		size_t strsz;
		kstat_named_t *stat = exi->exi_ne->ne_globals->svstat[NFS_V3];

		/* Get an artificial symlink based on a referral */
		s = build_symlink(vp, cr, &strsz);
		stat[NFS_REFERLINKS].value.ui64++;
		DTRACE_PROBE2(nfs3serv__func__referral__reflink,
		    vnode_t *, vp, char *, s);
		if (s == NULL)
			error = EINVAL;
		else {
			error = 0;
			(void) strlcpy(data, s, MAXPATHLEN + 1);
			kmem_free(s, strsz);
		}

	} else {

		iov.iov_base = data;
		iov.iov_len = MAXPATHLEN;
		uio.uio_iov = &iov;
		uio.uio_iovcnt = 1;
		uio.uio_segflg = UIO_SYSSPACE;
		uio.uio_extflg = UIO_COPY_CACHED;
		uio.uio_loffset = 0;
		uio.uio_resid = MAXPATHLEN;

		error = VOP_READLINK(vp, &uio, cr, NULL);

		if (!error)
			*(data + MAXPATHLEN - uio.uio_resid) = '\0';
	}

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	/* Lie about object type again just to be consistent */
	if (is_referral && vap != NULL)
		vap->va_type = VLNK;

#if 0 /* notyet */
	/*
	 * Don't do this.  It causes local disk writes when just
	 * reading the file and the overhead is deemed larger
	 * than the benefit.
	 */
	/*
	 * Force modified metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);
#endif

	if (error) {
		kmem_free(data, MAXPATHLEN + 1);
		goto out;
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, data, NFSCMD_CONV_OUTBOUND,
	    MAXPATHLEN + 1);

	if (name == NULL) {
		/*
		 * Even though the conversion failed, we return
		 * something. We just don't translate it.
		 */
		name = data;
	}

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.symlink_attributes);
	resp->resok.data = name;

	DTRACE_NFSV3_5(op__readlink__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READLINK3res *, resp);
	VN_RELE(vp);

	if (name != data)
		kmem_free(data, MAXPATHLEN + 1);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__readlink__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READLINK3res *, resp);
	if (vp != NULL)
		VN_RELE(vp);
	vattr_to_post_op_attr(vap, &resp->resfail.symlink_attributes);
}

void *
rfs3_readlink_getfh(READLINK3args *args)
{
	return (&args->symlink);
}

void
rfs3_readlink_free(READLINK3res *resp)
{
	if (resp->status == NFS3_OK)
		kmem_free(resp->resok.data, MAXPATHLEN + 1);
}

/*
 * Server routine to handle read
 * May handle RDMA data as well as mblks
 */
/* ARGSUSED */
void
rfs3_read(READ3args *args, READ3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	struct iovec iov, *iovp = NULL;
	int iovcnt;
	struct uio uio;
	u_offset_t offset;
	mblk_t *mp = NULL;
	int in_crit = 0;
	int need_rwunlock = 0;
	caller_context_t ct;
	int rdma_used = 0;
	int loaned_buffers;
	struct uio *uiop;

	vap = NULL;

	vp = nfs3_fhtovp(&args->file, exi);

	DTRACE_NFSV3_5(op__read__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READ3args *, args);


	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	if (args->wlist) {
		if (args->count > clist_len(args->wlist)) {
			error = EINVAL;
			goto out;
		}
		rdma_used = 1;
	}

	/* use loaned buffers for TCP */
	loaned_buffers = (nfs_loaned_buffers && !rdma_used) ? 1 : 0;

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opread__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	ct.cc_sysid = 0;
	ct.cc_pid = 0;
	ct.cc_caller_id = nfs3_srv_caller_id;
	ct.cc_flags = CC_DONTBLOCK;

	/*
	 * Enter the critical region before calling VOP_RWLOCK
	 * to avoid a deadlock with write requests.
	 */
	if (nbl_need_check(vp)) {
		nbl_start_crit(vp, RW_READER);
		in_crit = 1;
		if (nbl_conflict(vp, NBL_READ, args->offset, args->count, 0,
		    NULL)) {
			error = EACCES;
			goto out;
		}
	}

	error = VOP_RWLOCK(vp, V_WRITELOCK_FALSE, &ct);

	/* check if a monitor detected a delegation conflict */
	if (error == EAGAIN && (ct.cc_flags & CC_WOULDBLOCK)) {
		resp->status = NFS3ERR_JUKEBOX;
		goto out1;
	}

	need_rwunlock = 1;

	va.va_mask = AT_ALL;
	error = VOP_GETATTR(vp, &va, 0, cr, &ct);

	/*
	 * If we can't get the attributes, then we can't do the
	 * right access checking.  So, we'll fail the request.
	 */
	if (error)
		goto out;

	vap = &va;

	if (vp->v_type != VREG) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	if (crgetuid(cr) != va.va_uid) {
		error = VOP_ACCESS(vp, VREAD, 0, cr, &ct);
		if (error) {
			if (curthread->t_flag & T_WOULDBLOCK)
				goto out;
			error = VOP_ACCESS(vp, VEXEC, 0, cr, &ct);
			if (error)
				goto out;
		}
	}

	if (MANDLOCK(vp, va.va_mode)) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	offset = args->offset;
	if (offset >= va.va_size) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, &ct);
		if (in_crit)
			nbl_end_crit(vp);
		resp->status = NFS3_OK;
		vattr_to_post_op_attr(vap, &resp->resok.file_attributes);
		resp->resok.count = 0;
		resp->resok.eof = TRUE;
		resp->resok.data.data_len = 0;
		resp->resok.data.data_val = NULL;
		resp->resok.data.mp = NULL;
		/* RDMA */
		resp->resok.wlist = args->wlist;
		resp->resok.wlist_len = resp->resok.count;
		if (resp->resok.wlist)
			clist_zero_len(resp->resok.wlist);
		goto done;
	}

	if (args->count == 0) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, &ct);
		if (in_crit)
			nbl_end_crit(vp);
		resp->status = NFS3_OK;
		vattr_to_post_op_attr(vap, &resp->resok.file_attributes);
		resp->resok.count = 0;
		resp->resok.eof = FALSE;
		resp->resok.data.data_len = 0;
		resp->resok.data.data_val = NULL;
		resp->resok.data.mp = NULL;
		/* RDMA */
		resp->resok.wlist = args->wlist;
		resp->resok.wlist_len = resp->resok.count;
		if (resp->resok.wlist)
			clist_zero_len(resp->resok.wlist);
		goto done;
	}

	/*
	 * do not allocate memory more the max. allowed
	 * transfer size
	 */
	if (args->count > rfs3_tsize(req))
		args->count = rfs3_tsize(req);

	if (loaned_buffers) {
		uiop = (uio_t *)rfs_setup_xuio(vp);
		ASSERT(uiop != NULL);
		uiop->uio_segflg = UIO_SYSSPACE;
		uiop->uio_loffset = args->offset;
		uiop->uio_resid = args->count;

		/* Jump to do the read if successful */
		if (VOP_REQZCBUF(vp, UIO_READ, (xuio_t *)uiop, cr, &ct) == 0) {
			/*
			 * Need to hold the vnode until after VOP_RETZCBUF()
			 * is called.
			 */
			VN_HOLD(vp);
			goto doio_read;
		}

		DTRACE_PROBE2(nfss__i__reqzcbuf_failed, int,
		    uiop->uio_loffset, int, uiop->uio_resid);

		uiop->uio_extflg = 0;
		/* failure to setup for zero copy */
		rfs_free_xuio((void *)uiop);
		loaned_buffers = 0;
	}

	/*
	 * If returning data via RDMA Write, then grab the chunk list.
	 * If we aren't returning READ data w/RDMA_WRITE, then grab
	 * a mblk.
	 */
	if (rdma_used) {
		(void) rdma_get_wchunk(req, &iov, args->wlist);
		uio.uio_iov = &iov;
		uio.uio_iovcnt = 1;
	} else {
		/*
		 * mp will contain the data to be sent out in the read reply.
		 * For UDP, this will be freed after the reply has been sent
		 * out by the driver.  For TCP, it will be freed after the last
		 * segment associated with the reply has been ACKed by the
		 * client.
		 */
		mp = rfs_read_alloc(args->count, &iovp, &iovcnt);
		uio.uio_iov = iovp;
		uio.uio_iovcnt = iovcnt;
	}

	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_CACHED;
	uio.uio_loffset = args->offset;
	uio.uio_resid = args->count;
	uiop = &uio;

doio_read:
	nfs_process_vsd_stats(vp, FREAD, uiop->uio_resid);
	error = VOP_READ(vp, uiop, 0, cr, &ct);

	if (error) {
		if (mp)
			freemsg(mp);
		/* check if a monitor detected a delegation conflict */
		if (error == EAGAIN && (ct.cc_flags & CC_WOULDBLOCK)) {
			resp->status = NFS3ERR_JUKEBOX;
			goto out1;
		}
		goto out;
	}

	/* make mblk using zc buffers */
	if (loaned_buffers) {
		mp = uio_to_mblk(uiop);
		ASSERT(mp != NULL);
	}

	va.va_mask = AT_ALL;
	error = VOP_GETATTR(vp, &va, 0, cr, &ct);

	if (error)
		vap = NULL;
	else
		vap = &va;

	VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, &ct);

	if (in_crit)
		nbl_end_crit(vp);

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.file_attributes);
	resp->resok.count = args->count - uiop->uio_resid;
	if (!error && offset + resp->resok.count == va.va_size)
		resp->resok.eof = TRUE;
	else
		resp->resok.eof = FALSE;
	resp->resok.data.data_len = resp->resok.count;

	if (mp)
		rfs_rndup_mblks(mp, resp->resok.count, loaned_buffers);

	resp->resok.data.mp = mp;
	resp->resok.size = (uint_t)args->count;

	if (rdma_used) {
		resp->resok.data.data_val = (caddr_t)iov.iov_base;
		if (!rdma_setup_read_data3(args, &(resp->resok))) {
			resp->status = NFS3ERR_INVAL;
		}
	} else {
		resp->resok.data.data_val = (caddr_t)mp->b_datap->db_base;
		(resp->resok).wlist = NULL;
	}

done:
	DTRACE_NFSV3_5(op__read__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READ3res *, resp);

	VN_RELE(vp);

	if (iovp != NULL)
		kmem_free(iovp, iovcnt * sizeof (struct iovec));

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__read__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READ3res *, resp);

	if (vp != NULL) {
		if (need_rwunlock)
			VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, &ct);
		if (in_crit)
			nbl_end_crit(vp);
		VN_RELE(vp);
	}
	vattr_to_post_op_attr(vap, &resp->resfail.file_attributes);

	if (iovp != NULL)
		kmem_free(iovp, iovcnt * sizeof (struct iovec));
}

void
rfs3_read_free(READ3res *resp)
{
	mblk_t *mp;

	if (resp->status == NFS3_OK) {
		mp = resp->resok.data.mp;
		if (mp != NULL)
			freemsg(mp);
	}
}

void *
rfs3_read_getfh(READ3args *args)
{
	return (&args->file);
}

#define	MAX_IOVECS	12

#ifdef DEBUG
static int rfs3_write_hits = 0;
static int rfs3_write_misses = 0;
#endif

void
rfs3_write(WRITE3args *args, WRITE3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	nfs3_srv_t *ns;
	int error;
	vnode_t *vp;
	struct vattr *bvap = NULL;
	struct vattr bva;
	struct vattr *avap = NULL;
	struct vattr ava;
	u_offset_t rlimit;
	struct uio uio;
	struct iovec iov[MAX_IOVECS];
	mblk_t *m;
	struct iovec *iovp;
	int iovcnt;
	int ioflag;
	cred_t *savecred;
	int in_crit = 0;
	int rwlock_ret = -1;
	caller_context_t ct;

	vp = nfs3_fhtovp(&args->file, exi);

	DTRACE_NFSV3_5(op__write__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    WRITE3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto err;
	}

	ASSERT3U(curzone->zone_id, ==, exi->exi_zoneid); /* exi is non-NULL. */
	ns = nfs3_get_srv();

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opwrite__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	ct.cc_sysid = 0;
	ct.cc_pid = 0;
	ct.cc_caller_id = nfs3_srv_caller_id;
	ct.cc_flags = CC_DONTBLOCK;

	/*
	 * We have to enter the critical region before calling VOP_RWLOCK
	 * to avoid a deadlock with ufs.
	 */
	if (nbl_need_check(vp)) {
		nbl_start_crit(vp, RW_READER);
		in_crit = 1;
		if (nbl_conflict(vp, NBL_WRITE, args->offset, args->count, 0,
		    NULL)) {
			error = EACCES;
			goto err;
		}
	}

	rwlock_ret = VOP_RWLOCK(vp, V_WRITELOCK_TRUE, &ct);

	/* check if a monitor detected a delegation conflict */
	if (rwlock_ret == EAGAIN && (ct.cc_flags & CC_WOULDBLOCK)) {
		resp->status = NFS3ERR_JUKEBOX;
		rwlock_ret = -1;
		goto err1;
	}


	bva.va_mask = AT_ALL;
	error = VOP_GETATTR(vp, &bva, 0, cr, &ct);

	/*
	 * If we can't get the attributes, then we can't do the
	 * right access checking.  So, we'll fail the request.
	 */
	if (error)
		goto err;

	bvap = &bva;
	avap = bvap;

	if (args->count != args->data.data_len) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	if (rdonly(ro, vp)) {
		resp->status = NFS3ERR_ROFS;
		goto err1;
	}

	if (vp->v_type != VREG) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	if (crgetuid(cr) != bva.va_uid &&
	    (error = VOP_ACCESS(vp, VWRITE, 0, cr, &ct)))
		goto err;

	if (MANDLOCK(vp, bva.va_mode)) {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (args->count == 0) {
		resp->status = NFS3_OK;
		vattr_to_wcc_data(bvap, avap, &resp->resok.file_wcc);
		resp->resok.count = 0;
		resp->resok.committed = args->stable;
		resp->resok.verf = ns->write3verf;
		goto out;
	}

	if (args->mblk != NULL) {
		iovcnt = 0;
		for (m = args->mblk; m != NULL; m = m->b_cont)
			iovcnt++;
		if (iovcnt <= MAX_IOVECS) {
#ifdef DEBUG
			rfs3_write_hits++;
#endif
			iovp = iov;
		} else {
#ifdef DEBUG
			rfs3_write_misses++;
#endif
			iovp = kmem_alloc(sizeof (*iovp) * iovcnt, KM_SLEEP);
		}
		mblk_to_iov(args->mblk, iovcnt, iovp);

	} else if (args->rlist != NULL) {
		iovcnt = 1;
		iovp = iov;
		iovp->iov_base = (char *)((args->rlist)->u.c_daddr3);
		iovp->iov_len = args->count;
	} else {
		iovcnt = 1;
		iovp = iov;
		iovp->iov_base = args->data.data_val;
		iovp->iov_len = args->count;
	}

	uio.uio_iov = iovp;
	uio.uio_iovcnt = iovcnt;

	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_DEFAULT;
	uio.uio_loffset = args->offset;
	uio.uio_resid = args->count;
	uio.uio_llimit = curproc->p_fsz_ctl;
	rlimit = uio.uio_llimit - args->offset;
	if (rlimit < (u_offset_t)uio.uio_resid)
		uio.uio_resid = (int)rlimit;

	if (args->stable == UNSTABLE)
		ioflag = 0;
	else if (args->stable == FILE_SYNC)
		ioflag = FSYNC;
	else if (args->stable == DATA_SYNC)
		ioflag = FDSYNC;
	else {
		if (iovp != iov)
			kmem_free(iovp, sizeof (*iovp) * iovcnt);
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	nfs_process_vsd_stats(vp, FWRITE, uio.uio_resid);

	/*
	 * We're changing creds because VM may fault and we need
	 * the cred of the current thread to be used if quota
	 * checking is enabled.
	 */
	savecred = curthread->t_cred;
	curthread->t_cred = cr;
	error = VOP_WRITE(vp, &uio, ioflag, cr, &ct);
	curthread->t_cred = savecred;

	if (iovp != iov)
		kmem_free(iovp, sizeof (*iovp) * iovcnt);

	/* check if a monitor detected a delegation conflict */
	if (error == EAGAIN && (ct.cc_flags & CC_WOULDBLOCK)) {
		resp->status = NFS3ERR_JUKEBOX;
		goto err1;
	}

	ava.va_mask = AT_ALL;
	avap = VOP_GETATTR(vp, &ava, 0, cr, &ct) ? NULL : &ava;

	if (error)
		goto err;

	/*
	 * If we were unable to get the V_WRITELOCK_TRUE, then we
	 * may not have accurate after attrs, so check if
	 * we have both attributes, they have a non-zero va_seq, and
	 * va_seq has changed by exactly one,
	 * if not, turn off the before attr.
	 */
	if (rwlock_ret != V_WRITELOCK_TRUE) {
		if (bvap == NULL || avap == NULL ||
		    bvap->va_seq == 0 || avap->va_seq == 0 ||
		    avap->va_seq != (bvap->va_seq + 1)) {
			bvap = NULL;
		}
	}

	resp->status = NFS3_OK;
	vattr_to_wcc_data(bvap, avap, &resp->resok.file_wcc);
	resp->resok.count = args->count - uio.uio_resid;
	resp->resok.committed = args->stable;
	resp->resok.verf = ns->write3verf;
	goto out;

err:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
err1:
	vattr_to_wcc_data(bvap, avap, &resp->resfail.file_wcc);
out:
	DTRACE_NFSV3_5(op__write__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    WRITE3res *, resp);

	if (vp != NULL) {
		if (rwlock_ret != -1)
			VOP_RWUNLOCK(vp, V_WRITELOCK_TRUE, &ct);
		if (in_crit)
			nbl_end_crit(vp);
		VN_RELE(vp);
	}
}

void *
rfs3_write_getfh(WRITE3args *args)
{
	return (&args->file);
}

void
rfs3_create(CREATE3args *args, CREATE3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	int in_crit = 0;
	vnode_t *vp;
	vnode_t *tvp = NULL;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *dbvap;
	struct vattr dbva;
	struct vattr *davap;
	struct vattr dava;
	enum vcexcl excl;
	nfstime3 *mtime;
	len_t reqsize;
	bool_t trunc;
	struct sockaddr *ca;
	char *name = NULL;

	dbvap = NULL;
	davap = NULL;

	dvp = nfs3_fhtovp(&args->where.dir, exi);

	DTRACE_NFSV3_5(op__create__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    CREATE3args *, args);

	if (dvp == NULL) {
		error = ESTALE;
		goto out;
	}

	dbva.va_mask = AT_ALL;
	dbvap = VOP_GETATTR(dvp, &dbva, 0, cr, NULL) ? NULL : &dbva;
	davap = dbvap;

	if (args->where.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto out1;
	}

	if (args->where.name == NULL || *(args->where.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (rdonly(ro, dvp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (protect_zfs_mntpt(dvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opcreate__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->where.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		/* This is really a Solaris EILSEQ */
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	if (args->how.mode == EXCLUSIVE) {
		va.va_mask = AT_TYPE | AT_MODE | AT_MTIME;
		va.va_type = VREG;
		va.va_mode = (mode_t)0;
		/*
		 * Ensure no time overflows and that types match
		 */
		mtime = (nfstime3 *)&args->how.createhow3_u.verf;
		va.va_mtime.tv_sec = mtime->seconds % INT32_MAX;
		va.va_mtime.tv_nsec = mtime->nseconds;
		excl = EXCL;
	} else {
		error = sattr3_to_vattr(&args->how.createhow3_u.obj_attributes,
		    &va);
		if (error)
			goto out;
		va.va_mask |= AT_TYPE;
		va.va_type = VREG;
		if (args->how.mode == GUARDED)
			excl = EXCL;
		else {
			excl = NONEXCL;

			/*
			 * During creation of file in non-exclusive mode
			 * if size of file is being set then make sure
			 * that if the file already exists that no conflicting
			 * non-blocking mandatory locks exists in the region
			 * being modified. If there are conflicting locks fail
			 * the operation with EACCES.
			 */
			if (va.va_mask & AT_SIZE) {
				struct vattr tva;

				/*
				 * Does file already exist?
				 */
				error = VOP_LOOKUP(dvp, name, &tvp,
				    NULL, 0, NULL, cr, NULL, NULL, NULL);

				/*
				 * Check to see if the file has been delegated
				 * to a v4 client.  If so, then begin recall of
				 * the delegation and return JUKEBOX to allow
				 * the client to retrasmit its request.
				 */

				trunc = va.va_size == 0;
				if (!error &&
				    rfs4_check_delegated(FWRITE, tvp, trunc)) {
					resp->status = NFS3ERR_JUKEBOX;
					goto out1;
				}

				/*
				 * Check for NBMAND lock conflicts
				 */
				if (!error && nbl_need_check(tvp)) {
					u_offset_t offset;
					ssize_t len;

					nbl_start_crit(tvp, RW_READER);
					in_crit = 1;

					tva.va_mask = AT_SIZE;
					error = VOP_GETATTR(tvp, &tva, 0, cr,
					    NULL);
					/*
					 * Can't check for conflicts, so return
					 * error.
					 */
					if (error)
						goto out;

					offset = tva.va_size < va.va_size ?
					    tva.va_size : va.va_size;
					len = tva.va_size < va.va_size ?
					    va.va_size - tva.va_size :
					    tva.va_size - va.va_size;
					if (nbl_conflict(tvp, NBL_WRITE,
					    offset, len, 0, NULL)) {
						error = EACCES;
						goto out;
					}
				} else if (tvp) {
					VN_RELE(tvp);
					tvp = NULL;
				}
			}
		}
		if (va.va_mask & AT_SIZE)
			reqsize = va.va_size;
	}

	/*
	 * Must specify the mode.
	 */
	if (!(va.va_mask & AT_MODE)) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	/*
	 * If the filesystem is exported with nosuid, then mask off
	 * the setuid and setgid bits.
	 */
	if (va.va_type == VREG && (exi->exi_export.ex_flags & EX_NOSUID))
		va.va_mode &= ~(VSUID | VSGID);

tryagain:
	/*
	 * The file open mode used is VWRITE.  If the client needs
	 * some other semantic, then it should do the access checking
	 * itself.  It would have been nice to have the file open mode
	 * passed as part of the arguments.
	 */
	error = VOP_CREATE(dvp, name, &va, excl, VWRITE,
	    &vp, cr, 0, NULL, NULL);

	dava.va_mask = AT_ALL;
	davap = VOP_GETATTR(dvp, &dava, 0, cr, NULL) ? NULL : &dava;

	if (error) {
		/*
		 * If we got something other than file already exists
		 * then just return this error.  Otherwise, we got
		 * EEXIST.  If we were doing a GUARDED create, then
		 * just return this error.  Otherwise, we need to
		 * make sure that this wasn't a duplicate of an
		 * exclusive create request.
		 *
		 * The assumption is made that a non-exclusive create
		 * request will never return EEXIST.
		 */
		if (error != EEXIST || args->how.mode == GUARDED)
			goto out;
		/*
		 * Lookup the file so that we can get a vnode for it.
		 */
		error = VOP_LOOKUP(dvp, name, &vp, NULL, 0,
		    NULL, cr, NULL, NULL, NULL);
		if (error) {
			/*
			 * We couldn't find the file that we thought that
			 * we just created.  So, we'll just try creating
			 * it again.
			 */
			if (error == ENOENT)
				goto tryagain;
			goto out;
		}

		/*
		 * If the file is delegated to a v4 client, go ahead
		 * and initiate recall, this create is a hint that a
		 * conflicting v3 open has occurred.
		 */

		if (rfs4_check_delegated(FWRITE, vp, FALSE)) {
			VN_RELE(vp);
			resp->status = NFS3ERR_JUKEBOX;
			goto out1;
		}

		va.va_mask = AT_ALL;
		vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

		mtime = (nfstime3 *)&args->how.createhow3_u.verf;
		/* % with INT32_MAX to prevent overflows */
		if (args->how.mode == EXCLUSIVE && (vap == NULL ||
		    vap->va_mtime.tv_sec !=
		    (mtime->seconds % INT32_MAX) ||
		    vap->va_mtime.tv_nsec != mtime->nseconds)) {
			VN_RELE(vp);
			error = EEXIST;
			goto out;
		}
	} else {

		if ((args->how.mode == UNCHECKED ||
		    args->how.mode == GUARDED) &&
		    args->how.createhow3_u.obj_attributes.size.set_it &&
		    va.va_size == 0)
			trunc = TRUE;
		else
			trunc = FALSE;

		if (rfs4_check_delegated(FWRITE, vp, trunc)) {
			VN_RELE(vp);
			resp->status = NFS3ERR_JUKEBOX;
			goto out1;
		}

		va.va_mask = AT_ALL;
		vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

		/*
		 * We need to check to make sure that the file got
		 * created to the indicated size.  If not, we do a
		 * setattr to try to change the size, but we don't
		 * try too hard.  This shouldn't a problem as most
		 * clients will only specifiy a size of zero which
		 * local file systems handle.  However, even if
		 * the client does specify a non-zero size, it can
		 * still recover by checking the size of the file
		 * after it has created it and then issue a setattr
		 * request of its own to set the size of the file.
		 */
		if (vap != NULL &&
		    (args->how.mode == UNCHECKED ||
		    args->how.mode == GUARDED) &&
		    args->how.createhow3_u.obj_attributes.size.set_it &&
		    vap->va_size != reqsize) {
			va.va_mask = AT_SIZE;
			va.va_size = reqsize;
			(void) VOP_SETATTR(vp, &va, 0, cr, NULL);
			va.va_mask = AT_ALL;
			vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;
		}
	}

	if (name != args->where.name)
		kmem_free(name, MAXPATHLEN + 1);

	error = makefh3(&resp->resok.obj.handle, vp, exi);
	if (error)
		resp->resok.obj.handle_follows = FALSE;
	else
		resp->resok.obj.handle_follows = TRUE;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);
	(void) VOP_FSYNC(dvp, 0, cr, NULL);

	VN_RELE(vp);
	if (tvp != NULL) {
		if (in_crit)
			nbl_end_crit(tvp);
		VN_RELE(tvp);
	}

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	vattr_to_wcc_data(dbvap, davap, &resp->resok.dir_wcc);

	DTRACE_NFSV3_5(op__create__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    CREATE3res *, resp);

	VN_RELE(dvp);
	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__create__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    CREATE3res *, resp);

	if (name != NULL && name != args->where.name)
		kmem_free(name, MAXPATHLEN + 1);

	if (tvp != NULL) {
		if (in_crit)
			nbl_end_crit(tvp);
		VN_RELE(tvp);
	}
	if (dvp != NULL)
		VN_RELE(dvp);
	vattr_to_wcc_data(dbvap, davap, &resp->resfail.dir_wcc);
}

void *
rfs3_create_getfh(CREATE3args *args)
{
	return (&args->where.dir);
}

void
rfs3_mkdir(MKDIR3args *args, MKDIR3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp = NULL;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *dbvap;
	struct vattr dbva;
	struct vattr *davap;
	struct vattr dava;
	struct sockaddr *ca;
	char *name = NULL;

	dbvap = NULL;
	davap = NULL;

	dvp = nfs3_fhtovp(&args->where.dir, exi);

	DTRACE_NFSV3_5(op__mkdir__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKDIR3args *, args);

	if (dvp == NULL) {
		error = ESTALE;
		goto out;
	}

	dbva.va_mask = AT_ALL;
	dbvap = VOP_GETATTR(dvp, &dbva, 0, cr, NULL) ? NULL : &dbva;
	davap = dbvap;

	if (args->where.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto out1;
	}

	if (args->where.name == NULL || *(args->where.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (rdonly(ro, dvp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (protect_zfs_mntpt(dvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opmkdir__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	error = sattr3_to_vattr(&args->attributes, &va);
	if (error)
		goto out;

	if (!(va.va_mask & AT_MODE)) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->where.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	va.va_mask |= AT_TYPE;
	va.va_type = VDIR;

	error = VOP_MKDIR(dvp, name, &va, &vp, cr, NULL, 0, NULL);

	if (name != args->where.name)
		kmem_free(name, MAXPATHLEN + 1);

	dava.va_mask = AT_ALL;
	davap = VOP_GETATTR(dvp, &dava, 0, cr, NULL) ? NULL : &dava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(dvp, 0, cr, NULL);

	if (error)
		goto out;

	error = makefh3(&resp->resok.obj.handle, vp, exi);
	if (error)
		resp->resok.obj.handle_follows = FALSE;
	else
		resp->resok.obj.handle_follows = TRUE;

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, 0, cr, NULL);

	VN_RELE(vp);

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	vattr_to_wcc_data(dbvap, davap, &resp->resok.dir_wcc);

	DTRACE_NFSV3_5(op__mkdir__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKDIR3res *, resp);
	VN_RELE(dvp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__mkdir__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKDIR3res *, resp);
	if (dvp != NULL)
		VN_RELE(dvp);
	vattr_to_wcc_data(dbvap, davap, &resp->resfail.dir_wcc);
}

void *
rfs3_mkdir_getfh(MKDIR3args *args)
{
	return (&args->where.dir);
}

void
rfs3_symlink(SYMLINK3args *args, SYMLINK3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *dbvap;
	struct vattr dbva;
	struct vattr *davap;
	struct vattr dava;
	struct sockaddr *ca;
	char *name = NULL;
	char *symdata = NULL;

	dbvap = NULL;
	davap = NULL;

	dvp = nfs3_fhtovp(&args->where.dir, exi);

	DTRACE_NFSV3_5(op__symlink__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    SYMLINK3args *, args);

	if (dvp == NULL) {
		error = ESTALE;
		goto err;
	}

	dbva.va_mask = AT_ALL;
	dbvap = VOP_GETATTR(dvp, &dbva, 0, cr, NULL) ? NULL : &dbva;
	davap = dbvap;

	if (args->where.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto err1;
	}

	if (args->where.name == NULL || *(args->where.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (rdonly(ro, dvp)) {
		resp->status = NFS3ERR_ROFS;
		goto err1;
	}

	if (protect_zfs_mntpt(dvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opsymlink__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	error = sattr3_to_vattr(&args->symlink.symlink_attributes, &va);
	if (error)
		goto err;

	if (!(va.va_mask & AT_MODE)) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	if (args->symlink.symlink_data == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto err1;
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->where.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		/* This is really a Solaris EILSEQ */
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	symdata = nfscmd_convname(ca, exi, args->symlink.symlink_data,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);
	if (symdata == NULL) {
		/* This is really a Solaris EILSEQ */
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}


	va.va_mask |= AT_TYPE;
	va.va_type = VLNK;

	error = VOP_SYMLINK(dvp, name, &va, symdata, cr, NULL, 0);

	dava.va_mask = AT_ALL;
	davap = VOP_GETATTR(dvp, &dava, 0, cr, NULL) ? NULL : &dava;

	if (error)
		goto err;

	error = VOP_LOOKUP(dvp, name, &vp, NULL, 0, NULL, cr,
	    NULL, NULL, NULL);

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(dvp, 0, cr, NULL);


	resp->status = NFS3_OK;
	if (error) {
		resp->resok.obj.handle_follows = FALSE;
		vattr_to_post_op_attr(NULL, &resp->resok.obj_attributes);
		vattr_to_wcc_data(dbvap, davap, &resp->resok.dir_wcc);
		goto out;
	}

	error = makefh3(&resp->resok.obj.handle, vp, exi);
	if (error)
		resp->resok.obj.handle_follows = FALSE;
	else
		resp->resok.obj.handle_follows = TRUE;

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, 0, cr, NULL);

	VN_RELE(vp);

	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	vattr_to_wcc_data(dbvap, davap, &resp->resok.dir_wcc);
	goto out;

err:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
err1:
	vattr_to_wcc_data(dbvap, davap, &resp->resfail.dir_wcc);
out:
	if (name != NULL && name != args->where.name)
		kmem_free(name, MAXPATHLEN + 1);
	if (symdata != NULL && symdata != args->symlink.symlink_data)
		kmem_free(symdata, MAXPATHLEN + 1);

	DTRACE_NFSV3_5(op__symlink__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    SYMLINK3res *, resp);

	if (dvp != NULL)
		VN_RELE(dvp);
}

void *
rfs3_symlink_getfh(SYMLINK3args *args)
{
	return (&args->where.dir);
}

void
rfs3_mknod(MKNOD3args *args, MKNOD3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	vnode_t *realvp;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *dbvap;
	struct vattr dbva;
	struct vattr *davap;
	struct vattr dava;
	int mode;
	enum vcexcl excl;
	struct sockaddr *ca;
	char *name = NULL;

	dbvap = NULL;
	davap = NULL;

	dvp = nfs3_fhtovp(&args->where.dir, exi);

	DTRACE_NFSV3_5(op__mknod__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKNOD3args *, args);

	if (dvp == NULL) {
		error = ESTALE;
		goto out;
	}

	dbva.va_mask = AT_ALL;
	dbvap = VOP_GETATTR(dvp, &dbva, 0, cr, NULL) ? NULL : &dbva;
	davap = dbvap;

	if (args->where.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto out1;
	}

	if (args->where.name == NULL || *(args->where.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (rdonly(ro, dvp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (protect_zfs_mntpt(dvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opmknod__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	switch (args->what.type) {
	case NF3CHR:
	case NF3BLK:
		error = sattr3_to_vattr(
		    &args->what.mknoddata3_u.device.dev_attributes, &va);
		if (error)
			goto out;
		if (secpolicy_sys_devices(cr) != 0) {
			resp->status = NFS3ERR_PERM;
			goto out1;
		}
		if (args->what.type == NF3CHR)
			va.va_type = VCHR;
		else
			va.va_type = VBLK;
		va.va_rdev = makedevice(
		    args->what.mknoddata3_u.device.spec.specdata1,
		    args->what.mknoddata3_u.device.spec.specdata2);
		va.va_mask |= AT_TYPE | AT_RDEV;
		break;
	case NF3SOCK:
		error = sattr3_to_vattr(
		    &args->what.mknoddata3_u.pipe_attributes, &va);
		if (error)
			goto out;
		va.va_type = VSOCK;
		va.va_mask |= AT_TYPE;
		break;
	case NF3FIFO:
		error = sattr3_to_vattr(
		    &args->what.mknoddata3_u.pipe_attributes, &va);
		if (error)
			goto out;
		va.va_type = VFIFO;
		va.va_mask |= AT_TYPE;
		break;
	default:
		resp->status = NFS3ERR_BADTYPE;
		goto out1;
	}

	/*
	 * Must specify the mode.
	 */
	if (!(va.va_mask & AT_MODE)) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->where.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	excl = EXCL;

	mode = 0;

	error = VOP_CREATE(dvp, name, &va, excl, mode,
	    &vp, cr, 0, NULL, NULL);

	if (name != args->where.name)
		kmem_free(name, MAXPATHLEN + 1);

	dava.va_mask = AT_ALL;
	davap = VOP_GETATTR(dvp, &dava, 0, cr, NULL) ? NULL : &dava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(dvp, 0, cr, NULL);

	if (error)
		goto out;

	resp->status = NFS3_OK;

	error = makefh3(&resp->resok.obj.handle, vp, exi);
	if (error)
		resp->resok.obj.handle_follows = FALSE;
	else
		resp->resok.obj.handle_follows = TRUE;

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	/*
	 * Force modified metadata out to stable storage.
	 *
	 * if a underlying vp exists, pass it to VOP_FSYNC
	 */
	if (VOP_REALVP(vp, &realvp, NULL) == 0)
		(void) VOP_FSYNC(realvp, FNODSYNC, cr, NULL);
	else
		(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);

	VN_RELE(vp);

	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	vattr_to_wcc_data(dbvap, davap, &resp->resok.dir_wcc);
	DTRACE_NFSV3_5(op__mknod__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKNOD3res *, resp);
	VN_RELE(dvp);
	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__mknod__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, dvp, struct exportinfo *, exi,
	    MKNOD3res *, resp);
	if (dvp != NULL)
		VN_RELE(dvp);
	vattr_to_wcc_data(dbvap, davap, &resp->resfail.dir_wcc);
}

void *
rfs3_mknod_getfh(MKNOD3args *args)
{
	return (&args->where.dir);
}

void
rfs3_remove(REMOVE3args *args, REMOVE3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error = 0;
	vnode_t *vp;
	struct vattr *bvap;
	struct vattr bva;
	struct vattr *avap;
	struct vattr ava;
	vnode_t *targvp = NULL;
	struct sockaddr *ca;
	char *name = NULL;

	bvap = NULL;
	avap = NULL;

	vp = nfs3_fhtovp(&args->object.dir, exi);

	DTRACE_NFSV3_5(op__remove__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    REMOVE3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto err;
	}

	bva.va_mask = AT_ALL;
	bvap = VOP_GETATTR(vp, &bva, 0, cr, NULL) ? NULL : &bva;
	avap = bvap;

	if (vp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		goto err1;
	}

	if (args->object.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto err1;
	}

	if (args->object.name == NULL || *(args->object.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (rdonly(ro, vp)) {
		resp->status = NFS3ERR_ROFS;
		goto err1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opremove__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->object.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	/*
	 * Check for a conflict with a non-blocking mandatory share
	 * reservation and V4 delegations
	 */
	error = VOP_LOOKUP(vp, name, &targvp, NULL, 0,
	    NULL, cr, NULL, NULL, NULL);
	if (error != 0)
		goto err;

	if (rfs4_check_delegated(FWRITE, targvp, TRUE)) {
		resp->status = NFS3ERR_JUKEBOX;
		goto err1;
	}

	if (!nbl_need_check(targvp)) {
		error = VOP_REMOVE(vp, name, cr, NULL, 0);
	} else {
		nbl_start_crit(targvp, RW_READER);
		if (nbl_conflict(targvp, NBL_REMOVE, 0, 0, 0, NULL)) {
			error = EACCES;
		} else {
			error = VOP_REMOVE(vp, name, cr, NULL, 0);
		}
		nbl_end_crit(targvp);
	}
	VN_RELE(targvp);
	targvp = NULL;

	ava.va_mask = AT_ALL;
	avap = VOP_GETATTR(vp, &ava, 0, cr, NULL) ? NULL : &ava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, 0, cr, NULL);

	if (error)
		goto err;

	resp->status = NFS3_OK;
	vattr_to_wcc_data(bvap, avap, &resp->resok.dir_wcc);
	goto out;

err:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
err1:
	vattr_to_wcc_data(bvap, avap, &resp->resfail.dir_wcc);
out:
	DTRACE_NFSV3_5(op__remove__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    REMOVE3res *, resp);

	if (name != NULL && name != args->object.name)
		kmem_free(name, MAXPATHLEN + 1);

	if (vp != NULL)
		VN_RELE(vp);
}

void *
rfs3_remove_getfh(REMOVE3args *args)
{
	return (&args->object.dir);
}

void
rfs3_rmdir(RMDIR3args *args, RMDIR3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *bvap;
	struct vattr bva;
	struct vattr *avap;
	struct vattr ava;
	struct sockaddr *ca;
	char *name = NULL;

	bvap = NULL;
	avap = NULL;

	vp = nfs3_fhtovp(&args->object.dir, exi);

	DTRACE_NFSV3_5(op__rmdir__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    RMDIR3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto err;
	}

	bva.va_mask = AT_ALL;
	bvap = VOP_GETATTR(vp, &bva, 0, cr, NULL) ? NULL : &bva;
	avap = bvap;

	if (vp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		goto err1;
	}

	if (args->object.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto err1;
	}

	if (args->object.name == NULL || *(args->object.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (rdonly(ro, vp)) {
		resp->status = NFS3ERR_ROFS;
		goto err1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opremovedir__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->object.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	ASSERT3U(exi->exi_zoneid, ==, curzone->zone_id);
	error = VOP_RMDIR(vp, name, ZONE_ROOTVP(), cr, NULL, 0);

	if (name != args->object.name)
		kmem_free(name, MAXPATHLEN + 1);

	ava.va_mask = AT_ALL;
	avap = VOP_GETATTR(vp, &ava, 0, cr, NULL) ? NULL : &ava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, 0, cr, NULL);

	if (error) {
		/*
		 * System V defines rmdir to return EEXIST, not ENOTEMPTY,
		 * if the directory is not empty.  A System V NFS server
		 * needs to map NFS3ERR_EXIST to NFS3ERR_NOTEMPTY to transmit
		 * over the wire.
		 */
		if (error == EEXIST)
			error = ENOTEMPTY;
		goto err;
	}

	resp->status = NFS3_OK;
	vattr_to_wcc_data(bvap, avap, &resp->resok.dir_wcc);
	goto out;

err:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
err1:
	vattr_to_wcc_data(bvap, avap, &resp->resfail.dir_wcc);
out:
	DTRACE_NFSV3_5(op__rmdir__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    RMDIR3res *, resp);
	if (vp != NULL)
		VN_RELE(vp);

}

void *
rfs3_rmdir_getfh(RMDIR3args *args)
{
	return (&args->object.dir);
}

void
rfs3_rename(RENAME3args *args, RENAME3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error = 0;
	vnode_t *fvp;
	vnode_t *tvp;
	vnode_t *targvp;
	struct vattr *fbvap;
	struct vattr fbva;
	struct vattr *favap;
	struct vattr fava;
	struct vattr *tbvap;
	struct vattr tbva;
	struct vattr *tavap;
	struct vattr tava;
	nfs_fh3 *fh3;
	struct exportinfo *to_exi;
	vnode_t *srcvp = NULL;
	bslabel_t *clabel;
	struct sockaddr *ca;
	char *name = NULL;
	char *toname = NULL;

	fbvap = NULL;
	favap = NULL;
	tbvap = NULL;
	tavap = NULL;
	tvp = NULL;

	fvp = nfs3_fhtovp(&args->from.dir, exi);

	DTRACE_NFSV3_5(op__rename__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, fvp, struct exportinfo *, exi,
	    RENAME3args *, args);

	if (fvp == NULL) {
		error = ESTALE;
		goto err;
	}

	if (is_system_labeled()) {
		clabel = req->rq_label;
		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__oprename__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, fvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	fbva.va_mask = AT_ALL;
	fbvap = VOP_GETATTR(fvp, &fbva, 0, cr, NULL) ? NULL : &fbva;
	favap = fbvap;

	fh3 = &args->to.dir;
	to_exi = checkexport(&fh3->fh3_fsid, FH3TOXFIDP(fh3));
	if (to_exi == NULL) {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}
	exi_rele(to_exi);

	if (to_exi != exi) {
		resp->status = NFS3ERR_XDEV;
		goto err1;
	}

	tvp = nfs3_fhtovp(&args->to.dir, exi);
	if (tvp == NULL) {
		error = ESTALE;
		goto err;
	}

	tbva.va_mask = AT_ALL;
	tbvap = VOP_GETATTR(tvp, &tbva, 0, cr, NULL) ? NULL : &tbva;
	tavap = tbvap;

	if (fvp->v_type != VDIR || tvp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		goto err1;
	}

	if (args->from.name == nfs3nametoolong ||
	    args->to.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto err1;
	}
	if (args->from.name == NULL || *(args->from.name) == '\0' ||
	    args->to.name == NULL || *(args->to.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (rdonly(ro, tvp)) {
		resp->status = NFS3ERR_ROFS;
		goto err1;
	}

	if (protect_zfs_mntpt(tvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto err1;
	}

	if (is_system_labeled()) {
		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, tvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto err1;
			}
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->from.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	toname = nfscmd_convname(ca, exi, args->to.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (toname == NULL) {
		resp->status = NFS3ERR_INVAL;
		goto err1;
	}

	/*
	 * Check for a conflict with a non-blocking mandatory share
	 * reservation or V4 delegations.
	 */
	error = VOP_LOOKUP(fvp, name, &srcvp, NULL, 0,
	    NULL, cr, NULL, NULL, NULL);
	if (error != 0)
		goto err;

	/*
	 * If we rename a delegated file we should recall the
	 * delegation, since future opens should fail or would
	 * refer to a new file.
	 */
	if (rfs4_check_delegated(FWRITE, srcvp, FALSE)) {
		resp->status = NFS3ERR_JUKEBOX;
		goto err1;
	}

	/*
	 * Check for renaming over a delegated file.  Check nfs4_deleg_policy
	 * first to avoid VOP_LOOKUP if possible.
	 */
	if (nfs4_get_deleg_policy() != SRV_NEVER_DELEGATE &&
	    VOP_LOOKUP(tvp, toname, &targvp, NULL, 0, NULL, cr,
	    NULL, NULL, NULL) == 0) {

		if (rfs4_check_delegated(FWRITE, targvp, TRUE)) {
			VN_RELE(targvp);
			resp->status = NFS3ERR_JUKEBOX;
			goto err1;
		}
		VN_RELE(targvp);
	}

	if (!nbl_need_check(srcvp)) {
		error = VOP_RENAME(fvp, name, tvp, toname, cr, NULL, 0);
	} else {
		nbl_start_crit(srcvp, RW_READER);
		if (nbl_conflict(srcvp, NBL_RENAME, 0, 0, 0, NULL))
			error = EACCES;
		else
			error = VOP_RENAME(fvp, name, tvp, toname, cr, NULL, 0);
		nbl_end_crit(srcvp);
	}
	if (error == 0)
		vn_renamepath(tvp, srcvp, args->to.name,
		    strlen(args->to.name));
	VN_RELE(srcvp);
	srcvp = NULL;

	fava.va_mask = AT_ALL;
	favap = VOP_GETATTR(fvp, &fava, 0, cr, NULL) ? NULL : &fava;
	tava.va_mask = AT_ALL;
	tavap = VOP_GETATTR(tvp, &tava, 0, cr, NULL) ? NULL : &tava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(fvp, 0, cr, NULL);
	(void) VOP_FSYNC(tvp, 0, cr, NULL);

	if (error)
		goto err;

	resp->status = NFS3_OK;
	vattr_to_wcc_data(fbvap, favap, &resp->resok.fromdir_wcc);
	vattr_to_wcc_data(tbvap, tavap, &resp->resok.todir_wcc);
	goto out;

err:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else {
		resp->status = puterrno3(error);
	}
err1:
	vattr_to_wcc_data(fbvap, favap, &resp->resfail.fromdir_wcc);
	vattr_to_wcc_data(tbvap, tavap, &resp->resfail.todir_wcc);

out:
	if (name != NULL && name != args->from.name)
		kmem_free(name, MAXPATHLEN + 1);
	if (toname != NULL && toname != args->to.name)
		kmem_free(toname, MAXPATHLEN + 1);

	DTRACE_NFSV3_5(op__rename__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, fvp, struct exportinfo *, exi,
	    RENAME3res *, resp);
	if (fvp != NULL)
		VN_RELE(fvp);
	if (tvp != NULL)
		VN_RELE(tvp);
}

void *
rfs3_rename_getfh(RENAME3args *args)
{
	return (&args->from.dir);
}

void
rfs3_link(LINK3args *args, LINK3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	vnode_t *dvp;
	struct vattr *vap;
	struct vattr va;
	struct vattr *bvap;
	struct vattr bva;
	struct vattr *avap;
	struct vattr ava;
	nfs_fh3	*fh3;
	struct exportinfo *to_exi;
	bslabel_t *clabel;
	struct sockaddr *ca;
	char *name = NULL;

	vap = NULL;
	bvap = NULL;
	avap = NULL;
	dvp = NULL;

	vp = nfs3_fhtovp(&args->file, exi);

	DTRACE_NFSV3_5(op__link__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    LINK3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	fh3 = &args->link.dir;
	to_exi = checkexport(&fh3->fh3_fsid, FH3TOXFIDP(fh3));
	if (to_exi == NULL) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}
	exi_rele(to_exi);

	if (to_exi != exi) {
		resp->status = NFS3ERR_XDEV;
		goto out1;
	}

	if (is_system_labeled()) {
		clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__oplink__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	dvp = nfs3_fhtovp(&args->link.dir, exi);
	if (dvp == NULL) {
		error = ESTALE;
		goto out;
	}

	bva.va_mask = AT_ALL;
	bvap = VOP_GETATTR(dvp, &bva, 0, cr, NULL) ? NULL : &bva;

	if (dvp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		goto out1;
	}

	if (args->link.name == nfs3nametoolong) {
		resp->status = NFS3ERR_NAMETOOLONG;
		goto out1;
	}

	if (args->link.name == NULL || *(args->link.name) == '\0') {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (rdonly(ro, dvp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (protect_zfs_mntpt(dvp) != 0) {
		resp->status = NFS3ERR_ACCES;
		goto out1;
	}

	if (is_system_labeled()) {
		DTRACE_PROBE2(tx__rfs3__log__info__oplinkdir__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, dvp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	name = nfscmd_convname(ca, exi, args->link.name,
	    NFSCMD_CONV_INBOUND, MAXPATHLEN + 1);

	if (name == NULL) {
		resp->status = NFS3ERR_SERVERFAULT;
		goto out1;
	}

	error = VOP_LINK(dvp, vp, name, cr, NULL, 0);

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;
	ava.va_mask = AT_ALL;
	avap = VOP_GETATTR(dvp, &ava, 0, cr, NULL) ? NULL : &ava;

	/*
	 * Force modified data and metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);
	(void) VOP_FSYNC(dvp, 0, cr, NULL);

	if (error)
		goto out;

	VN_RELE(dvp);

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.file_attributes);
	vattr_to_wcc_data(bvap, avap, &resp->resok.linkdir_wcc);

	DTRACE_NFSV3_5(op__link__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    LINK3res *, resp);

	VN_RELE(vp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	if (name != NULL && name != args->link.name)
		kmem_free(name, MAXPATHLEN + 1);

	DTRACE_NFSV3_5(op__link__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    LINK3res *, resp);

	if (vp != NULL)
		VN_RELE(vp);
	if (dvp != NULL)
		VN_RELE(dvp);
	vattr_to_post_op_attr(vap, &resp->resfail.file_attributes);
	vattr_to_wcc_data(bvap, avap, &resp->resfail.linkdir_wcc);
}

void *
rfs3_link_getfh(LINK3args *args)
{
	return (&args->file);
}

#ifdef nextdp
#undef nextdp
#endif
#define	nextdp(dp)	((struct dirent64 *)((char *)(dp) + (dp)->d_reclen))

/* ARGSUSED */
void
rfs3_readdir(READDIR3args *args, READDIR3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	struct iovec iov;
	struct uio uio;
	int iseof;

	count3 count = args->count;
	count3 size;		/* size of the READDIR3resok structure */

	size_t datasz;
	char *data = NULL;
	dirent64_t *dp;

	struct sockaddr *ca;
	entry3 **eptr;
	entry3 *entry;

	vp = nfs3_fhtovp(&args->dir, exi);

	DTRACE_NFSV3_5(op__readdir__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIR3args *, args);

	if (vp == NULL) {
		resp->status = NFS3ERR_STALE;
		vap = NULL;
		goto out1;
	}

	if (vp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		vap = NULL;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opreaddir__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				vap = NULL;
				goto out1;
			}
		}
	}

	(void) VOP_RWLOCK(vp, V_WRITELOCK_FALSE, NULL);

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	error = VOP_ACCESS(vp, VREAD, 0, cr, NULL);
	if (error)
		goto out;

	/*
	 * Don't allow arbitrary counts for allocation
	 */
	if (count > rfs3_tsize(req))
		count = rfs3_tsize(req);

	/*
	 * struct READDIR3resok:
	 *   dir_attributes:	1 + NFS3_SIZEOF_FATTR3
	 *   cookieverf:	2
	 *   entries (bool):	1
	 *   eof:		1
	 */
	size = (1 + NFS3_SIZEOF_FATTR3 + 2 + 1 + 1) * BYTES_PER_XDR_UNIT;

	if (size > count) {
		resp->status = NFS3ERR_TOOSMALL;
		goto out1;
	}

	/*
	 * This is simplification.  The dirent64_t size is not the same as the
	 * size of XDR representation of entry3, but the sizes are similar so
	 * we'll assume they are same.  This assumption should not cause any
	 * harm.  In worst case we will need to issue VOP_READDIR() once more.
	 */
	datasz = count;

	/*
	 * Make sure that there is room to read at least one entry
	 * if any are available.
	 */
	if (datasz < DIRENT64_RECLEN(MAXNAMELEN))
		datasz = DIRENT64_RECLEN(MAXNAMELEN);

	data = kmem_alloc(datasz, KM_NOSLEEP);
	if (data == NULL) {
		/* The allocation failed; downsize and wait for it this time */
		if (datasz > MAXBSIZE)
			datasz = MAXBSIZE;
		data = kmem_alloc(datasz, KM_SLEEP);
	}

	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_CACHED;
	uio.uio_loffset = (offset_t)args->cookie;
	uio.uio_resid = datasz;

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	eptr = &resp->resok.reply.entries;
	entry = NULL;

getmoredents:
	iov.iov_base = data;
	iov.iov_len = datasz;

	error = VOP_READDIR(vp, &uio, cr, &iseof, NULL, 0);
	if (error) {
		iseof = 0;
		goto done;
	}

	if (iov.iov_len == datasz)
		goto done;

	for (dp = (dirent64_t *)data; (char *)dp - data < datasz - iov.iov_len;
	    dp = nextdp(dp)) {
		char *name;
		count3 esize;

		if (dp->d_ino == 0) {
			if (entry != NULL)
				entry->cookie = (cookie3)dp->d_off;
			continue;
		}

		name = nfscmd_convname(ca, exi, dp->d_name,
		    NFSCMD_CONV_OUTBOUND, MAXPATHLEN + 1);
		if (name == NULL) {
			if (entry != NULL)
				entry->cookie = (cookie3)dp->d_off;
			continue;
		}

		/*
		 * struct entry3:
		 *   fileid:		2
		 *   name (length):	1
		 *   name (data):	length (rounded up)
		 *   cookie:		2
		 *   nextentry (bool):	1
		 */
		esize = (2 + 1 + 2 + 1) * BYTES_PER_XDR_UNIT +
		    RNDUP(strlen(name));

		/* If the new entry does not fit, discard it */
		if (esize > count - size) {
			if (name != dp->d_name)
				kmem_free(name, MAXPATHLEN + 1);
			iseof = 0;
			goto done;
		}

		entry = kmem_alloc(sizeof (entry3), KM_SLEEP);

		entry->fileid = (fileid3)dp->d_ino;
		entry->name = strdup(name);
		if (name != dp->d_name)
			kmem_free(name, MAXPATHLEN + 1);
		entry->cookie = (cookie3)dp->d_off;

		size += esize;

		/* Add the entry to the linked list */
		*eptr = entry;
		eptr = &entry->nextentry;
	}

	if (!iseof && size < count) {
		uio.uio_resid = MIN(datasz, MAXBSIZE);
		goto getmoredents;
	}

done:
	*eptr = NULL;

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	if (!iseof && resp->resok.reply.entries == NULL) {
		if (error)
			goto out;
		resp->status = NFS3ERR_TOOSMALL;
		goto out1;
	}

	VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);

#if 0 /* notyet */
	/*
	 * Don't do this.  It causes local disk writes when just
	 * reading the file and the overhead is deemed larger
	 * than the benefit.
	 */
	/*
	 * Force modified metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);
#endif

	resp->status = NFS3_OK;
	resp->resok.cookieverf = 0;
	resp->resok.reply.eof = iseof ? TRUE : FALSE;

	vattr_to_post_op_attr(vap, &resp->resok.dir_attributes);

	DTRACE_NFSV3_5(op__readdir__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIR3res *, resp);

	VN_RELE(vp);

	if (data != NULL)
		kmem_free(data, datasz);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	vattr_to_post_op_attr(vap, &resp->resfail.dir_attributes);

	DTRACE_NFSV3_5(op__readdir__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIR3res *, resp);

	if (vp != NULL) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);
		VN_RELE(vp);
	}

	if (data != NULL)
		kmem_free(data, datasz);
}

void *
rfs3_readdir_getfh(READDIR3args *args)
{
	return (&args->dir);
}

void
rfs3_readdir_free(READDIR3res *resp)
{
	if (resp->status == NFS3_OK) {
		entry3 *entry, *nentry;

		for (entry = resp->resok.reply.entries; entry != NULL;
		    entry = nentry) {
			nentry = entry->nextentry;
			strfree(entry->name);
			kmem_free(entry, sizeof (entry3));
		}
	}
}

#ifdef nextdp
#undef nextdp
#endif
#define	nextdp(dp)	((struct dirent64 *)((char *)(dp) + (dp)->d_reclen))

/* ARGSUSED */
void
rfs3_readdirplus(READDIRPLUS3args *args, READDIRPLUS3res *resp,
    struct exportinfo *exi, struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	struct iovec iov;
	struct uio uio;
	int iseof;

	count3 dircount = args->dircount;
	count3 maxcount = args->maxcount;
	count3 dirsize = 0;
	count3 size;		/* size of the READDIRPLUS3resok structure */

	size_t datasz;
	char *data = NULL;
	dirent64_t *dp;

	struct sockaddr *ca;
	entryplus3 **eptr;
	entryplus3 *entry;

	vp = nfs3_fhtovp(&args->dir, exi);

	DTRACE_NFSV3_5(op__readdirplus__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIRPLUS3args *, args);

	if (vp == NULL) {
		resp->status = NFS3ERR_STALE;
		vap = NULL;
		goto out1;
	}

	if (vp->v_type != VDIR) {
		resp->status = NFS3ERR_NOTDIR;
		vap = NULL;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opreaddirplus__clabel,
		    char *, "got client label from request(1)",
		    struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				vap = NULL;
				goto out1;
			}
		}
	}

	(void) VOP_RWLOCK(vp, V_WRITELOCK_FALSE, NULL);

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	error = VOP_ACCESS(vp, VREAD, 0, cr, NULL);
	if (error)
		goto out;

	/*
	 * Don't allow arbitrary counts for allocation
	 */
	if (maxcount > rfs3_tsize(req))
		maxcount = rfs3_tsize(req);

	/*
	 * struct READDIRPLUS3resok:
	 *   dir_attributes:	1 + NFS3_SIZEOF_FATTR3
	 *   cookieverf:	2
	 *   entries (bool):	1
	 *   eof:		1
	 */
	size = (1 + NFS3_SIZEOF_FATTR3 + 2 + 1 + 1) * BYTES_PER_XDR_UNIT;

	if (size > maxcount) {
		resp->status = NFS3ERR_TOOSMALL;
		goto out1;
	}

	/*
	 * This is simplification.  The dirent64_t size is not the same as the
	 * size of XDR representation of entryplus3 (excluding attributes and
	 * handle), but the sizes are similar so we'll assume they are same.
	 * This assumption should not cause any harm.  In worst case we will
	 * need to issue VOP_READDIR() once more.
	 */

	datasz = MIN(dircount, maxcount);

	/*
	 * Make sure that there is room to read at least one entry
	 * if any are available.
	 */
	if (datasz < DIRENT64_RECLEN(MAXNAMELEN))
		datasz = DIRENT64_RECLEN(MAXNAMELEN);

	data = kmem_alloc(datasz, KM_NOSLEEP);
	if (data == NULL) {
		/* The allocation failed; downsize and wait for it this time */
		if (datasz > MAXBSIZE)
			datasz = MAXBSIZE;
		data = kmem_alloc(datasz, KM_SLEEP);
	}

	uio.uio_iov = &iov;
	uio.uio_iovcnt = 1;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_CACHED;
	uio.uio_loffset = (offset_t)args->cookie;
	uio.uio_resid = datasz;

	ca = (struct sockaddr *)svc_getrpccaller(req->rq_xprt)->buf;
	eptr = &resp->resok.reply.entries;
	entry = NULL;

getmoredents:
	iov.iov_base = data;
	iov.iov_len = datasz;

	error = VOP_READDIR(vp, &uio, cr, &iseof, NULL, 0);
	if (error) {
		iseof = 0;
		goto done;
	}

	if (iov.iov_len == datasz)
		goto done;

	for (dp = (dirent64_t *)data; (char *)dp - data < datasz - iov.iov_len;
	    dp = nextdp(dp)) {
		char *name;
		vnode_t *nvp;
		count3 edirsize;
		count3 esize;

		if (dp->d_ino == 0) {
			if (entry != NULL)
				entry->cookie = (cookie3)dp->d_off;
			continue;
		}

		name = nfscmd_convname(ca, exi, dp->d_name,
		    NFSCMD_CONV_OUTBOUND, MAXPATHLEN + 1);
		if (name == NULL) {
			if (entry != NULL)
				entry->cookie = (cookie3)dp->d_off;
			continue;
		}

		/*
		 * struct entryplus3:
		 *   fileid:		2
		 *   name (length):	1
		 *   name (data):	length (rounded up)
		 *   cookie:		2
		 */
		edirsize = (2 + 1 + 2) * BYTES_PER_XDR_UNIT +
		    RNDUP(strlen(name));

		/*
		 * struct entryplus3:
		 *   attributes_follow:	1
		 *   handle_follows:	1
		 *   nextentry (bool):	1
		 */
		esize = edirsize + (1 + 1 + 1) * BYTES_PER_XDR_UNIT;

		/* If the new entry does not fit, we are done */
		if (edirsize > dircount - dirsize || esize > maxcount - size) {
			if (name != dp->d_name)
				kmem_free(name, MAXPATHLEN + 1);
			iseof = 0;
			error = 0;
			goto done;
		}

		entry = kmem_alloc(sizeof (entryplus3), KM_SLEEP);

		entry->fileid = (fileid3)dp->d_ino;
		entry->name = strdup(name);
		if (name != dp->d_name)
			kmem_free(name, MAXPATHLEN + 1);
		entry->cookie = (cookie3)dp->d_off;

		error = VOP_LOOKUP(vp, dp->d_name, &nvp, NULL, 0, NULL, cr,
		    NULL, NULL, NULL);
		if (error) {
			entry->name_attributes.attributes = FALSE;
			entry->name_handle.handle_follows = FALSE;
		} else {
			struct vattr nva;
			struct vattr *nvap;

			nva.va_mask = AT_ALL;
			nvap = rfs4_delegated_getattr(nvp, &nva, 0, cr) ? NULL :
			    &nva;

			/* Lie about the object type for a referral */
			if (nvap != NULL && vn_is_nfs_reparse(nvp, cr))
				nvap->va_type = VLNK;

			if (vn_ismntpt(nvp)) {
				entry->name_attributes.attributes = FALSE;
				entry->name_handle.handle_follows = FALSE;
			} else {
				vattr_to_post_op_attr(nvap,
				    &entry->name_attributes);

				error = makefh3(&entry->name_handle.handle, nvp,
				    exi);
				if (!error)
					entry->name_handle.handle_follows =
					    TRUE;
				else
					entry->name_handle.handle_follows =
					    FALSE;
			}

			VN_RELE(nvp);
		}

		/*
		 * struct entryplus3 (optionally):
		 *   attributes:	NFS3_SIZEOF_FATTR3
		 *   handle length:	1
		 *   handle data:	length (rounded up)
		 */
		if (entry->name_attributes.attributes == TRUE)
			esize += NFS3_SIZEOF_FATTR3 * BYTES_PER_XDR_UNIT;
		if (entry->name_handle.handle_follows == TRUE)
			esize += 1 * BYTES_PER_XDR_UNIT +
			    RNDUP(entry->name_handle.handle.fh3_length);

		/* If the new entry does not fit, discard it */
		if (esize > maxcount - size) {
			strfree(entry->name);
			kmem_free(entry, sizeof (entryplus3));
			iseof = 0;
			error = 0;
			goto done;
		}

		dirsize += edirsize;
		size += esize;

		/* Add the entry to the linked list */
		*eptr = entry;
		eptr = &entry->nextentry;
	}

	if (!iseof && dirsize < dircount && size < maxcount) {
		uio.uio_resid = MIN(datasz, MAXBSIZE);
		goto getmoredents;
	}

done:
	*eptr = NULL;

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	if (!iseof && resp->resok.reply.entries == NULL) {
		if (error)
			goto out;
		resp->status = NFS3ERR_TOOSMALL;
		goto out1;
	}

	VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);

#if 0 /* notyet */
	/*
	 * Don't do this.  It causes local disk writes when just
	 * reading the file and the overhead is deemed larger
	 * than the benefit.
	 */
	/*
	 * Force modified metadata out to stable storage.
	 */
	(void) VOP_FSYNC(vp, FNODSYNC, cr, NULL);
#endif

	resp->status = NFS3_OK;
	resp->resok.cookieverf = 0;
	resp->resok.reply.eof = iseof ? TRUE : FALSE;

	vattr_to_post_op_attr(vap, &resp->resok.dir_attributes);

	DTRACE_NFSV3_5(op__readdirplus__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIRPLUS3res *, resp);

	VN_RELE(vp);

	if (data != NULL)
		kmem_free(data, datasz);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else {
		resp->status = puterrno3(error);
	}
out1:
	vattr_to_post_op_attr(vap, &resp->resfail.dir_attributes);

	DTRACE_NFSV3_5(op__readdirplus__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    READDIRPLUS3res *, resp);

	if (vp != NULL) {
		VOP_RWUNLOCK(vp, V_WRITELOCK_FALSE, NULL);
		VN_RELE(vp);
	}

	if (data != NULL)
		kmem_free(data, datasz);
}

void *
rfs3_readdirplus_getfh(READDIRPLUS3args *args)
{
	return (&args->dir);
}

void
rfs3_readdirplus_free(READDIRPLUS3res *resp)
{
	if (resp->status == NFS3_OK) {
		entryplus3 *entry, *nentry;

		for (entry = resp->resok.reply.entries; entry != NULL;
		    entry = nentry) {
			nentry = entry->nextentry;
			strfree(entry->name);
			kmem_free(entry, sizeof (entryplus3));
		}
	}
}

/* ARGSUSED */
void
rfs3_fsstat(FSSTAT3args *args, FSSTAT3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	struct statvfs64 sb;

	vap = NULL;

	vp = nfs3_fhtovp(&args->fsroot, exi);

	DTRACE_NFSV3_5(op__fsstat__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    FSSTAT3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opfsstat__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	error = VFS_STATVFS(vp->v_vfsp, &sb);

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	if (error)
		goto out;

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	if (sb.f_blocks != (fsblkcnt64_t)-1)
		resp->resok.tbytes = (size3)sb.f_frsize * (size3)sb.f_blocks;
	else
		resp->resok.tbytes = (size3)sb.f_blocks;
	if (sb.f_bfree != (fsblkcnt64_t)-1)
		resp->resok.fbytes = (size3)sb.f_frsize * (size3)sb.f_bfree;
	else
		resp->resok.fbytes = (size3)sb.f_bfree;
	if (sb.f_bavail != (fsblkcnt64_t)-1)
		resp->resok.abytes = (size3)sb.f_frsize * (size3)sb.f_bavail;
	else
		resp->resok.abytes = (size3)sb.f_bavail;
	resp->resok.tfiles = (size3)sb.f_files;
	resp->resok.ffiles = (size3)sb.f_ffree;
	resp->resok.afiles = (size3)sb.f_favail;
	resp->resok.invarsec = 0;

	DTRACE_NFSV3_5(op__fsstat__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    FSSTAT3res *, resp);
	VN_RELE(vp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__fsstat__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    FSSTAT3res *, resp);

	if (vp != NULL)
		VN_RELE(vp);
	vattr_to_post_op_attr(vap, &resp->resfail.obj_attributes);
}

void *
rfs3_fsstat_getfh(FSSTAT3args *args)
{
	return (&args->fsroot);
}

/* ARGSUSED */
void
rfs3_fsinfo(FSINFO3args *args, FSINFO3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	uint32_t xfer_size;
	ulong_t l = 0;
	int error;

	vp = nfs3_fhtovp(&args->fsroot, exi);

	DTRACE_NFSV3_5(op__fsinfo__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    FSINFO3args *, args);

	if (vp == NULL) {
		if (curthread->t_flag & T_WOULDBLOCK) {
			curthread->t_flag &= ~T_WOULDBLOCK;
			resp->status = NFS3ERR_JUKEBOX;
		} else
			resp->status = NFS3ERR_STALE;
		vattr_to_post_op_attr(NULL, &resp->resfail.obj_attributes);
		goto out;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opfsinfo__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_STALE;
				vattr_to_post_op_attr(NULL,
				    &resp->resfail.obj_attributes);
				goto out;
			}
		}
	}

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	xfer_size = rfs3_tsize(req);
	resp->resok.rtmax = xfer_size;
	resp->resok.rtpref = xfer_size;
	resp->resok.rtmult = DEV_BSIZE;
	resp->resok.wtmax = xfer_size;
	resp->resok.wtpref = xfer_size;
	resp->resok.wtmult = DEV_BSIZE;
	resp->resok.dtpref = MAXBSIZE;

	/*
	 * Large file spec: want maxfilesize based on limit of
	 * underlying filesystem.  We can guess 2^31-1 if need be.
	 */
	error = VOP_PATHCONF(vp, _PC_FILESIZEBITS, &l, cr, NULL);
	if (error) {
		resp->status = puterrno3(error);
		goto out;
	}

	/*
	 * If the underlying file system does not support _PC_FILESIZEBITS,
	 * return a reasonable default. Note that error code on VOP_PATHCONF
	 * will be 0, even if the underlying file system does not support
	 * _PC_FILESIZEBITS.
	 */
	if (l == (ulong_t)-1) {
		resp->resok.maxfilesize = MAXOFF32_T;
	} else {
		if (l >= (sizeof (uint64_t) * 8))
			resp->resok.maxfilesize = INT64_MAX;
		else
			resp->resok.maxfilesize = (1LL << (l-1)) - 1;
	}

	resp->resok.time_delta.seconds = 0;
	resp->resok.time_delta.nseconds = 1000;
	resp->resok.properties = FSF3_LINK | FSF3_SYMLINK |
	    FSF3_HOMOGENEOUS | FSF3_CANSETTIME;

	DTRACE_NFSV3_5(op__fsinfo__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    FSINFO3res *, resp);

	VN_RELE(vp);

	return;

out:
	DTRACE_NFSV3_5(op__fsinfo__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, NULL, struct exportinfo *, exi,
	    FSINFO3res *, resp);
	if (vp != NULL)
		VN_RELE(vp);
}

void *
rfs3_fsinfo_getfh(FSINFO3args *args)
{
	return (&args->fsroot);
}

/* ARGSUSED */
void
rfs3_pathconf(PATHCONF3args *args, PATHCONF3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	int error;
	vnode_t *vp;
	struct vattr *vap;
	struct vattr va;
	ulong_t val;

	vap = NULL;

	vp = nfs3_fhtovp(&args->object, exi);

	DTRACE_NFSV3_5(op__pathconf__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    PATHCONF3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__oppathconf__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, DOMINANCE_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	va.va_mask = AT_ALL;
	vap = VOP_GETATTR(vp, &va, 0, cr, NULL) ? NULL : &va;

	error = VOP_PATHCONF(vp, _PC_LINK_MAX, &val, cr, NULL);
	if (error)
		goto out;
	resp->resok.info.link_max = (uint32)val;

	error = VOP_PATHCONF(vp, _PC_NAME_MAX, &val, cr, NULL);
	if (error)
		goto out;
	resp->resok.info.name_max = (uint32)val;

	error = VOP_PATHCONF(vp, _PC_NO_TRUNC, &val, cr, NULL);
	if (error)
		goto out;
	if (val == 1)
		resp->resok.info.no_trunc = TRUE;
	else
		resp->resok.info.no_trunc = FALSE;

	error = VOP_PATHCONF(vp, _PC_CHOWN_RESTRICTED, &val, cr, NULL);
	if (error)
		goto out;
	if (val == 1)
		resp->resok.info.chown_restricted = TRUE;
	else
		resp->resok.info.chown_restricted = FALSE;

	resp->status = NFS3_OK;
	vattr_to_post_op_attr(vap, &resp->resok.obj_attributes);
	resp->resok.info.case_insensitive = FALSE;
	resp->resok.info.case_preserving = TRUE;
	DTRACE_NFSV3_5(op__pathconf__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    PATHCONF3res *, resp);
	VN_RELE(vp);
	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__pathconf__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    PATHCONF3res *, resp);
	if (vp != NULL)
		VN_RELE(vp);
	vattr_to_post_op_attr(vap, &resp->resfail.obj_attributes);
}

void *
rfs3_pathconf_getfh(PATHCONF3args *args)
{
	return (&args->object);
}

void
rfs3_commit(COMMIT3args *args, COMMIT3res *resp, struct exportinfo *exi,
    struct svc_req *req, cred_t *cr, bool_t ro)
{
	nfs3_srv_t *ns;
	int error;
	vnode_t *vp;
	struct vattr *bvap;
	struct vattr bva;
	struct vattr *avap;
	struct vattr ava;

	bvap = NULL;
	avap = NULL;

	vp = nfs3_fhtovp(&args->file, exi);

	DTRACE_NFSV3_5(op__commit__start, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    COMMIT3args *, args);

	if (vp == NULL) {
		error = ESTALE;
		goto out;
	}

	ASSERT3U(curzone->zone_id, ==, exi->exi_zoneid); /* exi is non-NULL. */
	ns = nfs3_get_srv();
	bva.va_mask = AT_ALL;
	error = VOP_GETATTR(vp, &bva, 0, cr, NULL);

	/*
	 * If we can't get the attributes, then we can't do the
	 * right access checking.  So, we'll fail the request.
	 */
	if (error)
		goto out;

	bvap = &bva;

	if (rdonly(ro, vp)) {
		resp->status = NFS3ERR_ROFS;
		goto out1;
	}

	if (vp->v_type != VREG) {
		resp->status = NFS3ERR_INVAL;
		goto out1;
	}

	if (is_system_labeled()) {
		bslabel_t *clabel = req->rq_label;

		ASSERT(clabel != NULL);
		DTRACE_PROBE2(tx__rfs3__log__info__opcommit__clabel, char *,
		    "got client label from request(1)", struct svc_req *, req);

		if (!blequal(&l_admin_low->tsl_label, clabel)) {
			if (!do_rfs_label_check(clabel, vp, EQUALITY_CHECK,
			    exi)) {
				resp->status = NFS3ERR_ACCES;
				goto out1;
			}
		}
	}

	if (crgetuid(cr) != bva.va_uid &&
	    (error = VOP_ACCESS(vp, VWRITE, 0, cr, NULL)))
		goto out;

	error = VOP_FSYNC(vp, FSYNC, cr, NULL);

	ava.va_mask = AT_ALL;
	avap = VOP_GETATTR(vp, &ava, 0, cr, NULL) ? NULL : &ava;

	if (error)
		goto out;

	resp->status = NFS3_OK;
	vattr_to_wcc_data(bvap, avap, &resp->resok.file_wcc);
	resp->resok.verf = ns->write3verf;

	DTRACE_NFSV3_5(op__commit__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    COMMIT3res *, resp);

	VN_RELE(vp);

	return;

out:
	if (curthread->t_flag & T_WOULDBLOCK) {
		curthread->t_flag &= ~T_WOULDBLOCK;
		resp->status = NFS3ERR_JUKEBOX;
	} else
		resp->status = puterrno3(error);
out1:
	DTRACE_NFSV3_5(op__commit__done, struct svc_req *, req,
	    cred_t *, cr, vnode_t *, vp, struct exportinfo *, exi,
	    COMMIT3res *, resp);

	if (vp != NULL)
		VN_RELE(vp);
	vattr_to_wcc_data(bvap, avap, &resp->resfail.file_wcc);
}

void *
rfs3_commit_getfh(COMMIT3args *args)
{
	return (&args->file);
}

static int
sattr3_to_vattr(sattr3 *sap, struct vattr *vap)
{

	vap->va_mask = 0;

	if (sap->mode.set_it) {
		vap->va_mode = (mode_t)sap->mode.mode;
		vap->va_mask |= AT_MODE;
	}
	if (sap->uid.set_it) {
		vap->va_uid = (uid_t)sap->uid.uid;
		vap->va_mask |= AT_UID;
	}
	if (sap->gid.set_it) {
		vap->va_gid = (gid_t)sap->gid.gid;
		vap->va_mask |= AT_GID;
	}
	if (sap->size.set_it) {
		if (sap->size.size > (size3)((u_longlong_t)-1))
			return (EINVAL);
		vap->va_size = sap->size.size;
		vap->va_mask |= AT_SIZE;
	}
	if (sap->atime.set_it == SET_TO_CLIENT_TIME) {
#ifndef _LP64
		/* check time validity */
		if (!NFS3_TIME_OK(sap->atime.atime.seconds))
			return (EOVERFLOW);
#endif
		/*
		 * nfs protocol defines times as unsigned so don't extend sign,
		 * unless sysadmin set nfs_allow_preepoch_time.
		 */
		NFS_TIME_T_CONVERT(vap->va_atime.tv_sec,
		    sap->atime.atime.seconds);
		vap->va_atime.tv_nsec = (uint32_t)sap->atime.atime.nseconds;
		vap->va_mask |= AT_ATIME;
	} else if (sap->atime.set_it == SET_TO_SERVER_TIME) {
		gethrestime(&vap->va_atime);
		vap->va_mask |= AT_ATIME;
	}
	if (sap->mtime.set_it == SET_TO_CLIENT_TIME) {
#ifndef _LP64
		/* check time validity */
		if (!NFS3_TIME_OK(sap->mtime.mtime.seconds))
			return (EOVERFLOW);
#endif
		/*
		 * nfs protocol defines times as unsigned so don't extend sign,
		 * unless sysadmin set nfs_allow_preepoch_time.
		 */
		NFS_TIME_T_CONVERT(vap->va_mtime.tv_sec,
		    sap->mtime.mtime.seconds);
		vap->va_mtime.tv_nsec = (uint32_t)sap->mtime.mtime.nseconds;
		vap->va_mask |= AT_MTIME;
	} else if (sap->mtime.set_it == SET_TO_SERVER_TIME) {
		gethrestime(&vap->va_mtime);
		vap->va_mask |= AT_MTIME;
	}

	return (0);
}

static const ftype3 vt_to_nf3[] = {
	0, NF3REG, NF3DIR, NF3BLK, NF3CHR, NF3LNK, NF3FIFO, 0, 0, NF3SOCK, 0
};

static int
vattr_to_fattr3(struct vattr *vap, fattr3 *fap)
{

	ASSERT(vap->va_type >= VNON && vap->va_type <= VBAD);
	/* Return error if time or size overflow */
	if (! (NFS_VAP_TIME_OK(vap) && NFS3_SIZE_OK(vap->va_size))) {
		return (EOVERFLOW);
	}
	fap->type = vt_to_nf3[vap->va_type];
	fap->mode = (mode3)(vap->va_mode & MODEMASK);
	fap->nlink = (uint32)vap->va_nlink;
	if (vap->va_uid == UID_NOBODY)
		fap->uid = (uid3)NFS_UID_NOBODY;
	else
		fap->uid = (uid3)vap->va_uid;
	if (vap->va_gid == GID_NOBODY)
		fap->gid = (gid3)NFS_GID_NOBODY;
	else
		fap->gid = (gid3)vap->va_gid;
	fap->size = (size3)vap->va_size;
	fap->used = (size3)DEV_BSIZE * (size3)vap->va_nblocks;
	fap->rdev.specdata1 = (uint32)getmajor(vap->va_rdev);
	fap->rdev.specdata2 = (uint32)getminor(vap->va_rdev);
	fap->fsid = (uint64)vap->va_fsid;
	fap->fileid = (fileid3)vap->va_nodeid;
	fap->atime.seconds = vap->va_atime.tv_sec;
	fap->atime.nseconds = vap->va_atime.tv_nsec;
	fap->mtime.seconds = vap->va_mtime.tv_sec;
	fap->mtime.nseconds = vap->va_mtime.tv_nsec;
	fap->ctime.seconds = vap->va_ctime.tv_sec;
	fap->ctime.nseconds = vap->va_ctime.tv_nsec;
	return (0);
}

static int
vattr_to_wcc_attr(struct vattr *vap, wcc_attr *wccap)
{

	/* Return error if time or size overflow */
	if (!(NFS_TIME_T_OK(vap->va_mtime.tv_sec) &&
	    NFS_TIME_T_OK(vap->va_ctime.tv_sec) &&
	    NFS3_SIZE_OK(vap->va_size))) {
		return (EOVERFLOW);
	}
	wccap->size = (size3)vap->va_size;
	wccap->mtime.seconds = vap->va_mtime.tv_sec;
	wccap->mtime.nseconds = vap->va_mtime.tv_nsec;
	wccap->ctime.seconds = vap->va_ctime.tv_sec;
	wccap->ctime.nseconds = vap->va_ctime.tv_nsec;
	return (0);
}

static void
vattr_to_pre_op_attr(struct vattr *vap, pre_op_attr *poap)
{

	/* don't return attrs if time overflow */
	if ((vap != NULL) && !vattr_to_wcc_attr(vap, &poap->attr)) {
		poap->attributes = TRUE;
	} else
		poap->attributes = FALSE;
}

void
vattr_to_post_op_attr(struct vattr *vap, post_op_attr *poap)
{

	/* don't return attrs if time overflow */
	if ((vap != NULL) && !vattr_to_fattr3(vap, &poap->attr)) {
		poap->attributes = TRUE;
	} else
		poap->attributes = FALSE;
}

static void
vattr_to_wcc_data(struct vattr *bvap, struct vattr *avap, wcc_data *wccp)
{
	vattr_to_pre_op_attr(bvap, &wccp->before);
	vattr_to_post_op_attr(avap, &wccp->after);
}

static int
rdma_setup_read_data3(READ3args *args, READ3resok *rok)
{
	struct clist	*wcl;
	int		wlist_len;
	count3		count = rok->count;

	wcl = args->wlist;
	if (rdma_setup_read_chunks(wcl, count, &wlist_len) == FALSE)
		return (FALSE);

	wcl = args->wlist;
	rok->wlist_len = wlist_len;
	rok->wlist = wcl;
	return (TRUE);
}

void
rfs3_srv_zone_init(nfs_globals_t *ng)
{
	nfs3_srv_t *ns;
	struct rfs3_verf_overlay {
		uint_t id; /* a "unique" identifier */
		int ts; /* a unique timestamp */
	} *verfp;
	timestruc_t now;

	ns = kmem_zalloc(sizeof (*ns), KM_SLEEP);

	/*
	 * The following algorithm attempts to find a unique verifier
	 * to be used as the write verifier returned from the server
	 * to the client.  It is important that this verifier change
	 * whenever the server reboots.  Of secondary importance, it
	 * is important for the verifier to be unique between two
	 * different servers.
	 *
	 * Thus, an attempt is made to use the system hostid and the
	 * current time in seconds when the nfssrv kernel module is
	 * loaded.  It is assumed that an NFS server will not be able
	 * to boot and then to reboot in less than a second.  If the
	 * hostid has not been set, then the current high resolution
	 * time is used.  This will ensure different verifiers each
	 * time the server reboots and minimize the chances that two
	 * different servers will have the same verifier.
	 */

#ifndef	lint
	/*
	 * We ASSERT that this constant logic expression is
	 * always true because in the past, it wasn't.
	 */
	ASSERT(sizeof (*verfp) <= sizeof (ns->write3verf));
#endif

	gethrestime(&now);
	verfp = (struct rfs3_verf_overlay *)&ns->write3verf;
	verfp->ts = (int)now.tv_sec;
	verfp->id = zone_get_hostid(NULL);

	if (verfp->id == 0)
		verfp->id = (uint_t)now.tv_nsec;

	ng->nfs3_srv = ns;
}

void
rfs3_srv_zone_fini(nfs_globals_t *ng)
{
	nfs3_srv_t *ns = ng->nfs3_srv;

	ng->nfs3_srv = NULL;

	kmem_free(ns, sizeof (*ns));
}

void
rfs3_srvrinit(void)
{
	nfs3_srv_caller_id = fs_new_caller_id();
}

void
rfs3_srvrfini(void)
{
	/* Nothing to do */
}
