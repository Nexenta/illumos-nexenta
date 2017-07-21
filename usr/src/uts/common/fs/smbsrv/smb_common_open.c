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

extern uint32_t smb_is_executable(char *);
static void smb_delete_new_object(smb_request_t *);
static int smb_set_open_attributes(smb_request_t *, smb_ofile_t *);

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
	char *fname;

	if (of->f_lease != NULL) {
		if (bcmp(sr->session->clnt_uuid,
		    of->f_session->clnt_uuid, 16) != 0)
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);

		if (op->op_oplock_level != SMB2_OPLOCK_LEVEL_LEASE)
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
		if (bcmp(op->lease_key, of->f_lease->ls_key,
		    SMB_LEASE_KEY_SZ) != 0)
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);

		/*
		 * We're supposed to check the name is the same.
		 * Not really necessary to do this, so just do
		 * minimal effort (check last component)
		 */
		fname = strrchr(op->fqi.fq_path.pn_path, '\\');
		if (fname != NULL)
			fname++;
		else
			fname = op->fqi.fq_path.pn_path;
		if (smb_strcasecmp(fname, of->f_node->od_name, 0) != 0) {
			cmn_err(CE_NOTE, "reconnect name <%s> of name <%s>",
			    fname, of->f_node->od_name);
			return (NT_STATUS_INVALID_PARAMETER);
		}
	} else {
		if (op->op_oplock_level == SMB2_OPLOCK_LEVEL_LEASE)
			return (NT_STATUS_OBJECT_NAME_NOT_FOUND);
	}

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
 *
 * Note that the oplock break code path can get to an ofile via the node
 * ofile list.  It starts with a ref taken in smb_ofile_hold_olbrk, which
 * waits if the ofile is found in state RECONNECT.  That wait happens with
 * the node ofile list lock held as reader, and the oplock mutex held.
 * Implications of that are: While we're in state RECONNECT, we shoud NOT
 * block (at least, not for long) and must not try to enter any of the
 * node ofile list lock or oplock mutex.  Thankfully, we don't need to
 * while moving an ofile from the old tree to the new tree.
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
	 * Only the last call attempting reclaim should be allowed to reclaim
	 * the ofile. The only *real* cause for multiple reclaimers would be
	 * when an active reclaimer is logged off or disconnected, and we get
	 * a new reconnect request before this one finishes. Clearly, in this
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
	 * At this point, we should be the only thread with a refcnt on the
	 * ofile, and the RECONNECT state should prevent new refcnts from
	 * being granted, or other durable threads from observing or
	 * reclaiming it, so it should be safe to drop the lock long enough
	 * to grab the others in the correct order.
	 */

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
	of->f_fid = fid;
	of->f_session = sr->session;

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

	/*
	 * In case smb_ofile_hold or smb_oplock_send_brk() are
	 * waiting for state RECONNECT to complete, wakeup.
	 */
	cv_broadcast(&of->f_cv);
	mutex_exit(&of->f_mutex);

	/*
	 * The ofile is now visible to the new session.
	 * From here, this is similar to the last part of
	 * smb_common_open().
	 */
	op->fqi.fq_fattr.sa_mask = SMB_AT_ALL;
	(void) smb_node_getattr(sr, node, zone_kcred(), of,
	    &op->fqi.fq_fattr);

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
		op->dsize = op->fqi.fq_fattr.sa_vattr.va_size;
	} else {
		/* directory or symlink */
		op->dsize = 0;
	}

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
 * smb_common_open
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
 *
 * 2. A setinfo operation (using either an open fid or a path) to set/unset
 * readonly will be successful regardless of whether a creator of a readonly
 * file has an open fid.
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
uint32_t
smb_common_open(smb_request_t *sr)
{
	smb_server_t	*sv = sr->sr_server;
	smb_tree_t	*tree = sr->tid_tree;
	smb_node_t	*fnode = NULL;
	smb_node_t	*dnode = NULL;
	smb_node_t	*cur_node = NULL;
	smb_arg_open_t	*op = &sr->sr_open;
	smb_pathname_t	*pn = &op->fqi.fq_path;
	smb_ofile_t	*of = NULL;
	smb_attr_t	new_attr;
	int		max_requested = 0;
	uint32_t	max_allowed;
	uint32_t	status = NT_STATUS_SUCCESS;
	int		is_dir;
	int		rc;
	boolean_t	is_stream = B_FALSE;
	int		lookup_flags = SMB_FOLLOW_LINKS;
	uint32_t	uniq_fid = 0;
	uint16_t	tree_fid = 0;
	boolean_t	created = B_FALSE;
	boolean_t	last_comp_found = B_FALSE;
	boolean_t	opening_incr = B_FALSE;
	boolean_t	dnode_held = B_FALSE;
	boolean_t	dnode_wlock = B_FALSE;
	boolean_t	fnode_held = B_FALSE;
	boolean_t	fnode_wlock = B_FALSE;
	boolean_t	fnode_shrlk = B_FALSE;
	boolean_t	did_open = B_FALSE;

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

	if (smb_idpool_alloc(&tree->t_fid_pool, &tree_fid))
		return (NT_STATUS_TOO_MANY_OPENED_FILES);

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
			goto errout;
		}

		/*
		 * Most of IPC open is handled in smb_opipe_open()
		 */
		uniq_fid = SMB_UNIQ_FID();
		op->create_options = 0;
		of = smb_ofile_alloc(sr, op, NULL, SMB_FTYPE_MESG_PIPE,
		    tree_fid, uniq_fid);
		status = smb_opipe_open(sr, of);
		smb_threshold_exit(&sv->sv_opipe_ct);
		if (status != NT_STATUS_SUCCESS)
			goto errout;
		return (NT_STATUS_SUCCESS);

	default:
		status = NT_STATUS_BAD_DEVICE_TYPE;
		goto errout;
	}

	smb_pathname_init(sr, pn, pn->pn_path);
	if (!smb_pathname_validate(sr, pn)) {
		status = sr->smb_error.status;
		goto errout;
	}

	if (strlen(pn->pn_path) >= SMB_MAXPATHLEN) {
		status = NT_STATUS_OBJECT_PATH_INVALID;
		goto errout;
	}

	if (is_dir) {
		if (!smb_validate_dirname(sr, pn)) {
			status = sr->smb_error.status;
			goto errout;
		}
	} else {
		if (!smb_validate_object_name(sr, pn)) {
			status = sr->smb_error.status;
			goto errout;
		}
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
			if (op->create_disposition == FILE_OPEN)
				status = NT_STATUS_OBJECT_NAME_NOT_FOUND;
			else
				status = NT_STATUS_ACCESS_DENIED;
			goto errout;
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
			status = smb_errno2status(rc);
			goto errout;
		}
	}
	dnode = op->fqi.fq_dnode;
	dnode_held = B_TRUE;

	/*
	 * Lock the parent dir node in case another create
	 * request to the same parent directory comes in.
	 * Drop this once either lookup succeeds, or we've
	 * created the object in this directory.
	 */
	smb_node_wrlock(dnode);
	dnode_wlock = B_TRUE;

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
		fnode_held = B_TRUE;

		/*
		 * Need the DOS attributes below, where we
		 * check the search attributes (sattr).
		 * Also UID, for owner check below.
		 */
		op->fqi.fq_fattr.sa_mask = SMB_AT_DOSATTR | SMB_AT_UID;
		rc = smb_node_getattr(sr, op->fqi.fq_fnode, zone_kcred(),
		    NULL, &op->fqi.fq_fattr);
		if (rc != 0) {
			status = NT_STATUS_INTERNAL_ERROR;
			goto errout;
		}
	} else if (rc == ENOENT) {
		last_comp_found = B_FALSE;
		op->fqi.fq_fnode = NULL;
		rc = 0;
	} else {
		status = smb_errno2status(rc);
		goto errout;
	}

	/*
	 * The uniq_fid is a CIFS-server-wide unique identifier for an ofile
	 * which is used to uniquely identify open instances for the
	 * VFS share reservation and POSIX locks.
	 */
	uniq_fid = SMB_UNIQ_FID();

	if (last_comp_found) {

		smb_node_unlock(dnode);
		dnode_wlock = B_FALSE;

		fnode = op->fqi.fq_fnode;
		dnode = op->fqi.fq_dnode;

		if (!smb_node_is_file(fnode) &&
		    !smb_node_is_dir(fnode) &&
		    !smb_node_is_symlink(fnode)) {
			status = NT_STATUS_ACCESS_DENIED;
			goto errout;
		}

		/*
		 * Reject this request if either:
		 * - the target IS a directory and the client requires that
		 *   it must NOT be (required by Lotus Notes)
		 * - the target is NOT a directory and client requires that
		 *   it MUST be.
		 */
		if (smb_node_is_dir(fnode)) {
			if (op->create_options & FILE_NON_DIRECTORY_FILE) {
				status = NT_STATUS_FILE_IS_A_DIRECTORY;
				goto errout;
			}
		} else {
			if ((op->create_options & FILE_DIRECTORY_FILE) ||
			    (op->nt_flags & NT_CREATE_FLAG_OPEN_TARGET_DIR)) {
				status = NT_STATUS_NOT_A_DIRECTORY;
				goto errout;
			}
		}

		/*
		 * No more open should be accepted when "Delete on close"
		 * flag is set.
		 */
		if (fnode->flags & NODE_FLAGS_DELETE_ON_CLOSE) {
			status = NT_STATUS_DELETE_PENDING;
			goto errout;
		}

		/*
		 * Specified file already exists so the operation should fail.
		 */
		if (op->create_disposition == FILE_CREATE) {
			status = NT_STATUS_OBJECT_NAME_COLLISION;
			goto errout;
		}

		/*
		 * Windows seems to check read-only access before file
		 * sharing check.
		 *
		 * Check to see if the file is currently readonly (regardless
		 * of whether this open will make it readonly).
		 * Readonly is ignored on directories.
		 */
		if (SMB_PATHFILE_IS_READONLY(sr, fnode) &&
		    !smb_node_is_dir(fnode)) {
			if (op->desired_access &
			    (FILE_WRITE_DATA | FILE_APPEND_DATA)) {
				status = NT_STATUS_ACCESS_DENIED;
				goto errout;
			}
			if (op->create_options & FILE_DELETE_ON_CLOSE) {
				status = NT_STATUS_CANNOT_DELETE;
				goto errout;
			}
		}

		if ((op->create_disposition == FILE_SUPERSEDE) ||
		    (op->create_disposition == FILE_OVERWRITE_IF) ||
		    (op->create_disposition == FILE_OVERWRITE)) {

			if (!smb_sattr_check(op->fqi.fq_fattr.sa_dosattr,
			    op->dattr)) {
				status = NT_STATUS_ACCESS_DENIED;
				goto errout;
			}

			if (smb_node_is_dir(fnode)) {
				status = NT_STATUS_ACCESS_DENIED;
				goto errout;
			}
		}

		/* MS-FSA 2.1.5.1.2 */
		if (op->create_disposition == FILE_SUPERSEDE)
			op->desired_access |= DELETE;
		if ((op->create_disposition == FILE_OVERWRITE_IF) ||
		    (op->create_disposition == FILE_OVERWRITE))
			op->desired_access |= FILE_WRITE_DATA;

		status = smb_fsop_access(sr, sr->user_cr, fnode,
		    op->desired_access);
		if (status != NT_STATUS_SUCCESS)
			goto errout;

		if (max_requested) {
			smb_fsop_eaccess(sr, sr->user_cr, fnode, &max_allowed);
			op->desired_access |= max_allowed;
		}

		/*
		 * File owner should always get read control + read attr.
		 */
		if (crgetuid(sr->user_cr) == op->fqi.fq_fattr.sa_vattr.va_uid)
			op->desired_access |=
			    (READ_CONTROL | FILE_READ_ATTRIBUTES);

		/*
		 * According to MS "dochelp" mail in Mar 2015, any handle
		 * on which read or write access is granted implicitly
		 * gets "read attributes", even if it was not requested.
		 */
		if ((op->desired_access & FILE_DATA_ALL) != 0)
			op->desired_access |= FILE_READ_ATTRIBUTES;

		/*
		 * Oplock break is done prior to sharing checks as the break
		 * may cause other clients to close the file which would
		 * affect the sharing checks, and may delete the file due to
		 * DELETE_ON_CLOSE. This may block, so set the file opening
		 * count before oplock stuff.
		 */
		of = smb_ofile_alloc(sr, op, fnode, SMB_FTYPE_DISK,
		    tree_fid, uniq_fid);

		smb_node_inc_opening_count(fnode);
		opening_incr = B_TRUE;

		/*
		 * XXX Supposed to do share access checks next.
		 * [MS-FSA] describes that as part of access check:
		 * 2.1.5.1.2.1 Alg... Check Access to an Existing File
		 *
		 * If CreateDisposition is FILE_OPEN or FILE_OPEN_IF:
		 *   If Open.Stream.Oplock is not empty and
		 *   Open.Stream.Oplock.State contains BATCH_OPLOCK,
		 *   the object store MUST check for an oplock
		 *   break according to the algorithm in section 2.1.4.12,
		 *   with input values as follows:
		 *	Open equal to this operation's Open
		 *	Oplock equal to Open.Stream.Oplock
		 *	Operation equal to "OPEN"
		 *	OpParams containing two members:
		 *	  DesiredAccess, CreateDisposition
		 *
		 * It's not clear how Windows would ask the FS layer if
		 * the file has a BATCH oplock.  We'll use a call to the
		 * common oplock code, which calls smb_oplock_break_OPEN
		 * only if the oplock state contains BATCH_OPLOCK.
		 * See: smb_oplock_break_BATCH()
		 *
		 * Also note: There's a nearly identical section in the
		 * spec. at the start of the "else" part of the above
		 * "if (disposition is overwrite, overwrite_if)" so this
		 * section (oplock break, the share mode check, and the
		 * next oplock_break_HANDLE) are all factored out to be
		 * in all cases above that if/else from the spec.
		 */
		status = smb_oplock_break_BATCH(fnode, of,
		    op->desired_access, op->create_disposition);
		if (status == NT_STATUS_OPLOCK_BREAK_IN_PROGRESS) {
			if (sr->session->dialect >= SMB_VERS_2_BASE)
				(void) smb2sr_go_async(sr);
			(void) smb_oplock_wait_break(fnode, 0);
			status = 0;
		}
		if (status != NT_STATUS_SUCCESS)
			goto errout;

		/*
		 * Check for sharing violations, and if any,
		 * do oplock break of handle caching.
		 *
		 * Need node_wrlock during shrlock checks,
		 * and not locked during oplock breaks,
		 * until after the smb_fsop_shrlock call.
		 */
		smb_node_wrlock(fnode);
		fnode_wlock = B_TRUE;
		status = smb_fsop_shrlock(sr->user_cr, fnode, uniq_fid,
		    op->desired_access, op->share_access);
		if (status == NT_STATUS_SHARING_VIOLATION) {
			hrtime_t t0 = gethrtime();

			smb_node_unlock(fnode);
			fnode_wlock = B_FALSE;

			/* [MS-FSA] "OPEN_BREAK_H" */
			status = smb_oplock_break_HANDLE(fnode, of);
			if (status == NT_STATUS_OPLOCK_BREAK_IN_PROGRESS) {
				if (sr->session->dialect >= SMB_VERS_2_BASE)
					(void) smb2sr_go_async(sr);
				(void) smb_oplock_wait_break(fnode, 0);
				status = 0;
			}
			if (status != NT_STATUS_SUCCESS)
				goto errout;

			/*
			 * SMB1 expects a 1 sec. delay before returning a
			 * sharing violation error.  If breaking oplocks
			 * above took less than a sec, wait some more.
			 * See: smbtorture base.defer_open
			 */
			if (sr->session->dialect < SMB_VERS_2_BASE) {
				hrtime_t t1 = t0 + NANOSEC;
				hrtime_t now = gethrtime();
				if (now < t1) {
					delay(NSEC_TO_TICK_ROUNDUP(t1 - now));
				}
			}

			smb_node_wrlock(fnode);
			fnode_wlock = B_TRUE;

			status = smb_fsop_shrlock(sr->user_cr, fnode, uniq_fid,
			    op->desired_access, op->share_access);
		}
		if (status != NT_STATUS_SUCCESS)
			goto errout;
		fnode_shrlk = B_TRUE;

		smb_node_unlock(fnode);
		fnode_wlock = B_FALSE;

		/*
		 * The [MS-FSA] spec. describes this oplock break as
		 * part of the sharing access checks.  See:
		 * 2.1.5.1.2.2 Algorithm to Check Sharing Access...
		 * At the end of the share mode tests described there,
		 * if it has not returned "sharing violation", it
		 * specifies a call to the alg. in sec. 2.1.4.12,
		 * that boils down to: smb_oplock_break_OPEN()
		 */
		status = smb_oplock_break_OPEN(fnode, of,
		    op->desired_access,
		    op->create_disposition);
		if (status == NT_STATUS_OPLOCK_BREAK_IN_PROGRESS) {
			if (sr->session->dialect >= SMB_VERS_2_BASE)
				(void) smb2sr_go_async(sr);
			(void) smb_oplock_wait_break(fnode, 0);
			status = 0;
		}
		if (status != NT_STATUS_SUCCESS)
			goto errout;

		if ((fnode->flags & NODE_FLAGS_DELETE_COMMITTED) != 0) {
			/*
			 * Breaking the oplock caused the file to be deleted,
			 * so let's bail and pretend the file wasn't found.
			 * Have to duplicate much of the logic found a the
			 * "errout" label here.
			 *
			 * This code path is exercised by smbtorture
			 * smb2.durable-open.delete_on_close1
			 */
			DTRACE_PROBE1(node_deleted, smb_node_t, fnode);
			smb_ofile_free(of);
			of = NULL;
			last_comp_found = B_FALSE;

			/*
			 * Get all the holds and locks into the state
			 * they would have if lookup had failed.
			 */
			fnode_shrlk = B_FALSE;
			smb_fsop_unshrlock(sr->user_cr, fnode, uniq_fid);

			opening_incr = B_FALSE;
			smb_node_dec_opening_count(fnode);

			fnode_held = B_FALSE;
			smb_node_release(fnode);

			dnode_wlock = B_TRUE;
			smb_node_wrlock(dnode);

			goto create;
		}

		/*
		 * Go ahead with modifications as necessary.
		 */
		switch (op->create_disposition) {
		case FILE_SUPERSEDE:
		case FILE_OVERWRITE_IF:
		case FILE_OVERWRITE:
			op->dattr |= FILE_ATTRIBUTE_ARCHIVE;
			/* Don't apply readonly until smb_set_open_attributes */
			if (op->dattr & FILE_ATTRIBUTE_READONLY) {
				op->dattr &= ~FILE_ATTRIBUTE_READONLY;
				op->created_readonly = B_TRUE;
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
			rc = smb_fsop_setattr(sr, sr->user_cr, fnode,
			    &new_attr);
			if (rc != 0) {
				status = smb_errno2status(rc);
				goto errout;
			}

			/*
			 * If file is being replaced, remove existing streams
			 */
			if (SMB_IS_STREAM(fnode) == 0) {
				status = smb_fsop_remove_streams(sr,
				    sr->user_cr, fnode);
				if (status != 0)
					goto errout;
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
			status = NT_STATUS_OBJECT_NAME_NOT_FOUND;
			goto errout;
		}

		if (pn->pn_fname && smb_is_invalid_filename(pn->pn_fname)) {
			status = NT_STATUS_OBJECT_NAME_INVALID;
			goto errout;
		}

		/*
		 * Don't create in directories marked "Delete on close".
		 */
		if (dnode->flags & NODE_FLAGS_DELETE_ON_CLOSE) {
			status = NT_STATUS_DELETE_PENDING;
			goto errout;
		}

		/*
		 * Create always sets the DOS attributes, type, and mode
		 * in the if/else below (different for file vs directory).
		 * Don't set the readonly bit until smb_set_open_attributes
		 * or that would prevent this open.  Note that op->dattr
		 * needs to be what smb_set_open_attributes will use,
		 * except for the readonly bit.
		 */
		bzero(&new_attr, sizeof (new_attr));
		new_attr.sa_mask = SMB_AT_DOSATTR | SMB_AT_TYPE | SMB_AT_MODE;
		if (op->dattr & FILE_ATTRIBUTE_READONLY) {
			op->dattr &= ~FILE_ATTRIBUTE_READONLY;
			op->created_readonly = B_TRUE;
		}

		/*
		 * SMB create can specify the create time.
		 */
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
		} else {
			op->dattr |= FILE_ATTRIBUTE_DIRECTORY;
			new_attr.sa_dosattr = op->dattr;
			new_attr.sa_vattr.va_type = VDIR;
			new_attr.sa_vattr.va_mode = 0777;

			rc = smb_fsop_mkdir(sr, sr->user_cr, dnode,
			    op->fqi.fq_last_comp, &new_attr, &op->fqi.fq_fnode);
		}
		if (rc != 0) {
			status = smb_errno2status(rc);
			goto errout;
		}

		smb_node_unlock(dnode);
		dnode_wlock = B_FALSE;

		created = B_TRUE;
		op->action_taken = SMB_OACT_CREATED;

		fnode = op->fqi.fq_fnode;
		fnode_held = B_TRUE;

		smb_node_inc_opening_count(fnode);
		opening_incr = B_TRUE;

		smb_node_wrlock(fnode);
		fnode_wlock = B_TRUE;

		status = smb_fsop_shrlock(sr->user_cr, fnode, uniq_fid,
		    op->desired_access, op->share_access);
		if (status != 0)
			goto errout;
		fnode_shrlk = B_TRUE;

		if (max_requested) {
			smb_fsop_eaccess(sr, sr->user_cr, fnode, &max_allowed);
			op->desired_access |= max_allowed;
		}
		/*
		 * We created this object (we own it) so grant
		 * read_control + read_attributes on this handle,
		 * even if that was not requested.  This avoids
		 * unexpected access failures later.
		 */
		op->desired_access |= (READ_CONTROL | FILE_READ_ATTRIBUTES);

		/*
		 * MS-FSA 2.1.5.1.1
		 * If the Oplock member of the DirectoryStream in
		 * Link.ParentFile.StreamList (ParentOplock) is
		 * not empty ... oplock break on the parent...
		 * (dnode is the parent directory)
		 *
		 * This compares of->ParentOplockKey with each
		 * oplock of->TargetOplockKey and breaks...
		 * so it's OK that we're passing an OF that's
		 * NOT a member of dnode->n_ofile_list
		 *
		 * The break never blocks, so ignore the return.
		 */
		of = smb_ofile_alloc(sr, op, fnode, SMB_FTYPE_DISK,
		    tree_fid, uniq_fid);
		(void) smb_oplock_break_PARENT(dnode, of);
	}

	/*
	 * We might have blocked in smb_oplock_break_OPEN long enough
	 * so a tree disconnect might have happened.  In that case,
	 * we would be adding an ofile to a tree that's disconnecting,
	 * which would interfere with tear-down.  If so, error out.
	 */
	if (!smb_tree_is_connected(sr->tid_tree)) {
		status = NT_STATUS_INVALID_PARAMETER;
		goto errout;
	}

	/*
	 * Moved this up from smb_ofile_open()
	 */
	if ((rc = smb_fsop_open(fnode, of->f_mode, of->f_cr)) != 0) {
		status = smb_errno2status(rc);
		goto errout;
	}

	/*
	 * Complete this open (add to ofile lists)
	 */
	smb_ofile_open(sr, op, of);
	did_open = B_TRUE;

	/*
	 * This MUST be done after ofile creation, so that explicitly
	 * set timestamps can be remembered on the ofile, and setting
	 * the readonly flag won't affect access via this open.
	 */
	if ((rc = smb_set_open_attributes(sr, of)) != 0) {
		status = smb_errno2status(rc);
		goto errout;
	}

	/*
	 * We've already done access checks above,
	 * and want this call to succeed even when
	 * !(desired_access & FILE_READ_ATTRIBUTES),
	 * so pass kcred here.
	 */
	op->fqi.fq_fattr.sa_mask = SMB_AT_ALL;
	(void) smb_node_getattr(sr, fnode, zone_kcred(), of,
	    &op->fqi.fq_fattr);

	/*
	 * Propagate the write-through mode from the open params
	 * to the node: see the notes in the function header.
	 * XXX: write_through should be a flag on the ofile.
	 */
	if (sr->sr_cfg->skc_sync_enable ||
	    (op->create_options & FILE_WRITE_THROUGH))
		fnode->flags |= NODE_FLAGS_WRITE_THROUGH;

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

	if (smb_node_is_file(fnode)) {
		op->dsize = op->fqi.fq_fattr.sa_vattr.va_size;
	} else {
		/* directory or symlink */
		op->dsize = 0;
	}

	/*
	 * Note: oplock_acquire happens in callers, because
	 * how that happens is protocol-specific.
	 */

	if (fnode_wlock)
		smb_node_unlock(fnode);
	if (opening_incr)
		smb_node_dec_opening_count(fnode);
	if (fnode_held)
		smb_node_release(fnode);
	if (dnode_wlock)
		smb_node_unlock(dnode);
	if (dnode_held)
		smb_node_release(dnode);

	return (NT_STATUS_SUCCESS);

errout:
	if (did_open) {
		smb_ofile_close(of, 0);
		/* Don't also ofile_free */
	} else if (of != NULL) {
		smb_ofile_free(of);
	}

	if (fnode_shrlk)
		smb_fsop_unshrlock(sr->user_cr, fnode, uniq_fid);

	if (created) {
		/* Try to roll-back create. */
		smb_delete_new_object(sr);
	}

	if (fnode_wlock)
		smb_node_unlock(fnode);
	if (opening_incr)
		smb_node_dec_opening_count(fnode);
	if (fnode_held)
		smb_node_release(fnode);
	if (dnode_wlock)
		smb_node_unlock(dnode);
	if (dnode_held)
		smb_node_release(dnode);

	if (tree_fid != 0)
		smb_idpool_free(&tree->t_fid_pool, tree_fid);

	return (status);
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
	 * clients expect.
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
