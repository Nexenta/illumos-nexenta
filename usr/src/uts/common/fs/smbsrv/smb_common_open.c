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
 * Copyright (c) 2007, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * This module provides the common open functionality to the various
 * open and create SMB interface functions.
 */

#include <sys/types.h>
#include <sys/cmn_err.h>
#include <sys/fcntl.h>
#include <sys/nbmlock.h>
#include <smbsrv/string.h>
#include <smbsrv/smb_kproto.h>
#include <smbsrv/smb_fsops.h>
#include <smbsrv/smbinfo.h>
#include <smbsrv/smb2_kproto.h>

int smb_disable_streams_on_share_root = 0;
int smb_session_ofile_max = 32768;

static volatile uint32_t smb_fids = 0;
#define	SMB_UNIQ_FID()	atomic_inc_32_nv(&smb_fids)

static uint32_t smb_open_subr(smb_request_t *);
extern uint32_t smb_is_executable(char *);
static void smb_delete_new_object(smb_request_t *);
static int smb_set_open_attributes(smb_request_t *, smb_ofile_t *);
static void smb_open_oplock_break(smb_request_t *, smb_node_t *);
static boolean_t smb_open_attr_only(smb_arg_open_t *);
static boolean_t smb_open_overwrite(smb_arg_open_t *);

/*
 * smb_access_generic_to_file
 *
 * Search MSDN for IoCreateFile to see following mapping.
 *
 * GENERIC_READ		STANDARD_RIGHTS_READ, FILE_READ_DATA,
 *			FILE_READ_ATTRIBUTES and FILE_READ_EA
 *
 * GENERIC_WRITE	STANDARD_RIGHTS_WRITE, FILE_WRITE_DATA,
 *               FILE_WRITE_ATTRIBUTES, FILE_WRITE_EA, and FILE_APPEND_DATA
 *
 * GENERIC_EXECUTE	STANDARD_RIGHTS_EXECUTE, SYNCHRONIZE, and FILE_EXECUTE.
 */
static uint32_t
smb_access_generic_to_file(uint32_t desired_access)
{
	uint32_t access = 0;

	if (desired_access & GENERIC_ALL)
		return (FILE_ALL_ACCESS & ~SYNCHRONIZE);

	if (desired_access & GENERIC_EXECUTE) {
		desired_access &= ~GENERIC_EXECUTE;
		access |= (STANDARD_RIGHTS_EXECUTE |
		    SYNCHRONIZE | FILE_EXECUTE);
	}

	if (desired_access & GENERIC_WRITE) {
		desired_access &= ~GENERIC_WRITE;
		access |= (FILE_GENERIC_WRITE & ~SYNCHRONIZE);
	}

	if (desired_access & GENERIC_READ) {
		desired_access &= ~GENERIC_READ;
		access |= FILE_GENERIC_READ;
	}

	return (access | desired_access);
}

/*
 * smb_omode_to_amask
 *
 * This function converts open modes used by Open and Open AndX
 * commands to desired access bits used by NT Create AndX command.
 */
uint32_t
smb_omode_to_amask(uint32_t desired_access)
{
	switch (desired_access & SMB_DA_ACCESS_MASK) {
	case SMB_DA_ACCESS_READ:
		return (FILE_GENERIC_READ);

	case SMB_DA_ACCESS_WRITE:
		return (FILE_GENERIC_WRITE);

	case SMB_DA_ACCESS_READ_WRITE:
		return (FILE_GENERIC_READ | FILE_GENERIC_WRITE);

	case SMB_DA_ACCESS_EXECUTE:
		return (FILE_GENERIC_READ | FILE_GENERIC_EXECUTE);

	default:
		return (FILE_GENERIC_ALL);
	}
}

/*
 * smb_denymode_to_sharemode
 *
 * This function converts deny modes used by Open and Open AndX
 * commands to share access bits used by NT Create AndX command.
 */
uint32_t
smb_denymode_to_sharemode(uint32_t desired_access, char *fname)
{
	switch (desired_access & SMB_DA_SHARE_MASK) {
	case SMB_DA_SHARE_COMPATIBILITY:
		if (smb_is_executable(fname))
			return (FILE_SHARE_READ | FILE_SHARE_WRITE);

		return (FILE_SHARE_ALL);

	case SMB_DA_SHARE_EXCLUSIVE:
		return (FILE_SHARE_NONE);

	case SMB_DA_SHARE_DENY_WRITE:
		return (FILE_SHARE_READ);

	case SMB_DA_SHARE_DENY_READ:
		return (FILE_SHARE_WRITE);

	case SMB_DA_SHARE_DENY_NONE:
	default:
		return (FILE_SHARE_READ | FILE_SHARE_WRITE);
	}
}

/*
 * smb_ofun_to_crdisposition
 *
 * This function converts open function values used by Open and Open AndX
 * commands to create disposition values used by NT Create AndX command.
 */
uint32_t
smb_ofun_to_crdisposition(uint16_t  ofun)
{
	static int ofun_cr_map[3][2] =
	{
		{ -1,			FILE_CREATE },
		{ FILE_OPEN,		FILE_OPEN_IF },
		{ FILE_OVERWRITE,	FILE_OVERWRITE_IF }
	};

	int row = ofun & SMB_OFUN_OPEN_MASK;
	int col = (ofun & SMB_OFUN_CREATE_MASK) >> 4;

	if (row == 3)
		return (FILE_MAXIMUM_DISPOSITION + 1);

	return (ofun_cr_map[row][col]);
}

/*
 * Requirements for ofile found during reconnect (MS-SMB2 3.3.5.9.7):
 * - security descriptor must match provided descriptor
 *
 * If file is leased:
 * - lease must be requested
 * - client guid must match session guid
 * - file name must match given name
 * - lease key must match provided lease key
 * If file is not leased:
 * - Lease must not be requested
 *
 * dh_v2 only:
 * - SMB2_DHANDLE_FLAG_PERSISTENT must be set if dh_persist is true
 * - SMB2_DHANDLE_FLAG_PERSISTENT must not be set if dh_persist is false
 * - desired access, share access, and create_options must be ignored
 * - createguid must match
 */
static uint32_t
smb_open_reconnect_checks(smb_request_t *sr, smb_ofile_t *of)
{
	smb_arg_open_t	*op = &sr->sr_open;

	if (op->dh_vers == SMB2_DURABLE_V2) {
		if (of->dh_persist && !SMB2_PERSIST(op->dh_v2_flags))
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
		if (memcmp(op->create_guid, of->dh_create_guid, UUID_LEN))
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
		if (!of->dh_persist && SMB2_PERSIST(op->dh_v2_flags))
			return (NT_STATUS_INVALID_PARAMETER);
	}

	if (of->f_tree->t_snode != sr->tid_tree->t_snode) {
#ifdef DEBUG
		cmn_err(CE_WARN, "open_reconnect without matching snodes");
#endif
		return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
	}

	if (!smb_is_same_user(sr->uid_user, of->f_user))
		return (NT_STATUS_ACCESS_DENIED);

	return (NT_STATUS_SUCCESS);
}

/*
 * [MS-SMB2] 3.3.5.9.7 and 3.3.5.9.12 (durable reconnect v1/v2)
 *
 * Looks up an ofile on the server's sv_dh_list by the persistid.
 * If found, it validates the request.
 * (see smb_open_reconnect_checks() for details)
 * If the checks are passed, we remove the ofile from the old list,
 * update the related state to the new context (session, tree, user, etc),
 * and add it onto the new tree's list.
 *
 * Moving an ofile from one context to another is inherently tricky.
 * This codebase previously made the assumption that certain members are
 * immutable, that new objects are only added to the collection when
 * they are newly created, and such objects are always destroyed when
 * a session is torn down.
 *
 * The following previously immutable members are modified by the below code:
 *	f_cr, f_user, f_tree, f_fid, f_session
 * Additionally, the ofile's list membership in t_ofile_list is changed.
 *
 * Clearly, changing these members out from under functions can cause serious
 * problems. This function attempts to avoid this in the following ways:
 *
 * 1) Proceed with the reconnect only after all requests have gone away.
 *    If there are no active requests, and no new requests can occur
 *    (due to the session having gone away), then that drastically reduces
 *    the number of code paths that can possibly interfere.
 *
 * 2) Take the node's ol_mutex in order to shut down the oplock path.
 *    There are two paths to the ofile if you're not part of the durable handle
 *    code: the tree list and the node/oplock lists. The node list is used to
 *    notify directories of changes (directories can't be durable), in the
 *    byte-range lock code (no changing ofile members are checked), when
 *    detecting sharing violations (see below), and when handling oplocks
 *    (via the oplock_grant member). By taking ol_mutex and ensuring ofile
 *    member access only happens with this mutex held, we can keep out the
 *    oplock code while switching contexts - and the context switch does not
 *    modify the node.
 *
 * 3) Restrict access to ofiles in state ORPHANED or RECONNECT to those who are
 *    only interested in immutable members (i.e. code checking for sharing
 *    violations). We need only keep out people who need information about or
 *    from the members we're modifying. Other access are fine, and in fact
 *    should treat the ofile as STATE_OPEN.
 */
uint32_t
smb2_open_reconnect(smb_request_t *sr)
{
	smb_arg_open_t	*op = &sr->sr_open;
	smb_ofile_t *of;
	smb_tree_t *tree;
	smb_node_t *node;
	smb_llist_t *dhlist;
	cred_t *cr;
	uint32_t rv;
	uint16_t fid;

	of = smb_ofile_lookup_by_persistid(sr, op->dh_fileid.persistent);
	if (of == NULL)
		return (NT_STATUS_OBJECT_NAME_NOT_FOUND);

	mutex_enter(&of->f_mutex);
	if ((rv = smb_open_reconnect_checks(sr, of)) != NT_STATUS_SUCCESS)
		goto out1;

	/*
	 * Only the last person attempting reclaim should be allowed to reclaim
	 * the ofile. The only *real* cause for multiple reclaimers would be
	 * when an active reclaimer is logged off or disconnected, and we get a
	 * new reconnect request before this one finishes. Clearly, in this
	 * case, the last reclaimer should get the ofile.
	 */
	of->dh_reclaimer = sr;
	cv_signal(&of->f_cv);

	/*
	 * Wait until all other references to this object have gone away
	 * so that it's safe to proceed. If another reconnect comes in
	 * for the same file, or if the state of the ofile changes, there's
	 * no point in continuing.
	 */
	while (of->f_state == SMB_OFILE_STATE_ORPHANED &&
	    of->f_refcnt > 1 && of->dh_reclaimer == sr)
		cv_wait(&of->f_cv, &of->f_mutex);

	if (of->f_state != SMB_OFILE_STATE_ORPHANED ||
	    of->dh_reclaimer != sr) {
		rv = NT_STATUS_OBJECT_NAME_NOT_FOUND;
		goto out1;
	}

	/*
	 * We need to ensure that this reclaim completes prior to any
	 * *final* attempt (user_logoff/tree_disconnect) to close all
	 * ofiles on the tree, otherwise this ofile will remain open.
	 */
	tree = sr->tid_tree;
	/* inline smb_tree_hold() */
	mutex_enter(&tree->t_mutex);
	if (!smb_tree_is_connected_locked(tree)) {
		rv = NT_STATUS_OBJECT_NAME_NOT_FOUND;
		goto out2;
	}

	if (smb_idpool_alloc(&tree->t_fid_pool, &fid)) {
		rv = NT_STATUS_TOO_MANY_OPENED_FILES;
		goto out2;
	}

	tree->t_refcnt++;
	smb_llist_enter(&tree->t_ofile_list, RW_WRITER);
	mutex_exit(&tree->t_mutex);

	node = of->f_node;
	dhlist = &of->f_tree->t_ofile_list;

	of->f_state = SMB_OFILE_STATE_RECONNECT;
	mutex_exit(&of->f_mutex);

	/*
	 * We must take the ofile list lock before the mutex. Additionally,
	 * because parts of the oplock code take the ofile mutex after
	 * the oplock mutex, we must respect that order as well.
	 *
	 * At this point, we should be the only ones with a refcnt on the
	 * ofile, and the RECONNECT state should prevent new refcnts from
	 * being granted, or other durable threads from observing or
	 * reclaiming it, so it should be safe to drop the lock long enough
	 * to grab the others in the correct order.
	 */

	mutex_enter(&node->n_oplock.ol_mutex);
	smb_llist_enter(dhlist, RW_WRITER);
	ASSERT(of->f_state == SMB_OFILE_STATE_RECONNECT);

	/*
	 * While we're in STATE_RECONNECT, no one should be reading any of the
	 * values we're changing here. If it's safe to drop the mutex above,
	 * it should be safe to work without it until we need to modify state.
	 */
	smb_llist_remove(dhlist, of);
	smb_idpool_free(&of->f_tree->t_fid_pool, of->f_fid);
	atomic_dec_32(&of->f_tree->t_open_files);
	atomic_dec_32(&of->f_session->s_file_cnt);
	atomic_dec_32(&of->f_session->s_dh_cnt);
	smb_llist_exit(dhlist);
	smb_tree_release(of->f_tree); /* for ofile */

	smb_ptrhash_remove(of->f_server->sv_persistid_ht, of);

	/* From here, the ofile is only visible via the node lists */

	cr = of->f_cr;
	of->f_cr = (of->f_cr == of->f_user->u_cred) ?
	    sr->uid_user->u_cred : smb_user_getprivcred(sr->uid_user);
	crhold(of->f_cr);
	crfree(cr);

	smb_user_hold_internal(sr->uid_user);
	smb_user_release(of->f_user);

	of->f_user = sr->uid_user;
	of->f_tree = sr->tid_tree;
	of->f_fid = sr->smb_fid = fid;
	of->f_session = sr->session;

	op->op_oplock_level = of->f_oplock_grant.og_level;

	mutex_enter(&of->f_mutex);
	of->dh_expire_time = 0;
	of->f_state = SMB_OFILE_STATE_OPEN;

	/*
	 * No one with access to this list can possibly wait on
	 * the mutex on this ofile, so it should be safe
	 * to take the list lock
	 * Note: list lock is taken higher up
	 */
	smb_llist_insert_tail(&tree->t_ofile_list, of);
	atomic_inc_32(&tree->t_open_files);
	atomic_inc_32(&of->f_session->s_file_cnt);
	smb_llist_exit(&tree->t_ofile_list);

	mutex_exit(&of->f_mutex);
	mutex_exit(&node->n_oplock.ol_mutex);

	/* The ofile is now visible to the new session */

	op->fqi.fq_fattr.sa_mask = SMB_AT_ALL;
	(void) smb_node_getattr(sr, node, zone_kcred(), of,
	    &op->fqi.fq_fattr);

	sr->fid_ofile = of;
	op->create_options = 0; /* no more modifications wanted */
	op->action_taken = SMB_OACT_OPENED;
	return (NT_STATUS_SUCCESS);

out2:
	mutex_exit(&tree->t_mutex);
out1:
	mutex_exit(&of->f_mutex);
	smb_ofile_release(of);
	return (rv);
}

/*
 * Retry opens to avoid spurious sharing violations, due to timing
 * issues between closes and opens.  The client that already has the
 * file open may be in the process of closing it.
 */
uint32_t
smb_common_open(smb_request_t *sr)
{
	smb_arg_open_t	*parg;
	uint32_t	status = NT_STATUS_SUCCESS;
	int		count;

	parg = kmem_alloc(sizeof (*parg), KM_SLEEP);
	bcopy(&sr->arg.open, parg, sizeof (*parg));

	for (count = 0; count <= 4; count++) {
		if (count != 0)
			delay(MSEC_TO_TICK(400));

		status = smb_open_subr(sr);
		if (status != NT_STATUS_SHARING_VIOLATION)
			break;

		bcopy(parg, &sr->arg.open, sizeof (*parg));
	}

	if (status == NT_STATUS_NO_SUCH_FILE)
		status = NT_STATUS_OBJECT_NAME_NOT_FOUND;

	kmem_free(parg, sizeof (*parg));
	return (status);
}

/*
 * smb_open_subr
 *
 * Notes on write-through behaviour. It looks like pre-LM0.12 versions
 * of the protocol specify the write-through mode when a file is opened,
 * (SmbOpen, SmbOpenAndX) so the write calls (SmbWrite, SmbWriteAndClose,
 * SmbWriteAndUnlock) don't need to contain a write-through flag.
 *
 * With LM0.12, the open calls (SmbCreateAndX, SmbNtTransactCreate)
 * don't indicate which write-through mode to use. Instead the write
 * calls (SmbWriteAndX, SmbWriteRaw) specify the mode on a per call
 * basis.
 *
 * We don't care which open call was used to get us here, we just need
 * to ensure that the write-through mode flag is copied from the open
 * parameters to the node. We test the omode write-through flag in all
 * write functions.
 *
 * This function returns NT status codes.
 *
 * The following rules apply when processing a file open request:
 *
 * - Oplocks must be broken prior to share checking as the break may
 *   cause other clients to close the file, which would affect sharing
 *   checks.
 *
 * - Share checks must take place prior to access checks for correct
 * Windows semantics and to prevent unnecessary NFS delegation recalls.
 *
 * - Oplocks must be acquired after open to ensure the correct
 * synchronization with NFS delegation and FEM installation.
 *
 * DOS readonly bit rules
 *
 * 1. The creator of a readonly file can write to/modify the size of the file
 * using the original create fid, even though the file will appear as readonly
 * to all other fids and via a CIFS getattr call.
 * The readonly bit therefore cannot be set in the filesystem until the file
 * is closed (smb_ofile_close). It is accounted for via ofile and node flags.
 *
 * 2. A setinfo operation (using either an open fid or a path) to set/unset
 * readonly will be successful regardless of whether a creator of a readonly
 * file has an open fid (and has the special privilege mentioned in #1,
 * above).  I.e., the creator of a readonly fid holding that fid will no longer
 * have a special privilege.
 *
 * 3. The DOS readonly bit affects only data and some metadata.
 * The following metadata can be changed regardless of the readonly bit:
 * 	- security descriptors
 *	- DOS attributes
 *	- timestamps
 *
 * In the current implementation, the file size cannot be changed (except for
 * the exceptions in #1 and #2, above).
 *
 *
 * DOS attribute rules
 *
 * These rules are specific to creating / opening files and directories.
 * How the attribute value (specifically ZERO or FILE_ATTRIBUTE_NORMAL)
 * should be interpreted may differ in other requests.
 *
 * - An attribute value equal to ZERO or FILE_ATTRIBUTE_NORMAL means that the
 *   file's attributes should be cleared.
 * - If FILE_ATTRIBUTE_NORMAL is specified with any other attributes,
 *   FILE_ATTRIBUTE_NORMAL is ignored.
 *
 * 1. Creating a new file
 * - The request attributes + FILE_ATTRIBUTE_ARCHIVE are applied to the file.
 *
 * 2. Creating a new directory
 * - The request attributes + FILE_ATTRIBUTE_DIRECTORY are applied to the file.
 * - FILE_ATTRIBUTE_ARCHIVE does not get set.
 *
 * 3. Overwriting an existing file
 * - the request attributes are used as search attributes. If the existing
 *   file does not meet the search criteria access is denied.
 * - otherwise, applies attributes + FILE_ATTRIBUTE_ARCHIVE.
 *
 * 4. Opening an existing file or directory
 *    The request attributes are ignored.
 */
static uint32_t
smb_open_subr(smb_request_t *sr)
{
	boolean_t	created = B_FALSE;
	boolean_t	last_comp_found = B_FALSE;
	smb_node_t	*node = NULL;
	smb_node_t	*dnode = NULL;
	smb_node_t	*cur_node = NULL;
	smb_arg_open_t	*op = &sr->sr_open;
	int		rc;
	smb_ofile_t	*of;
	smb_attr_t	new_attr;
	int		max_requested = 0;
	uint32_t	max_allowed;
	uint32_t	status = NT_STATUS_SUCCESS;
	int		is_dir;
	smb_error_t	err;
	boolean_t	is_stream = B_FALSE;
	int		lookup_flags = SMB_FOLLOW_LINKS;
	uint32_t	uniq_fid;
	smb_pathname_t	*pn = &op->fqi.fq_path;
	smb_server_t	*sv = sr->sr_server;

	/* Get out now if we've been cancelled. */
	mutex_enter(&sr->sr_mutex);
	if (sr->sr_state != SMB_REQ_STATE_ACTIVE) {
		mutex_exit(&sr->sr_mutex);
		return (NT_STATUS_CANCELLED);
	}
	mutex_exit(&sr->sr_mutex);

	is_dir = (op->create_options & FILE_DIRECTORY_FILE) ? 1 : 0;

	/*
	 * If the object being created or opened is a directory
	 * the Disposition parameter must be one of FILE_CREATE,
	 * FILE_OPEN, or FILE_OPEN_IF
	 */
	if (is_dir) {
		if ((op->create_disposition != FILE_CREATE) &&
		    (op->create_disposition != FILE_OPEN_IF) &&
		    (op->create_disposition != FILE_OPEN)) {
			return (NT_STATUS_INVALID_PARAMETER);
		}
	}

	if (op->desired_access & MAXIMUM_ALLOWED) {
		max_requested = 1;
		op->desired_access &= ~MAXIMUM_ALLOWED;
	}
	op->desired_access = smb_access_generic_to_file(op->desired_access);

	if (sr->session->s_file_cnt >= smb_session_ofile_max) {
		ASSERT(sr->uid_user);
		cmn_err(CE_NOTE, "smbsrv[%s\\%s]: TOO_MANY_OPENED_FILES",
		    sr->uid_user->u_domain, sr->uid_user->u_name);
		return (NT_STATUS_TOO_MANY_OPENED_FILES);
	}

	/* This must be NULL at this point */
	sr->fid_ofile = NULL;

	op->devstate = 0;

	switch (sr->tid_tree->t_res_type & STYPE_MASK) {
	case STYPE_DISKTREE:
	case STYPE_PRINTQ:
		break;

	case STYPE_IPC:
		/*
		 * Security descriptors for pipes are not implemented,
		 * so just setup a reasonable access mask.
		 */
		op->desired_access = (READ_CONTROL | SYNCHRONIZE |
		    FILE_READ_DATA | FILE_READ_ATTRIBUTES |
		    FILE_WRITE_DATA | FILE_APPEND_DATA);

		/*
		 * Limit the number of open pipe instances.
		 */
		if ((rc = smb_threshold_enter(&sv->sv_opipe_ct)) != 0) {
			status = RPC_NT_SERVER_TOO_BUSY;
			return (status);
		}

		/*
		 * No further processing for IPC, we need to either
		 * raise an exception or return success here.
		 */
		uniq_fid = SMB_UNIQ_FID();
		status = smb_opipe_open(sr, uniq_fid);
		smb_threshold_exit(&sv->sv_opipe_ct);
		return (status);

	default:
		return (NT_STATUS_BAD_DEVICE_TYPE);
	}

	smb_pathname_init(sr, pn, pn->pn_path);
	if (!smb_pathname_validate(sr, pn))
		return (sr->smb_error.status);

	if (strlen(pn->pn_path) >= SMB_MAXPATHLEN) {
		return (NT_STATUS_OBJECT_PATH_INVALID);
	}

	if (is_dir) {
		if (!smb_validate_dirname(sr, pn))
			return (sr->smb_error.status);
	} else {
		if (!smb_validate_object_name(sr, pn))
			return (sr->smb_error.status);
	}

	cur_node = op->fqi.fq_dnode ?
	    op->fqi.fq_dnode : sr->tid_tree->t_snode;

	/*
	 * if no path or filename are specified the stream should be
	 * created on cur_node
	 */
	if (!is_dir && !pn->pn_pname && !pn->pn_fname && pn->pn_sname) {
		/*
		 * There were historically some problems with allowing
		 * NT named streams at the root of a share, but all the
		 * details about such problem are long gone.  Windows
		 * allows these; the Mac expects them to work.  Let's
		 * allow this but provide a way to disable it in case
		 * someone rediscovers the historical problem.
		 */
		if (smb_disable_streams_on_share_root != 0 &&
		    cur_node == sr->tid_tree->t_snode) {
			if (op->create_disposition == FILE_OPEN) {
				return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
			}
			return (NT_STATUS_ACCESS_DENIED);
		}

		(void) snprintf(op->fqi.fq_last_comp,
		    sizeof (op->fqi.fq_last_comp),
		    "%s%s", cur_node->od_name, pn->pn_sname);

		op->fqi.fq_dnode = cur_node->n_dnode;
		smb_node_ref(op->fqi.fq_dnode);
	} else {
		rc = smb_pathname_reduce(sr, sr->user_cr, pn->pn_path,
		    sr->tid_tree->t_snode, cur_node, &op->fqi.fq_dnode,
		    op->fqi.fq_last_comp);
		if (rc != 0) {
			return (smb_errno2status(rc));
		}
	}

	/*
	 * If the access mask has only DELETE set (ignore
	 * FILE_READ_ATTRIBUTES), then assume that this
	 * is a request to delete the link (if a link)
	 * and do not follow links.  Otherwise, follow
	 * the link to the target.
	 */
	if ((op->desired_access & ~FILE_READ_ATTRIBUTES) == DELETE)
		lookup_flags &= ~SMB_FOLLOW_LINKS;

	rc = smb_fsop_lookup_name(sr, zone_kcred(), lookup_flags,
	    sr->tid_tree->t_snode, op->fqi.fq_dnode, op->fqi.fq_last_comp,
	    &op->fqi.fq_fnode);

	if (rc == 0) {
		last_comp_found = B_TRUE;
		/*
		 * Need the DOS attributes below, where we
		 * check the search attributes (sattr).
		 */
		op->fqi.fq_fattr.sa_mask = SMB_AT_DOSATTR;
		rc = smb_node_getattr(sr, op->fqi.fq_fnode, zone_kcred(),
		    NULL, &op->fqi.fq_fattr);
		if (rc != 0) {
			smb_node_release(op->fqi.fq_fnode);
			smb_node_release(op->fqi.fq_dnode);
			return (NT_STATUS_INTERNAL_ERROR);
		}
	} else if (rc == ENOENT) {
		last_comp_found = B_FALSE;
		op->fqi.fq_fnode = NULL;
		rc = 0;
	} else {
		smb_node_release(op->fqi.fq_dnode);
		return (smb_errno2status(rc));
	}


	/*
	 * The uniq_fid is a CIFS-server-wide unique identifier for an ofile
	 * which is used to uniquely identify open instances for the
	 * VFS share reservation and POSIX locks.
	 */

	uniq_fid = SMB_UNIQ_FID();

	if (last_comp_found) {

		node = op->fqi.fq_fnode;
		dnode = op->fqi.fq_dnode;

		if (!smb_node_is_file(node) && !smb_node_is_dir(node) &&
		    !smb_node_is_symlink(node)) {
			smb_node_release(node);
			smb_node_release(dnode);
			return (NT_STATUS_ACCESS_DENIED);
		}

		/*
		 * Reject this request if either:
		 * - the target IS a directory and the client requires that
		 *   it must NOT be (required by Lotus Notes)
		 * - the target is NOT a directory and client requires that
		 *   it MUST be.
		 */
		if (smb_node_is_dir(node)) {
			if (op->create_options & FILE_NON_DIRECTORY_FILE) {
				smb_node_release(node);
				smb_node_release(dnode);
				return (NT_STATUS_FILE_IS_A_DIRECTORY);
			}
		} else {
			if ((op->create_options & FILE_DIRECTORY_FILE) ||
			    (op->nt_flags & NT_CREATE_FLAG_OPEN_TARGET_DIR)) {
				smb_node_release(node);
				smb_node_release(dnode);
				return (NT_STATUS_NOT_A_DIRECTORY);
			}
		}

		/*
		 * No more open should be accepted when "Delete on close"
		 * flag is set.
		 */
		if (node->flags & NODE_FLAGS_DELETE_ON_CLOSE) {
			smb_node_release(node);
			smb_node_release(dnode);
			return (NT_STATUS_DELETE_PENDING);
		}

		/*
		 * Specified file already exists so the operation should fail.
		 */
		if (op->create_disposition == FILE_CREATE) {
			smb_node_release(node);
			smb_node_release(dnode);
			return (NT_STATUS_OBJECT_NAME_COLLISION);
		}

		/*
		 * Windows seems to check read-only access before file
		 * sharing check.
		 *
		 * Check to see if the file is currently readonly (irrespective
		 * of whether this open will make it readonly).
		 */
		if (SMB_PATHFILE_IS_READONLY(sr, node)) {
			/* Files data only */
			if (!smb_node_is_dir(node)) {
				if (op->desired_access & (FILE_WRITE_DATA |
				    FILE_APPEND_DATA)) {
					smb_node_release(node);
					smb_node_release(dnode);
					return (NT_STATUS_ACCESS_DENIED);
				}
				if (op->create_options & FILE_DELETE_ON_CLOSE) {
					return (NT_STATUS_CANNOT_DELETE);
				}
			}
		}

		if ((op->create_disposition == FILE_SUPERSEDE) ||
		    (op->create_disposition == FILE_OVERWRITE_IF) ||
		    (op->create_disposition == FILE_OVERWRITE)) {

			if (!smb_sattr_check(op->fqi.fq_fattr.sa_dosattr,
			    op->dattr)) {
				smb_node_release(node);
				smb_node_release(dnode);
				return (NT_STATUS_ACCESS_DENIED);
			}

			if (smb_node_is_dir(node)) {
				smb_node_release(node);
				smb_node_release(dnode);
				return (NT_STATUS_ACCESS_DENIED);
			}
		}

		/* MS-FSA 2.1.5.1.2 */
		if (op->create_disposition == FILE_SUPERSEDE)
			op->desired_access |= DELETE;
		if ((op->create_disposition == FILE_OVERWRITE_IF) ||
		    (op->create_disposition == FILE_OVERWRITE))
			op->desired_access |= FILE_WRITE_DATA;

		status = smb_fsop_access(sr, sr->user_cr, node,
		    op->desired_access);
		if (status != NT_STATUS_SUCCESS) {
			smb_node_release(node);
			smb_node_release(dnode);

			/* SMB1 specific? NT_STATUS_PRIVILEGE_NOT_HELD */
			if (status == NT_STATUS_PRIVILEGE_NOT_HELD) {
				return (status);
			} else {
				return (NT_STATUS_ACCESS_DENIED);
			}
		}

		if (max_requested) {
			smb_fsop_eaccess(sr, sr->user_cr, node, &max_allowed);
			op->desired_access |= max_allowed;
		}
		/*
		 * According to MS "dochelp" mail in Mar 2015, any handle
		 * on which read or write access is granted implicitly
		 * gets "read attributes", even if it was not requested.
		 * This avoids unexpected access failures later that
		 * would happen if these were not granted.
		 */
		if ((op->desired_access & FILE_DATA_ALL) != 0) {
			op->desired_access |= (READ_CONTROL |
			    FILE_READ_ATTRIBUTES);
		}

		/*
		 * Oplock break is done prior to sharing checks as the break
		 * may cause other clients to close the file which would
		 * affect the sharing checks, and may delete the file due to
		 * DELETE_ON_CLOSE. This may block, so set the file opening
		 * count before oplock stuff.
		 */
		smb_node_inc_opening_count(node);
		smb_open_oplock_break(sr, node);

		if ((node->flags & NODE_FLAGS_DELETE_COMMITTED) != 0) {
			/*
			 * Breaking the oplock caused the file to be deleted,
			 * so let's bail and pretend the file wasn't found
			 */
			smb_node_dec_opening_count(node);
			smb_node_release(node);
			last_comp_found = B_FALSE;
			goto create;
		}

		smb_node_wrlock(node);

		/*
		 * Check for sharing violations
		 */
		status = smb_fsop_shrlock(sr->user_cr, node, uniq_fid,
		    op->desired_access, op->share_access);
		if (status == NT_STATUS_SHARING_VIOLATION) {
			smb_node_unlock(node);
			smb_node_dec_opening_count(node);
			smb_node_release(node);
			smb_node_release(dnode);
			return (status);
		}

		/*
		 * Go ahead with modifications as necessary.
		 */
		switch (op->create_disposition) {
		case FILE_SUPERSEDE:
		case FILE_OVERWRITE_IF:
		case FILE_OVERWRITE:
			op->dattr |= FILE_ATTRIBUTE_ARCHIVE;
			/* Don't apply readonly bit until smb_ofile_close */
			if (op->dattr & FILE_ATTRIBUTE_READONLY) {
				op->created_readonly = B_TRUE;
				op->dattr &= ~FILE_ATTRIBUTE_READONLY;
			}

			/*
			 * Truncate the file data here.
			 * We set alloc_size = op->dsize later,
			 * after we have an ofile.  See:
			 * smb_set_open_attributes
			 */
			bzero(&new_attr, sizeof (new_attr));
			new_attr.sa_dosattr = op->dattr;
			new_attr.sa_vattr.va_size = 0;
			new_attr.sa_mask = SMB_AT_DOSATTR | SMB_AT_SIZE;
			rc = smb_fsop_setattr(sr, sr->user_cr, node, &new_attr);
			if (rc != 0) {
				smb_fsop_unshrlock(sr->user_cr, node, uniq_fid);
				smb_node_unlock(node);
				smb_node_dec_opening_count(node);
				smb_node_release(node);
				smb_node_release(dnode);
				return (smb_errno2status(rc));
			}

			/*
			 * If file is being replaced, remove existing streams
			 */
			if (SMB_IS_STREAM(node) == 0) {
				status = smb_fsop_remove_streams(sr,
				    sr->user_cr, node);
				if (status != 0) {
					smb_fsop_unshrlock(sr->user_cr, node,
					    uniq_fid);
					smb_node_unlock(node);
					smb_node_dec_opening_count(node);
					smb_node_release(node);
					smb_node_release(dnode);
					return (status);
				}
			}

			op->action_taken = SMB_OACT_TRUNCATED;
			break;

		default:
			/*
			 * FILE_OPEN or FILE_OPEN_IF.
			 */
			/*
			 * Ignore any user-specified alloc_size for
			 * existing files, to avoid truncation in
			 * smb_set_open_attributes
			 */
			op->dsize = 0L;
			op->action_taken = SMB_OACT_OPENED;
			break;
		}
	} else {
create:
		/* Last component was not found. */
		dnode = op->fqi.fq_dnode;

		if (is_dir == 0)
			is_stream = smb_is_stream_name(pn->pn_path);

		if ((op->create_disposition == FILE_OPEN) ||
		    (op->create_disposition == FILE_OVERWRITE)) {
			smb_node_release(dnode);
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
		}

		if (pn->pn_fname && smb_is_invalid_filename(pn->pn_fname)) {
			smb_node_release(dnode);
			return (NT_STATUS_OBJECT_NAME_INVALID);
		}

		/*
		 * lock the parent dir node in case another create
		 * request to the same parent directory comes in.
		 */
		smb_node_wrlock(dnode);

		/* Don't apply readonly bit until smb_ofile_close */
		if (op->dattr & FILE_ATTRIBUTE_READONLY) {
			op->dattr &= ~FILE_ATTRIBUTE_READONLY;
			op->created_readonly = B_TRUE;
		}

		bzero(&new_attr, sizeof (new_attr));
		if ((op->crtime.tv_sec != 0) &&
		    (op->crtime.tv_sec != UINT_MAX)) {

			new_attr.sa_mask |= SMB_AT_CRTIME;
			new_attr.sa_crtime = op->crtime;
		}

		if (is_dir == 0) {
			op->dattr |= FILE_ATTRIBUTE_ARCHIVE;
			new_attr.sa_dosattr = op->dattr;
			new_attr.sa_vattr.va_type = VREG;
			if (is_stream)
				new_attr.sa_vattr.va_mode = S_IRUSR | S_IWUSR;
			else
				new_attr.sa_vattr.va_mode =
				    S_IRUSR | S_IRGRP | S_IROTH |
				    S_IWUSR | S_IWGRP | S_IWOTH;
			new_attr.sa_mask |=
			    SMB_AT_DOSATTR | SMB_AT_TYPE | SMB_AT_MODE;

			/*
			 * We set alloc_size = op->dsize later,
			 * (in smb_set_open_attributes) after we
			 * have an ofile on which to save that.
			 *
			 * Legacy Open&X sets size to alloc_size
			 * when creating a new file.
			 */
			if (sr->smb_com == SMB_COM_OPEN_ANDX) {
				new_attr.sa_vattr.va_size = op->dsize;
				new_attr.sa_mask |= SMB_AT_SIZE;
			}

			rc = smb_fsop_create(sr, sr->user_cr, dnode,
			    op->fqi.fq_last_comp, &new_attr, &op->fqi.fq_fnode);

			if (rc != 0) {
				smb_node_unlock(dnode);
				smb_node_release(dnode);
				return (smb_errno2status(rc));
			}

			node = op->fqi.fq_fnode;
			smb_node_inc_opening_count(node);
			smb_node_wrlock(node);

			status = smb_fsop_shrlock(sr->user_cr, node, uniq_fid,
			    op->desired_access, op->share_access);

			if (status == NT_STATUS_SHARING_VIOLATION) {
				smb_node_unlock(node);
				smb_node_dec_opening_count(node);
				smb_delete_new_object(sr);
				smb_node_release(node);
				smb_node_unlock(dnode);
				smb_node_release(dnode);
				return (status);
			}
		} else {
			op->dattr |= FILE_ATTRIBUTE_DIRECTORY;
			new_attr.sa_dosattr = op->dattr;
			new_attr.sa_vattr.va_type = VDIR;
			new_attr.sa_vattr.va_mode = 0777;
			new_attr.sa_mask |=
			    SMB_AT_DOSATTR | SMB_AT_TYPE | SMB_AT_MODE;

			rc = smb_fsop_mkdir(sr, sr->user_cr, dnode,
			    op->fqi.fq_last_comp, &new_attr, &op->fqi.fq_fnode);
			if (rc != 0) {
				smb_node_unlock(dnode);
				smb_node_release(dnode);
				return (smb_errno2status(rc));
			}

			node = op->fqi.fq_fnode;
			smb_node_inc_opening_count(node);
			smb_node_wrlock(node);
		}

		created = B_TRUE;
		op->action_taken = SMB_OACT_CREATED;

		if (max_requested) {
			smb_fsop_eaccess(sr, sr->user_cr, node, &max_allowed);
			op->desired_access |= max_allowed;
		}
		/*
		 * We created this object (we own it) so grant
		 * read_control + read_attributes on this handle,
		 * even if that was not requested.  This avoids
		 * unexpected access failures later.
		 */
		op->desired_access |= (READ_CONTROL | FILE_READ_ATTRIBUTES);
	}

	status = NT_STATUS_SUCCESS;

	of = smb_ofile_open(sr, node, op, SMB_FTYPE_DISK, uniq_fid,
	    &err);
	if (of == NULL) {
		status = err.status;
	}

	/*
	 * We might have blocked in smb_ofile_open long enough so a
	 * tree disconnect might have happened.  In that case, we've
	 * just added an ofile to a tree that's disconnecting, and
	 * need to undo that to avoid interfering with tear-down of
	 * the tree connection.
	 */
	if (status == NT_STATUS_SUCCESS &&
	    !smb_tree_is_connected(sr->tid_tree)) {
		status = NT_STATUS_INVALID_PARAMETER;
	}

	/*
	 * This MUST be done after ofile creation, so that explicitly
	 * set timestamps can be remembered on the ofile, and the
	 * readonly flag will be stored "pending" on the node.
	 */
	if (status == NT_STATUS_SUCCESS) {
		if ((rc = smb_set_open_attributes(sr, of)) != 0) {
			status = smb_errno2status(rc);
		}
	}

	if (status == NT_STATUS_SUCCESS) {
		/*
		 * We've already done access checks above,
		 * and want this call to succeed even when
		 * !(desired_access & FILE_READ_ATTRIBUTES),
		 * so pass kcred here.
		 */
		op->fqi.fq_fattr.sa_mask = SMB_AT_ALL;
		rc = smb_node_getattr(sr, node, zone_kcred(), of,
		    &op->fqi.fq_fattr);
		if (rc != 0) {
			status = NT_STATUS_INTERNAL_ERROR;
		}
	}

	/*
	 * smb_fsop_unshrlock is a no-op if node is a directory
	 * smb_fsop_unshrlock is done in smb_ofile_close
	 */
	if (status != NT_STATUS_SUCCESS) {
		if (of == NULL) {
			smb_fsop_unshrlock(sr->user_cr, node, uniq_fid);
		} else {
			smb_ofile_close(of, 0);
			smb_ofile_release(of);
		}
		if (created)
			smb_delete_new_object(sr);
		smb_node_unlock(node);
		smb_node_dec_opening_count(node);
		smb_node_release(node);
		if (created)
			smb_node_unlock(dnode);
		smb_node_release(dnode);
		return (status);
	}

	/*
	 * Propagate the write-through mode from the open params
	 * to the node: see the notes in the function header.
	 */
	if (sr->sr_cfg->skc_sync_enable ||
	    (op->create_options & FILE_WRITE_THROUGH))
		node->flags |= NODE_FLAGS_WRITE_THROUGH;

	/*
	 * Set up the fileid and dosattr in open_param for response
	 */
	op->fileid = op->fqi.fq_fattr.sa_vattr.va_nodeid;
	op->dattr = op->fqi.fq_fattr.sa_dosattr;

	/*
	 * Set up the file type in open_param for the response
	 */
	op->ftype = SMB_FTYPE_DISK;
	sr->smb_fid = of->f_fid;
	sr->fid_ofile = of;

	if (smb_node_is_file(node)) {
		smb_oplock_acquire(sr, node, of);
		op->dsize = op->fqi.fq_fattr.sa_vattr.va_size;
	} else {
		/* directory or symlink */
		op->op_oplock_level = SMB_OPLOCK_NONE;
		op->dsize = 0;
	}

	smb_node_dec_opening_count(node);

	smb_node_unlock(node);
	if (created)
		smb_node_unlock(dnode);

	smb_node_release(node);
	smb_node_release(dnode);

	return (NT_STATUS_SUCCESS);
}

/*
 * smb_open_oplock_break
 *
 * If the node has an ofile opened with share access none,
 * (smb_node_share_check = FALSE) only break BATCH oplock.
 * Otherwise:
 * If overwriting, break to SMB_OPLOCK_NONE, else
 * If opening for anything other than attribute access,
 * break oplock to LEVEL_II.
 */
static void
smb_open_oplock_break(smb_request_t *sr, smb_node_t *node)
{
	smb_arg_open_t	*op = &sr->sr_open;
	uint32_t	flags = 0;

	if (!smb_node_share_check(node))
		flags |= SMB_OPLOCK_BREAK_BATCH;

	if (smb_open_overwrite(op)) {
		flags |= SMB_OPLOCK_BREAK_TO_NONE;
		(void) smb_oplock_break(sr, node, flags);
	} else if (!smb_open_attr_only(op)) {
		flags |= SMB_OPLOCK_BREAK_TO_LEVEL_II;
		(void) smb_oplock_break(sr, node, flags);
	}
}

/*
 * smb_open_attr_only
 *
 * Determine if file is being opened for attribute access only.
 * This is used to determine whether it is necessary to break
 * existing oplocks on the file.
 */
static boolean_t
smb_open_attr_only(smb_arg_open_t *op)
{
	if (((op->desired_access & ~(FILE_READ_ATTRIBUTES |
	    FILE_WRITE_ATTRIBUTES | SYNCHRONIZE | READ_CONTROL)) == 0) &&
	    (op->create_disposition != FILE_SUPERSEDE) &&
	    (op->create_disposition != FILE_OVERWRITE)) {
		return (B_TRUE);
	}
	return (B_FALSE);
}

static boolean_t
smb_open_overwrite(smb_arg_open_t *op)
{
	if ((op->create_disposition == FILE_SUPERSEDE) ||
	    (op->create_disposition == FILE_OVERWRITE_IF) ||
	    (op->create_disposition == FILE_OVERWRITE)) {
		return (B_TRUE);
	}
	return (B_FALSE);
}

/*
 * smb_set_open_attributes
 *
 * Last write time:
 * - If the last_write time specified in the open params is not 0 or -1,
 *   use it as file's mtime. This will be considered an explicitly set
 *   timestamps, not reset by subsequent writes.
 *
 * DOS attributes
 * - If we created_readonly, we now store the real DOS attributes
 *   (including the readonly bit) so subsequent opens will see it.
 *
 * Both are stored "pending" rather than in the file system.
 *
 * Returns: errno
 */
static int
smb_set_open_attributes(smb_request_t *sr, smb_ofile_t *of)
{
	smb_attr_t	attr;
	smb_arg_open_t	*op = &sr->sr_open;
	smb_node_t	*node = of->f_node;
	int		rc = 0;

	bzero(&attr, sizeof (smb_attr_t));

	if (op->created_readonly) {
		attr.sa_dosattr = op->dattr | FILE_ATTRIBUTE_READONLY;
		attr.sa_mask |= SMB_AT_DOSATTR;
	}

	if (op->dsize != 0) {
		attr.sa_allocsz = op->dsize;
		attr.sa_mask |= SMB_AT_ALLOCSZ;
	}

	if ((op->mtime.tv_sec != 0) && (op->mtime.tv_sec != UINT_MAX)) {
		attr.sa_vattr.va_mtime = op->mtime;
		attr.sa_mask |= SMB_AT_MTIME;
	}

	/*
	 * Used to have code here to set mtime, ctime, atime
	 * when the open op->create_disposition is any of:
	 * FILE_SUPERSEDE, FILE_OVERWRITE_IF, FILE_OVERWRITE.
	 * We know that in those cases we will have set the
	 * file size, in which case the file system will
	 * update those times, so we don't have to.
	 *
	 * However, keep track of the fact that we modified
	 * the file via this handle, so we can do the evil,
	 * gratuitious mtime update on close that Windows
	 * clients appear to expect.
	 */
	if (op->action_taken == SMB_OACT_TRUNCATED)
		of->f_written = B_TRUE;

	if (attr.sa_mask != 0)
		rc = smb_node_setattr(sr, node, of->f_cr, of, &attr);

	return (rc);
}

/*
 * This function is used to delete a newly created object (file or
 * directory) if an error occurs after creation of the object.
 */
static void
smb_delete_new_object(smb_request_t *sr)
{
	smb_arg_open_t	*op = &sr->sr_open;
	smb_fqi_t	*fqi = &(op->fqi);
	uint32_t	flags = 0;

	if (SMB_TREE_IS_CASEINSENSITIVE(sr))
		flags |= SMB_IGNORE_CASE;
	if (SMB_TREE_SUPPORTS_CATIA(sr))
		flags |= SMB_CATIA;

	if (op->create_options & FILE_DIRECTORY_FILE)
		(void) smb_fsop_rmdir(sr, sr->user_cr, fqi->fq_dnode,
		    fqi->fq_last_comp, flags);
	else
		(void) smb_fsop_remove(sr, sr->user_cr, fqi->fq_dnode,
		    fqi->fq_last_comp, flags);
}
