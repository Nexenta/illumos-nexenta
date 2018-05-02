/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
 */


#include <smbsrv/smb2_kproto.h>
#include <smbsrv/smb_kstat.h>
#include <smbsrv/smb2.h>

/*
 * Saved state for a command that "goes async".  When a compound request
 * contains a command that may block indefinitely, the compound reply is
 * composed with an "interim response" for that command, and information
 * needed to actually dispatch that command is saved on a list of "async"
 * commands for this compound request.  After the compound reply is sent,
 * the list of async commands is processed, and those may block as long
 * as they need to without affecting the initial compound request.
 *
 * Now interestingly, this "async" mechanism is not used with the full
 * range of asynchrony that one might imagine.  The design of async
 * request processing can be drastically simplified if we can assume
 * that there's no need to run more than one async command at a time.
 * With that simplifying assumption, we can continue using the current
 * "one worker thread per request message" model, which has very simple
 * locking rules etc.  The same worker thread that handles the initial
 * compound request can handle the list of async requests.
 *
 * As it turns out, SMB2 clients do not try to use more than one "async"
 * command in a compound.  If they were to do so, the [MS-SMB2] spec.
 * allows us to decline additional async requests with an error.
 *
 * smb_async_req_t is the struct used to save an "async" request on
 * the list of requests that had an interim reply in the initial
 * compound reply.  This includes everything needed to restart
 * processing at the async command.
 */

typedef struct smb2_async_req {

	smb_sdrc_t		(*ar_func)(smb_request_t *);

	int ar_cmd_hdr;		/* smb2_cmd_hdr offset */
	int ar_cmd_len;		/* length from hdr */

	/*
	 * SMB2 header fields.
	 */
	uint64_t		ar_messageid;
	uint64_t		ar_ssnid;
	uint16_t		ar_cmd_code;
	uint16_t		ar_tid;
	uint32_t		ar_pid;
	uint32_t		ar_hdr_flags;
} smb2_async_req_t;

void smb2sr_do_async(smb_request_t *);
smb_sdrc_t smb2_invalid_cmd(smb_request_t *);
static void smb2_tq_work(void *);
static int smb3_decrypt_msg(smb_request_t *);

static const smb_disp_entry_t const
smb2_disp_table[SMB2__NCMDS] = {

	/* text-name, pre, func, post, cmd-code, dialect, flags */

	{  "smb2_negotiate", NULL,
	    smb2_negotiate, NULL, 0, 0,
	    SDDF_SUPPRESS_TID | SDDF_SUPPRESS_UID },

	{  "smb2_session_setup", NULL,
	    smb2_session_setup, NULL, 0, 0,
	    SDDF_SUPPRESS_TID | SDDF_SUPPRESS_UID },

	{  "smb2_logoff", NULL,
	    smb2_logoff, NULL, 0, 0,
	    SDDF_SUPPRESS_TID },

	{  "smb2_tree_connect", NULL,
	    smb2_tree_connect, NULL, 0, 0,
	    SDDF_SUPPRESS_TID },

	{  "smb2_tree_disconn", NULL,
	    smb2_tree_disconn, NULL, 0, 0 },

	{  "smb2_create", NULL,
	    smb2_create, NULL, 0, 0 },

	{  "smb2_close", NULL,
	    smb2_close, NULL, 0, 0 },

	{  "smb2_flush", NULL,
	    smb2_flush, NULL, 0, 0 },

	{  "smb2_read", NULL,
	    smb2_read, NULL, 0, 0 },

	{  "smb2_write", NULL,
	    smb2_write, NULL, 0, 0 },

	{  "smb2_lock", NULL,
	    smb2_lock, NULL, 0, 0 },

	{  "smb2_ioctl", NULL,
	    smb2_ioctl, NULL, 0, 0 },

	{  "smb2_cancel", NULL,
	    smb2_cancel, NULL, 0, 0,
	    SDDF_SUPPRESS_UID | SDDF_SUPPRESS_TID },

	{  "smb2_echo", NULL,
	    smb2_echo, NULL, 0, 0,
	    SDDF_SUPPRESS_UID | SDDF_SUPPRESS_TID },

	{  "smb2_query_dir", NULL,
	    smb2_query_dir, NULL, 0, 0 },

	{  "smb2_change_notify", NULL,
	    smb2_change_notify, NULL, 0, 0 },

	{  "smb2_query_info", NULL,
	    smb2_query_info, NULL, 0, 0 },

	{  "smb2_set_info", NULL,
	    smb2_set_info, NULL, 0, 0 },

	{  "smb2_oplock_break_ack", NULL,
	    smb2_oplock_break_ack, NULL, 0, 0 },

	{  "smb2_invalid_cmd", NULL,
	    smb2_invalid_cmd, NULL, 0, 0,
	    SDDF_SUPPRESS_UID | SDDF_SUPPRESS_TID },
};

smb_sdrc_t
smb2_invalid_cmd(smb_request_t *sr)
{
#ifdef	DEBUG
	cmn_err(CE_NOTE, "clnt %s bad SMB2 cmd code",
	    sr->session->ip_addr_str);
#endif
	sr->smb2_status = NT_STATUS_INVALID_PARAMETER;
	return (SDRC_DROP_VC);
}

/*
 * This is the SMB2 handler for new smb requests, called from
 * smb_session_reader after SMB negotiate is done.  For most SMB2
 * requests, we just enqueue them for the smb_session_worker to
 * execute via the task queue, so they can block for resources
 * without stopping the reader thread.  A few protocol messages
 * are special cases and are handled directly here in the reader
 * thread so they don't wait for taskq scheduling.
 *
 * This function must either enqueue the new request for
 * execution via the task queue, or execute it directly
 * and then free it.  If this returns non-zero, the caller
 * will drop the session.
 */
int
smb2sr_newrq(smb_request_t *sr)
{
	struct mbuf_chain *mbc = &sr->command;
	uint32_t magic;
	int rc, skip;

	if (smb_mbc_peek(mbc, 0, "l", &magic) != 0)
		goto drop;

	/* 0xFD S M B */
	if (magic == SMB3_ENCRYPTED_MAGIC) {
		if (smb3_decrypt_msg(sr) != 0)
			goto drop;
		/*
		 * Should now be looking at an un-encrypted
		 * SMB2 message header.
		 */
		if (smb_mbc_peek(mbc, 0, "l", &magic) != 0)
			goto drop;
	}

	if (magic != SMB2_PROTOCOL_MAGIC)
		goto drop;

	/*
	 * Walk the SMB2 commands in this compound message and
	 * update the scoreboard to record that we've received
	 * the new message IDs in these commands.
	 */
	for (;;) {
		if (smb2_decode_header(sr) != 0)
			goto drop;

		/*
		 * Cancel requests are special:  They refer to
		 * an earlier message ID (or an async. ID),
		 * never a new ID, and are never compounded.
		 * This is intentionally not "goto drop"
		 * because rc may be zero (success).
		 */
		if (sr->smb2_cmd_code == SMB2_CANCEL) {
			rc = smb2_newrq_cancel(sr);
			smb_request_free(sr);
			return (rc);
		}

		if ((rc = smb2_scoreboard_cmd_new(sr)) != 0) {
			/* Logging was done in the above call. */
			goto drop;
		}

		/* Normal loop exit on next == zero */
		if (sr->smb2_next_command == 0)
			break;

		/* Abundance of caution... */
		if (sr->smb2_next_command < SMB2_HDR_SIZE)
			goto drop;

		/* Advance to the next header. */
		skip = sr->smb2_next_command - SMB2_HDR_SIZE;
		if (MBC_ROOM_FOR(mbc, skip) == 0)
			goto drop;
		mbc->chain_offset += skip;
	}
	/* Rewind back to the top. */
	mbc->chain_offset = 0;

	/*
	 * Submit the request to the task queue, which calls
	 * smb2_tq_work when the workload permits.
	 */
	sr->sr_time_submitted = gethrtime();
	sr->sr_state = SMB_REQ_STATE_SUBMITTED;
	smb_srqueue_waitq_enter(sr->session->s_srqueue);
	(void) taskq_dispatch(sr->sr_server->sv_worker_pool,
	    smb2_tq_work, sr, TQ_SLEEP);
	return (0);

drop:
	smb_request_free(sr);
	return (-1);
}

static void
smb2_tq_work(void *arg)
{
	smb_request_t	*sr;
	smb_srqueue_t	*srq;

	sr = (smb_request_t *)arg;
	SMB_REQ_VALID(sr);

	srq = sr->session->s_srqueue;
	smb_srqueue_waitq_to_runq(srq);
	sr->sr_worker = curthread;
	sr->sr_time_active = gethrtime();

	/*
	 * Always dispatch to the work function, because cancelled
	 * requests need an error reply (NT_STATUS_CANCELLED).
	 */
	mutex_enter(&sr->sr_mutex);
	if (sr->sr_state == SMB_REQ_STATE_SUBMITTED)
		sr->sr_state = SMB_REQ_STATE_ACTIVE;
	mutex_exit(&sr->sr_mutex);

	smb2sr_work(sr);

	smb_srqueue_runq_exit(srq);
}

static int
smb3_decrypt_msg(smb_request_t *sr)
{
	int save_offset;

	if (sr->session->dialect < SMB_VERS_3_0) {
		cmn_err(CE_WARN, "encrypted message in SMB 2.x");
		return (-1);
	}

	sr->encrypted = B_TRUE;
	save_offset = sr->command.chain_offset;
	if (smb3_decode_tform_header(sr) != 0) {
		cmn_err(CE_WARN, "bad transform header");
		return (-1);
	}
	sr->command.chain_offset = save_offset;

	sr->tform_ssn = smb_session_lookup_ssnid(sr->session,
	    sr->smb3_tform_ssnid);
	if (sr->tform_ssn == NULL) {
		cmn_err(CE_WARN, "transform header: session not found");
		return (-1);
	}

	if (smb3_decrypt_sr(sr) != 0) {
		cmn_err(CE_WARN, "smb3 decryption failed");
		return (-1);
	}

	return (0);
}

/*
 * smb2sr_work
 *
 * This function processes each SMB command in the current request
 * (which may be a compound request) building a reply containing
 * SMB reply messages, one-to-one with the SMB commands.  Some SMB
 * commands (change notify, blocking locks) may require both an
 * "interim response" and a later "async response" at completion.
 * In such cases, we'll encode the interim response in the reply
 * compound we're building, and put the (now async) command on a
 * list of commands that need further processing.  After we've
 * finished processing the commands in this compound and building
 * the compound reply, we'll send the compound reply, and finally
 * process the list of async commands.
 *
 * As we work our way through the compound request and reply,
 * we need to keep track of the bounds of the current request
 * and reply.  For the request, this uses an MBC_SHADOW_CHAIN
 * that begins at smb2_cmd_hdr.  The reply is appended to the
 * sr->reply chain starting at smb2_reply_hdr.
 *
 * This function must always free the smb request, or arrange
 * for it to be completed and free'd later (if SDRC_SR_KEPT).
 */
void
smb2sr_work(struct smb_request *sr)
{
	const smb_disp_entry_t	*sdd;
	smb_disp_stats_t	*sds;
	smb_session_t		*session;
	uint32_t		msg_len;
	uint16_t		cmd_idx;
	int			rc = 0;
	boolean_t		disconnect = B_FALSE;
	boolean_t		related;

	session = sr->session;

	ASSERT(sr->tid_tree == 0);
	ASSERT(sr->uid_user == 0);
	ASSERT(sr->fid_ofile == 0);
	sr->smb_fid = (uint16_t)-1;
	sr->smb2_status = 0;

	/* temporary until we identify a user */
	sr->user_cr = zone_kcred();

cmd_start:
	/*
	 * Note that we don't check sr_state here and abort the
	 * compound if cancelled (etc.) because some SMB2 command
	 * handlers need to do work even when cancelled.
	 *
	 * We treat some status codes as if "sticky", meaning
	 * once they're set after some command handler returns,
	 * all remaining commands get this status without even
	 * calling the command-specific handler.
	 */
	if (sr->smb2_status != NT_STATUS_CANCELLED &&
	    sr->smb2_status != NT_STATUS_INSUFFICIENT_RESOURCES)
		sr->smb2_status = 0;

	/*
	 * Decode the request header
	 *
	 * Most problems with decoding will result in the error
	 * STATUS_INVALID_PARAMETER.  If the decoding problem
	 * prevents continuing, we'll close the connection.
	 * [MS-SMB2] 3.3.5.2.6 Handling Incorrectly Formatted...
	 */
	sr->smb2_cmd_hdr = sr->command.chain_offset;
	if ((rc = smb2_decode_header(sr)) != 0) {
		cmn_err(CE_WARN, "clnt %s bad SMB2 header",
		    session->ip_addr_str);
		disconnect = B_TRUE;
		goto cleanup;
	}

	/*
	 * Update the "scoreboard" for this new command, and
	 * check whether this message ID was marked cancelled.
	 */
	if (smb2_scoreboard_cmd_start(sr)) {
		/*
		 * This command was cancelled.  Update sr_state
		 * and continue.  See notes above at cmd_start.
		 */
		mutex_enter(&sr->sr_mutex);
		if (sr->sr_state == SMB_REQ_STATE_ACTIVE)
			sr->sr_state = SMB_REQ_STATE_CANCELLED;
		mutex_exit(&sr->sr_mutex);
	}

	/*
	 * The SMB2_FLAGS_SERVER_TO_REDIR should only appear
	 * in messages from the server back to the client.
	 */
	if ((sr->smb2_hdr_flags & SMB2_FLAGS_SERVER_TO_REDIR) != 0) {
		cmn_err(CE_WARN, "clnt %s bad SMB2 flags",
		    session->ip_addr_str);
		disconnect = B_TRUE;
		goto cleanup;
	}
	related = (sr->smb2_hdr_flags & SMB2_FLAGS_RELATED_OPERATIONS);

	/*
	 * In case we bail out with an error before we get to the
	 * section that computes the credit grant, initialize the
	 * response header fields so that credits won't change.
	 * Note: SMB 2.02 clients may send credit charge zero.
	 */
	if (sr->smb2_credit_charge == 0)
		sr->smb2_credit_charge = 1;
	sr->smb2_credit_response = sr->smb2_credit_charge;

	/*
	 * Reserve space for the reply header, and save the offset.
	 * The reply header will be overwritten later.  If we have
	 * already exhausted the output space, then this client is
	 * trying something funny.  Log it and kill 'em.
	 */
	ASSERT((sr->reply.chain_offset & 7) == 0);
	sr->smb2_reply_hdr = sr->reply.chain_offset;
	if ((rc = smb2_encode_header(sr, B_FALSE)) != 0) {
		cmn_err(CE_WARN, "clnt %s excessive reply",
		    session->ip_addr_str);
		disconnect = B_TRUE;
		goto cleanup;
	}

	/*
	 * Figure out the length of data following the SMB2 header.
	 * It ends at either the next SMB2 header if there is one
	 * (smb2_next_command != 0) or at the end of the message.
	 */
	if (sr->smb2_next_command != 0) {
		/* [MS-SMB2] says this is 8-byte aligned */
		msg_len = sr->smb2_next_command;
		if ((msg_len & 7) != 0 || (msg_len < SMB2_HDR_SIZE) ||
		    ((sr->smb2_cmd_hdr + msg_len) > sr->command.max_bytes)) {
			cmn_err(CE_WARN, "clnt %s bad SMB2 next cmd",
			    session->ip_addr_str);
			disconnect = B_TRUE;
			goto cleanup;
		}
	} else {
		msg_len = sr->command.max_bytes - sr->smb2_cmd_hdr;
	}

	/*
	 * Setup a shadow chain for this SMB2 command, starting
	 * with the header and ending at either the next command
	 * or the end of the message.  The signing check below
	 * needs the entire SMB2 command.  After that's done, we
	 * advance chain_offset to the end of the header where
	 * the command specific handlers continue decoding.
	 */
	(void) MBC_SHADOW_CHAIN(&sr->smb_data, &sr->command,
	    sr->smb2_cmd_hdr, msg_len);

	/*
	 * We will consume the data for this request from smb_data.
	 * That effectively consumes msg_len bytes from sr->command
	 * but doesn't update its chain_offset, so we need to update
	 * that here to make later received bytes accounting work.
	 */
	sr->command.chain_offset = sr->smb2_cmd_hdr + msg_len;
	ASSERT(sr->command.chain_offset <= sr->command.max_bytes);

	/*
	 * Validate the commmand code, get dispatch table entries.
	 * [MS-SMB2] 3.3.5.2.6 Handling Incorrectly Formatted...
	 *
	 * The last slot in the dispatch table is used to handle
	 * invalid commands.  Same for statistics.
	 */
	if (sr->smb2_cmd_code < SMB2_INVALID_CMD)
		cmd_idx = sr->smb2_cmd_code;
	else
		cmd_idx = SMB2_INVALID_CMD;
	sdd = &smb2_disp_table[cmd_idx];
	sds = &session->s_server->sv_disp_stats2[cmd_idx];

	/*
	 * If this command is NOT "related" to the previous,
	 * clear out the UID, TID, FID state that might be
	 * left over from the previous command.
	 *
	 * If the command IS related, any new IDs are ignored,
	 * and we simply continue with the previous user, tree,
	 * and open file.
	 */
	if (!related) {
		/*
		 * Drop user, tree, file; carefully ordered to
		 * avoid dangling references: file, tree, user
		 */
		if (sr->fid_ofile != NULL) {
			smb_ofile_request_complete(sr->fid_ofile);
			smb_ofile_release(sr->fid_ofile);
			sr->fid_ofile = NULL;
		}
		if (sr->tid_tree != NULL) {
			smb_tree_release(sr->tid_tree);
			sr->tid_tree = NULL;
		}
		if (sr->uid_user != NULL) {
			smb_user_release(sr->uid_user);
			sr->uid_user = NULL;
			sr->user_cr = zone_kcred();
		}
	}

	/*
	 * Make sure we have a user and tree as needed
	 * according to the flags for the this command.
	 * Note that we may have inherited these.
	 */
	if ((sdd->sdt_flags & SDDF_SUPPRESS_UID) == 0) {
		/*
		 * This command requires a user session.
		 */
		if (related) {
			/*
			 * Previous command should have given us a user.
			 * [MS-SMB2] 3.3.5.2 Handling Related Requests
			 */
			if (sr->uid_user == NULL) {
				smb2sr_put_error(sr,
				    NT_STATUS_INVALID_PARAMETER);
				goto cmd_done;
			}
			sr->smb2_ssnid = sr->uid_user->u_ssnid;
		} else {
			/*
			 * Lookup the UID
			 * [MS-SMB2] 3.3.5.2 Verifying the Session
			 */
			ASSERT(sr->uid_user == NULL);
			/*
			 * [MS-SMB2] 3.3.5.2.7 Handling Compounded Requests
			 *
			 * If this is an encrypted compound request,
			 * ensure that the ssnid in the request
			 * is the same as the tform ssnid if this
			 * message is not related.
			 *
			 * The reasons this is done seem to apply equally
			 * to uncompounded requests, so we apply it to all.
			 */

			if (sr->encrypted &&
			    sr->smb2_ssnid != sr->smb3_tform_ssnid) {
				disconnect = B_TRUE;
				goto cleanup; /* just do this for now */
			}

			sr->uid_user = smb_session_lookup_ssnid(session,
			    sr->smb2_ssnid);
			if (sr->uid_user == NULL) {
				smb2sr_put_error(sr,
				    NT_STATUS_USER_SESSION_DELETED);
				goto cmd_done;
			}

			/*
			 * [MS-SMB2] 3.3.5.2.9 Verifying the Session
			 *
			 * If we're talking 3.x,
			 * RejectUnencryptedAccess is TRUE,
			 * Session.EncryptData is TRUE,
			 * and the message wasn't encrypted,
			 * return ACCESS_DENIED.
			 *
			 * Note that Session.EncryptData can only be TRUE when
			 * we're talking 3.x.
			 */

			if (sr->uid_user->u_encrypt ==
			    SMB_CONFIG_REQUIRED &&
			    !sr->encrypted) {
				smb2sr_put_error(sr,
				    NT_STATUS_ACCESS_DENIED);
				goto cmd_done;
			}

			sr->user_cr = smb_user_getcred(sr->uid_user);
		}
		ASSERT(sr->uid_user != NULL);

		/*
		 * Encrypt if:
		 * - The cmd is not SESSION_SETUP or NEGOTIATE; AND
		 * - Session.EncryptData is TRUE
		 *
		 * Those commands suppress UID, so they can't be the cmd here.
		 */
		if (sr->uid_user->u_encrypt != SMB_CONFIG_DISABLED &&
		    sr->tform_ssn == NULL) {
			smb_user_hold_internal(sr->uid_user);
			sr->tform_ssn = sr->uid_user;
			sr->smb3_tform_ssnid = sr->smb2_ssnid;
		}
	}

	if ((sdd->sdt_flags & SDDF_SUPPRESS_TID) == 0) {
		/*
		 * This command requires a tree connection.
		 */
		if (related) {
			/*
			 * Previous command should have given us a tree.
			 * [MS-SMB2] 3.3.5.2 Handling Related Requests
			 */
			if (sr->tid_tree == NULL) {
				smb2sr_put_error(sr,
				    NT_STATUS_INVALID_PARAMETER);
				goto cmd_done;
			}
			sr->smb_tid = sr->tid_tree->t_tid;
		} else {
			/*
			 * Lookup the TID
			 * [MS-SMB2] 3.3.5.2 Verifying the Tree Connect
			 */
			ASSERT(sr->tid_tree == NULL);
			sr->tid_tree = smb_session_lookup_tree(session,
			    sr->smb_tid);
			if (sr->tid_tree == NULL) {
				smb2sr_put_error(sr,
				    NT_STATUS_NETWORK_NAME_DELETED);
				goto cmd_done;
			}

			/*
			 * [MS-SMB2] 3.3.5.2.11 Verifying the Tree Connect
			 *
			 * If we support 3.x, RejectUnencryptedAccess is TRUE,
			 * if Tcon.EncryptData is TRUE or
			 * global EncryptData is TRUE and
			 * the message wasn't encrypted, or
			 * if Tcon.EncryptData is TRUE or
			 * global EncryptData is TRUE or
			 * the request was encrypted and
			 * the connection doesn't support encryption,
			 * return ACCESS_DENIED.
			 *
			 * If RejectUnencryptedAccess is TRUE, we force
			 * max_protocol to at least 3.0. Additionally,
			 * if the tree requires encryption, we don't care
			 * what we support, we still enforce encryption.
			 */
			if (sr->tid_tree->t_encrypt == SMB_CONFIG_REQUIRED &&
			    (!sr->encrypted ||
			    (session->srv_cap & SMB2_CAP_ENCRYPTION) == 0)) {
				smb2sr_put_error(sr,
				    NT_STATUS_ACCESS_DENIED);
				goto cmd_done;
			}
		}
		ASSERT(sr->tid_tree != NULL);

		/*
		 * Encrypt if:
		 * - The cmd is not TREE_CONNECT; AND
		 * - Tree.EncryptData is TRUE
		 *
		 * TREE_CONNECT suppresses TID, so that can't be the cmd here.
		 * NOTE: assumes we can't have a tree without a user
		 */
		if (sr->tid_tree->t_encrypt != SMB_CONFIG_DISABLED &&
		    sr->tform_ssn == NULL) {
			smb_user_hold_internal(sr->uid_user);
			sr->tform_ssn = sr->uid_user;
			sr->smb3_tform_ssnid = sr->smb2_ssnid;
		}
	}

	/*
	 * SMB2 signature verification, two parts:
	 * (a) Require SMB2_FLAGS_SIGNED (for most request types)
	 * (b) If SMB2_FLAGS_SIGNED is set, check the signature.
	 * [MS-SMB2] 3.3.5.2.4 Verifying the Signature
	 */

	/*
	 * No user session means no signature check.  That's OK,
	 * i.e. for commands marked SDDF_SUPPRESS_UID above.
	 * Note, this also means we won't sign the reply.
	 */
	if (sr->uid_user == NULL)
		sr->smb2_hdr_flags &= ~SMB2_FLAGS_SIGNED;

	/*
	 * The SDDF_SUPPRESS_UID dispatch is set for requests that
	 * don't need a UID (user).  These also don't require a
	 * signature check here.
	 *
	 * [MS-SMB2] 3.3.5.2.4 Verifying the Signature
	 *
	 * If the packet was successfully decrypted, the message
	 * signature has already been verified, so we can skip this.
	 */
	if ((sdd->sdt_flags & SDDF_SUPPRESS_UID) == 0 &&
	    !sr->encrypted && sr->uid_user != NULL &&
	    (sr->uid_user->u_sign_flags & SMB_SIGNING_CHECK) != 0) {
		/*
		 * This request type should be signed, and
		 * we're configured to require signatures.
		 */
		if ((sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED) == 0) {
			smb2sr_put_error(sr, NT_STATUS_ACCESS_DENIED);
			goto cmd_done;
		}
		rc = smb2_sign_check_request(sr);
		if (rc != 0) {
			DTRACE_PROBE1(smb2__sign__check, smb_request_t, sr);
			smb2sr_put_error(sr, NT_STATUS_ACCESS_DENIED);
			goto cmd_done;
		}
	}

	/*
	 * Now that the signing check is done with smb_data,
	 * advance past the SMB2 header we decoded earlier.
	 * This leaves sr->smb_data correctly positioned
	 * for command-specific decoding in the dispatch
	 * function called next.
	 */
	sr->smb_data.chain_offset = sr->smb2_cmd_hdr + SMB2_HDR_SIZE;

	/*
	 * SMB2 credits determine how many simultaneous commands the
	 * client may issue, and bounds the range of message IDs those
	 * commands may use.  With multi-credit support, commands may
	 * use ranges of message IDs, where the credits used by each
	 * command are proportional to their data transfer size.
	 *
	 * Every command may request an increase or decrease of
	 * the currently granted credits, based on the difference
	 * between the credit request and the credit charge.
	 * [MS-SMB2] 3.3.1.2 Algorithm for the Granting of Credits
	 *
	 * Most commands have credit_request=1, credit_charge=1,
	 * which keeps the credit grant unchanged.
	 *
	 * All we're really doing here (for now) is reducing the
	 * credit_response if the client requests a credit increase
	 * that would take their credit over the maximum, and
	 * limiting the decrease so they don't run out of credits.
	 *
	 * Later, this could do something dynamic based on load.
	 *
	 * One other non-obvious bit about credits: We keep the
	 * session s_max_credits low until the 1st authentication,
	 * at which point we'll set the normal maximum_credits.
	 * Some clients ask for more credits with session setup,
	 * and we need to handle that requested increase _after_
	 * the command-specific handler returns so it won't be
	 * restricted to the lower (pre-auth) limit.
	 */
	sr->smb2_credit_response = sr->smb2_credit_request;
	if (sr->smb2_credit_request < sr->smb2_credit_charge) {
		uint16_t cur, d;

		mutex_enter(&session->s_credits_mutex);
		cur = session->s_cur_credits;

		/* Handle credit decrease. */
		d = sr->smb2_credit_charge - sr->smb2_credit_request;
		cur -= d;
		if (cur & 0x8000) {
			/*
			 * underflow (bad credit charge or request)
			 * leave credits unchanged (response=charge)
			 */
			cur = session->s_cur_credits;
			sr->smb2_credit_response = sr->smb2_credit_charge;
			DTRACE_PROBE1(smb2__credit__neg, smb_request_t, sr);
		}

		/*
		 * The server MUST ensure that the number of credits
		 * held by the client is never reduced to zero.
		 * [MS-SMB2] 3.3.1.2
		 */
		if (cur == 0) {
			cur = 1;
			sr->smb2_credit_response += 1;
			DTRACE_PROBE1(smb2__credit__min, smb_request_t, sr);
		}

		DTRACE_PROBE3(smb2__credit__decrease,
		    smb_request_t, sr, int, (int)cur,
		    int, (int)session->s_cur_credits);

		session->s_cur_credits = cur;
		mutex_exit(&session->s_credits_mutex);
	}

	/*
	 * The real work: call the SMB2 command handler
	 * (except for "sticky" smb2_status - see above)
	 */
	sr->sr_time_start = gethrtime();
	rc = SDRC_SUCCESS;
	if (sr->smb2_status == 0) {
		/* NB: not using pre_op */
		rc = (*sdd->sdt_function)(sr);
		/* NB: not using post_op */
	} else {
		smb2sr_put_error(sr, sr->smb2_status);
	}

	MBC_FLUSH(&sr->raw_data);

	/*
	 * Second half of SMB2 credit handling (increases)
	 */
	if (sr->smb2_credit_request > sr->smb2_credit_charge) {
		uint16_t cur, d;

		mutex_enter(&session->s_credits_mutex);
		cur = session->s_cur_credits;

		/* Handle credit increase. */
		d = sr->smb2_credit_request - sr->smb2_credit_charge;
		cur += d;

		/*
		 * If new credits would be above max,
		 * reduce the credit grant.
		 */
		if (cur > session->s_max_credits) {
			d = cur - session->s_max_credits;
			cur = session->s_max_credits;
			sr->smb2_credit_response -= d;
			DTRACE_PROBE1(smb2__credit__max, smb_request_t, sr);
		}

		DTRACE_PROBE3(smb2__credit__increase,
		    smb_request_t, sr, int, (int)cur,
		    int, (int)session->s_cur_credits);

		session->s_cur_credits = cur;
		mutex_exit(&session->s_credits_mutex);
	}

cmd_done:
	/*
	 * Pad the reply to align(8) if there will be another.
	 */
	if (sr->smb2_next_command != 0 &&
	    (sr->reply.chain_offset & 7) != 0) {
		int padsz = 8 - (sr->reply.chain_offset & 7);
		(void) smb_mbc_encodef(&sr->reply, "#.", padsz);
	}

	/*
	 * Record some statistics:  latency, rx bytes, tx bytes
	 * per:  server, session & kshare.
	 */
	{
		hrtime_t	dt;
		int64_t		rxb;
		int64_t		txb;
		smb_disp_stats_t	*client_sds;
		smb_disp_stats_t	*share_sds;
		int			cmd_type;

		if (sr->smb2_cmd_code == SMB2_READ) {
			cmd_type = SMBSRV_CLSH_READ;
		} else if (sr->smb2_cmd_code == SMB2_WRITE) {
			cmd_type = SMBSRV_CLSH_WRITE;
		} else
			cmd_type = SMBSRV_CLSH_OTHER;

		dt = gethrtime() - sr->sr_time_start;
		rxb = (int64_t)(sr->command.chain_offset - sr->smb2_cmd_hdr);
		txb = (int64_t)(sr->reply.chain_offset - sr->smb2_reply_hdr);

		smb_latency_add_sample(&sds->sdt_lat, dt);
		atomic_add_64(&sds->sdt_rxb, rxb);
		atomic_add_64(&sds->sdt_txb, txb);

		client_sds = &session->s_stats[cmd_type];
		smb_latency_add_sample(&client_sds->sdt_lat, dt);
		atomic_add_64(&client_sds->sdt_rxb, rxb);
		atomic_add_64(&client_sds->sdt_txb, txb);

		if ((sr->tid_tree != NULL) &&
		    (sr->tid_tree->t_kshare != NULL)) {
			share_sds =
			    &sr->tid_tree->t_kshare->shr_stats[cmd_type];
			smb_latency_add_sample(&share_sds->sdt_lat, dt);
			atomic_add_64(&share_sds->sdt_rxb, rxb);
			atomic_add_64(&share_sds->sdt_txb, txb);
		}
	}

	/*
	 * Mark this command "done" in the scoreboard, but keep track
	 * of whether there's async work still to happen (for debug)
	 */
	smb2_scoreboard_cmd_done(sr, (sr->sr_async_req != NULL));

	switch (rc) {
	case SDRC_SUCCESS:
		break;
	default:
		/*
		 * SMB2 does not use the other dispatch return codes.
		 * If we see something else, log an event so we'll
		 * know something is returning bogus status codes.
		 * If you see these in the log, use dtrace to find
		 * the code returning something else.
		 */
#ifdef	DEBUG
		cmn_err(CE_NOTE, "handler for %u returned 0x%x",
		    sr->smb2_cmd_code, rc);
#endif
		sr->smb2_status = NT_STATUS_INTERNAL_ERROR;
		break;
	case SDRC_ERROR:
		/*
		 * Many command handlers return SDRC_ERROR for any
		 * problems decoding the request, and don't bother
		 * setting smb2_status.  For those cases, the best
		 * status return would be "invalid parameter".
		 */
		if (sr->smb2_status == 0)
			sr->smb2_status = NT_STATUS_INVALID_PARAMETER;
		break;
	case SDRC_DROP_VC:
		disconnect = B_TRUE;
		goto cleanup;

	case SDRC_NO_REPLY:
		/* will free sr */
		goto cleanup;
	}

	/*
	 * If there's a next command, figure out where it starts,
	 * and fill in the next command offset for the reply.
	 * Note: We sanity checked smb2_next_command above
	 * (the offset to the next command).  Similarly set
	 * smb2_next_reply as the offset to the next reply.
	 */
	if (sr->smb2_next_command != 0) {
		sr->command.chain_offset =
		    sr->smb2_cmd_hdr + sr->smb2_next_command;
		sr->smb2_next_reply =
		    sr->reply.chain_offset - sr->smb2_reply_hdr;
	} else {
		sr->smb2_next_reply = 0;
	}

	/*
	 * Overwrite the SMB2 header for the response of
	 * this command (possibly part of a compound).
	 * encode_header adds: SMB2_FLAGS_SERVER_TO_REDIR
	 */
	(void) smb2_encode_header(sr, B_TRUE);

	/* Don't sign if we're going to encrypt */
	if (sr->tform_ssn == NULL &&
	    (sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED) != 0)
		smb2_sign_reply(sr);

	if (sr->smb2_next_command != 0)
		goto cmd_start;

	/*
	 * We've done all the commands in this compound.
	 * Encrypt if needed, then send it out.
	 */
	smb2_send_reply(sr);

cleanup:
	if (disconnect)
		smb2_network_disconnect(session);

	/*
	 * If any of the requests "went async", process those now.
	 * The async. function "keeps" this sr, changing its state
	 * to completed and calling smb_request_free().
	 */
	if (sr->sr_async_req != NULL) {
		smb2sr_do_async(sr);
		return;
	}

	mutex_enter(&sr->sr_mutex);
	sr->sr_state = SMB_REQ_STATE_COMPLETED;
	mutex_exit(&sr->sr_mutex);

	smb_request_free(sr);
}

/*
 * Dispatch an async request using saved information.
 * See smb2sr_save_async and [MS-SMB2] 3.3.4.2
 *
 * This is sort of a "lite" version of smb2sr_work.  Initialize the
 * command and reply areas as they were when the command-speicific
 * handler started (in case it needs to decode anything again).
 * Call the async function, which builds the command-specific part
 * of the response.  Finally, send the response and free the sr.
 */
void
smb2sr_do_async(smb_request_t *sr)
{
	const smb_disp_entry_t	*sdd;
	smb2_async_req_t	*ar;
	smb_sdrc_t		(*ar_func)(smb_request_t *);
	int sdrc;

	/*
	 * Restore what smb2_decode_header found.
	 * (In lieu of decoding it again.)
	 */
	ar = sr->sr_async_req;
	sr->smb2_cmd_hdr   = ar->ar_cmd_hdr;
	sr->smb2_cmd_code  = ar->ar_cmd_code;
	sr->smb2_hdr_flags = ar->ar_hdr_flags;
	sr->smb2_async_id  = ar->ar_messageid ^ (1ULL << 62);
	sr->smb2_messageid = ar->ar_messageid;
	sr->smb_pid = ar->ar_pid;
	sr->smb_tid = ar->ar_tid;
	sr->smb2_ssnid = ar->ar_ssnid;
	sr->smb2_status = 0;

	/*
	 * Async requests don't grant credits, because any credits
	 * should have gone out with the interim reply.
	 * An async reply goes alone (no next reply).
	 */
	sr->smb2_credit_response = 0;
	sr->smb2_next_reply = 0;

	/*
	 * Setup input mbuf_chain
	 */
	ASSERT(ar->ar_cmd_len >= SMB2_HDR_SIZE);
	(void) MBC_SHADOW_CHAIN(&sr->smb_data, &sr->command,
	    sr->smb2_cmd_hdr + SMB2_HDR_SIZE,
	    ar->ar_cmd_len - SMB2_HDR_SIZE);

	/*
	 * Done with sr_async_req
	 */
	ar_func = ar->ar_func;
	kmem_free(ar, sizeof (*ar));
	sr->sr_async_req = ar = NULL;

	/*
	 * Setup output mbuf_chain
	 */
	MBC_FLUSH(&sr->reply);
	sr->smb2_reply_hdr = sr->reply.chain_offset;
	(void) smb2_encode_header(sr, B_FALSE);

	VERIFY3U(sr->smb2_cmd_code, <, SMB2_INVALID_CMD);
	sdd = &smb2_disp_table[sr->smb2_cmd_code];

	/*
	 * Keep the UID, TID, ofile we have.
	 */
	if ((sdd->sdt_flags & SDDF_SUPPRESS_UID) == 0 &&
	    sr->uid_user == NULL) {
		smb2sr_put_error(sr, NT_STATUS_USER_SESSION_DELETED);
		goto cmd_done;
	}
	if ((sdd->sdt_flags & SDDF_SUPPRESS_TID) == 0 &&
	    sr->tid_tree == NULL) {
		smb2sr_put_error(sr, NT_STATUS_NETWORK_NAME_DELETED);
		goto cmd_done;
	}

	/*
	 * Signature already verified
	 * Credits handled...
	 *
	 * Just call the async handler function.
	 */
	sdrc = ar_func(sr);
	switch (sdrc) {
	case SDRC_SUCCESS:
		break;
	case SDRC_ERROR:
		if (sr->smb2_status == 0)
			sr->smb2_status = NT_STATUS_INTERNAL_ERROR;
		break;
	case SDRC_SR_KEPT:
		/* This SR will be completed later. */
		return;
	}

cmd_done:
	smb2sr_finish_async(sr);
}

void
smb2sr_finish_async(smb_request_t *sr)
{
	smb_disp_stats_t	*sds;

	/*
	 * Record some statistics: (just tx bytes here)
	 */
	sds = &sr->session->s_server->sv_disp_stats2[sr->smb2_cmd_code];
	atomic_add_64(&sds->sdt_txb, (int64_t)(sr->reply.chain_offset));

	/*
	 * Put (overwrite) the final SMB2 header.
	 * The call adds: SMB2_FLAGS_SERVER_TO_REDIR
	 */
	(void) smb2_encode_header(sr, B_TRUE);

	if (sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED)
		smb2_sign_reply(sr);

	smb2_send_reply(sr);

	/*
	 * Done.  Unlink and free.
	 */

	mutex_enter(&sr->sr_mutex);
	sr->sr_state = SMB_REQ_STATE_COMPLETED;
	mutex_exit(&sr->sr_mutex);

	smb_request_free(sr);
}

/*
 * In preparation for sending an "interim response", save
 * all the state we'll need to run an async command later,
 * and assign an "async id" for this (now async) command.
 * See [MS-SMB2] 3.3.4.2
 *
 * If more than one request in a compound request tries to
 * "go async", we can "say no".  See [MS-SMB2] 3.3.4.2
 *	If an operation would require asynchronous processing
 *	but resources are constrained, the server MAY choose to
 *	fail that operation with STATUS_INSUFFICIENT_RESOURCES.
 *
 * For simplicity, we further restrict the cases where we're
 * willing to "go async", and only allow the last command in a
 * compound to "go async".  It happens that this is the only
 * case where we're actually asked to go async anyway. This
 * simplification also means there can be at most one command
 * in a compound that "goes async" (the last one).
 *
 * If we agree to "go async", this should return STATUS_PENDING.
 * Otherwise return STATUS_INSUFFICIENT_RESOURCES for this and
 * all requests following this request.  (See the comments re.
 * "sticky" smb2_status values in smb2sr_work).
 *
 * Note: the Async ID we assign here is arbitrary, and need only
 * be unique among pending async responses on this connection, so
 * this just uses an object address as the Async ID.
 *
 * Also, the assigned worker is the ONLY thread using this
 * async request object (sr_async_req) so no locking.
 */
uint32_t
smb2sr_go_async(smb_request_t *sr,
    smb_sdrc_t (*async_func)(smb_request_t *))
{
	smb2_async_req_t *ar;

	if (sr->smb2_next_command != 0)
		return (NT_STATUS_INSUFFICIENT_RESOURCES);

	ASSERT(sr->sr_async_req == NULL);
	ar = kmem_zalloc(sizeof (*ar), KM_SLEEP);

	/*
	 * Place an interim response in the compound reply.
	 *
	 * Turn on the "async" flag for both the (synchronous)
	 * interim response and the (later) async response,
	 * by storing that in flags before coping into ar.
	 */
	sr->smb2_hdr_flags |= SMB2_FLAGS_ASYNC_COMMAND;
	sr->smb2_async_id = sr->smb2_messageid ^ (1ULL << 62);

	ar->ar_func = async_func;
	ar->ar_cmd_hdr = sr->smb2_cmd_hdr;
	ar->ar_cmd_len = sr->smb_data.max_bytes - sr->smb2_cmd_hdr;

	ar->ar_cmd_code = sr->smb2_cmd_code;
	ar->ar_hdr_flags = sr->smb2_hdr_flags;
	ar->ar_messageid = sr->smb2_messageid;
	ar->ar_pid = sr->smb_pid;
	ar->ar_tid = sr->smb_tid;
	ar->ar_ssnid = sr->smb2_ssnid;

	sr->sr_async_req = ar;

	/* Interim responses are NOT signed. */
	sr->smb2_hdr_flags &= ~SMB2_FLAGS_SIGNED;

	return (NT_STATUS_PENDING);
}

int
smb3_decode_tform_header(smb_request_t *sr)
{
	uint16_t flags;
	int rc;
	uint32_t protocolid;

	rc = smb_mbc_decodef(
	    &sr->command, "l16c16cl..wq",
	    &protocolid,	/*  l  */
	    sr->smb2_sig,	/* 16c */
	    sr->nonce,	/* 16c */
	    &sr->msgsize,	/* l */
	    /* reserved	  .. */
	    &flags,		/* w */
	    &sr->smb3_tform_ssnid); /* q */
	if (rc)
		return (rc);

	ASSERT3U(protocolid, ==, SMB3_ENCRYPTED_MAGIC);

	if (flags != 1) {
#ifdef DEBUG
		cmn_err(CE_NOTE, "flags field not 1: %x", flags);
#endif
		return (-1);
	}

	/*
	 * MsgSize is the amount of data the client tell us to decrypt.
	 * Make sure this value is not too big and not too small.
	 */
	if (sr->msgsize < SMB2_HDR_SIZE ||
	    sr->msgsize > sr->session->cmd_max_bytes ||
	    sr->msgsize > sr->command.max_bytes - SMB3_TFORM_HDR_SIZE)
		return (-1);

	return (rc);
}

int
smb3_encode_tform_header(smb_request_t *sr, struct mbuf_chain *mbc)
{
	int rc;

	/* Signature and Nonce are added in smb3_encrypt_sr */
	rc = smb_mbc_encodef(
	    mbc, "l32.lwwq",
	    SMB3_ENCRYPTED_MAGIC, /* l */
	    /* signature(16), nonce(16) 32. */
	    sr->msgsize,	/* l */
	    0, /* reserved	   w */
	    1, /* flags		   w */
	    sr->smb3_tform_ssnid); /* q */

	return (rc);
}

int
smb2_decode_header(smb_request_t *sr)
{
	uint64_t ssnid;
	uint32_t pid, tid;
	uint16_t hdr_len;
	int rc;

	rc = smb_mbc_decodef(
	    &sr->command, "Nwww..wwllqllq16c",
	    &hdr_len,			/* w */
	    &sr->smb2_credit_charge,	/* w */
	    &sr->smb2_chan_seq,		/* w */
	    /* reserved			  .. */
	    &sr->smb2_cmd_code,		/* w */
	    &sr->smb2_credit_request,	/* w */
	    &sr->smb2_hdr_flags,	/* l */
	    &sr->smb2_next_command,	/* l */
	    &sr->smb2_messageid,	/* q */
	    &pid,			/* l */
	    &tid,			/* l */
	    &ssnid,			/* q */
	    sr->smb2_sig);		/* 16c */
	if (rc)
		return (rc);

	if (hdr_len != SMB2_HDR_SIZE)
		return (-1);

	sr->smb2_ssnid = ssnid;

	if (sr->smb2_hdr_flags & SMB2_FLAGS_ASYNC_COMMAND) {
		sr->smb2_async_id = pid |
		    ((uint64_t)tid) << 32;
	} else {
		sr->smb_pid = pid;
		sr->smb_tid = (uint16_t)tid; /* XXX wide TIDs */
	}

	return (rc);
}

int
smb2_encode_header(smb_request_t *sr, boolean_t overwrite)
{
	uint64_t pid_tid_aid; /* pid+tid, or async id */
	uint32_t reply_hdr_flags;
	int rc;

	if (sr->smb2_hdr_flags & SMB2_FLAGS_ASYNC_COMMAND) {
		pid_tid_aid = sr->smb2_async_id;
	} else {
		pid_tid_aid = sr->smb_pid |
		    ((uint64_t)sr->smb_tid) << 32;
	}
	reply_hdr_flags = sr->smb2_hdr_flags | SMB2_FLAGS_SERVER_TO_REDIR;

	if (overwrite) {
		rc = smb_mbc_poke(&sr->reply,
		    sr->smb2_reply_hdr,
		    "Nwwlwwllqqq16c",
		    SMB2_HDR_SIZE,		/* w */
		    sr->smb2_credit_charge,	/* w */
		    sr->smb2_status,		/* l */
		    sr->smb2_cmd_code,		/* w */
		    sr->smb2_credit_response,	/* w */
		    reply_hdr_flags,		/* l */
		    sr->smb2_next_reply,	/* l */
		    sr->smb2_messageid,		/* q */
		    pid_tid_aid,		/* q */
		    sr->smb2_ssnid,		/* q */
		    sr->smb2_sig);		/* 16c */
	} else {
		rc = smb_mbc_encodef(&sr->reply,
		    "Nwwlwwllqqq16c",
		    SMB2_HDR_SIZE,		/* w */
		    sr->smb2_credit_charge,	/* w */
		    sr->smb2_status,		/* l */
		    sr->smb2_cmd_code,		/* w */
		    sr->smb2_credit_response,	/* w */
		    reply_hdr_flags,		/* l */
		    sr->smb2_next_reply,	/* l */
		    sr->smb2_messageid,		/* q */
		    pid_tid_aid,		/* q */
		    sr->smb2_ssnid,		/* q */
		    sr->smb2_sig);		/* 16c */
	}

	return (rc);
}

void
smb2_send_reply(smb_request_t *sr)
{
	struct mbuf_chain enc_reply;
	smb_session_t *session = sr->session;
	void *tmpbuf;
	size_t buflen;
	struct mbuf_chain tmp;

	/*
	 * [MS-SMB2] 3.3.4.1.4 Encrypting the Message
	 *
	 * When the connection supports encryption and the dialect
	 * is 3.x, encrypt if:
	 * - The request was encrypted OR
	 * - The cmd is not SESSION_SETUP or NEGOTIATE AND
	 * -- Session.EncryptData is TRUE OR
	 * -- The cmd is not TREE_CONNECT AND
	 * --- Tree.EncryptData is TRUE
	 *
	 * This boils down to sr->tform_ssn != NULL, and the rest
	 * is enforced when tform_ssn is set.
	 */

	if ((session->capabilities & SMB2_CAP_ENCRYPTION) == 0 ||
	    sr->tform_ssn == NULL) {
		if (smb_session_send(sr->session, 0, &sr->reply) == 0)
			sr->reply.chain = 0;
		return;
	}

	sr->msgsize = sr->reply.chain_offset;
	(void) MBC_SHADOW_CHAIN(&tmp, &sr->reply,
	    0, sr->msgsize);

	buflen = SMB3_TFORM_HDR_SIZE + sr->msgsize;

	/* taken from smb_request_init_command_mbuf */
	tmpbuf = kmem_alloc(buflen, KM_SLEEP);
	MBC_ATTACH_BUF(&enc_reply, tmpbuf, buflen);
	enc_reply.flags = 0;
	enc_reply.shadow_of = NULL;

	if (smb3_encode_tform_header(sr, &enc_reply) != 0) {
		cmn_err(CE_WARN, "couldn't encode transform header");
		goto errout;
	}
	if (smb3_encrypt_sr(sr, &tmp, &enc_reply) != 0) {
		cmn_err(CE_WARN, "smb3 encryption failed");
		goto errout;
	}

	if (smb_session_send(sr->session, 0, &enc_reply) == 0)
		enc_reply.chain = 0;
	return;

errout:
	kmem_free(tmpbuf, buflen);
	smb2_network_disconnect(sr->session);
}

/*
 * This wrapper function exists to help catch calls to smbsr_status()
 * (which is SMB1-specific) in common code.  See smbsr_status().
 * If the log message below is seen, put a dtrace probe on this
 * function with a stack() action to see who is calling the SMB1
 * "put error" from common code, and fix it.
 */
void
smbsr_status_smb2(smb_request_t *sr, DWORD status)
{
	const char *name;

	if (sr->smb2_cmd_code < SMB2__NCMDS)
		name = smb2_disp_table[sr->smb2_cmd_code].sdt_name;
	else
		name = "<unknown>";
#ifdef	DEBUG
	cmn_err(CE_NOTE, "smbsr_status called for %s", name);
#endif

	smb2sr_put_error_data(sr, status, NULL);
}

void
smb2sr_put_errno(struct smb_request *sr, int errnum)
{
	uint32_t status = smb_errno2status(errnum);
	smb2sr_put_error_data(sr, status, NULL);
}

void
smb2sr_put_error(smb_request_t *sr, uint32_t status)
{
	smb2sr_put_error_data(sr, status, NULL);
}

/*
 * Build an SMB2 error response.  [MS-SMB2] 2.2.2
 */
void
smb2sr_put_error_data(smb_request_t *sr, uint32_t status, mbuf_chain_t *mbc)
{
	DWORD len;

	/*
	 * The common dispatch code writes this when it
	 * updates the SMB2 header before sending.
	 */
	sr->smb2_status = status;

	/* Rewind to the end of the SMB header. */
	sr->reply.chain_offset = sr->smb2_reply_hdr + SMB2_HDR_SIZE;

	/*
	 * NB: Must provide at least one byte of error data,
	 * per [MS-SMB2] 2.2.2
	 */
	if (mbc != NULL && (len = MBC_LENGTH(mbc)) != 0) {
		(void) smb_mbc_encodef(
		    &sr->reply,
		    "wwlC",
		    9,	/* StructSize */	/* w */
		    0,	/* reserved */		/* w */
		    len,			/* l */
		    mbc);			/* C */
	} else {
		(void) smb_mbc_encodef(
		    &sr->reply,
		    "wwl.",
		    9,	/* StructSize */	/* w */
		    0,	/* reserved */		/* w */
		    0);				/* l. */
	}
}

/*
 * smb2sr_lookup_fid
 *
 * Setup sr->fid_ofile, either inherited from a related command,
 * or obtained via FID lookup.  Similar inheritance logic as in
 * smb2sr_work.
 */
uint32_t
smb2sr_lookup_fid(smb_request_t *sr, smb2fid_t *fid)
{
	boolean_t related = sr->smb2_hdr_flags &
	    SMB2_FLAGS_RELATED_OPERATIONS;

	if (related) {
		if (sr->fid_ofile == NULL)
			return (NT_STATUS_INVALID_PARAMETER);
		sr->smb_fid = sr->fid_ofile->f_fid;
		return (0);
	}

	/*
	 * If we could be sure this is called only once per cmd,
	 * we could simply ASSERT(sr->fid_ofile == NULL) here.
	 * However, there are cases where it can be called again
	 * handling the same command, so let's tolerate that.
	 */
	if (sr->fid_ofile == NULL) {
		sr->smb_fid = (uint16_t)fid->temporal;
		sr->fid_ofile = smb_ofile_lookup_by_fid(sr, sr->smb_fid);
	}
	if (sr->fid_ofile == NULL ||
	    sr->fid_ofile->f_persistid != fid->persistent)
		return (NT_STATUS_FILE_CLOSED);

	return (0);
}

/*
 * smb2_dispatch_stats_init
 *
 * Initializes dispatch statistics for SMB2.
 * See also smb_dispatch_stats_init(), which fills in
 * the lower part of the statistics array, from zero
 * through SMB_COM_NUM;
 */
void
smb2_dispatch_stats_init(smb_server_t *sv)
{
	smb_disp_stats_t *sds = sv->sv_disp_stats2;
	smb_kstat_req_t *ksr;
	int		i;

	ksr = ((smbsrv_kstats_t *)sv->sv_ksp->ks_data)->ks_reqs2;

	for (i = 0; i < SMB2__NCMDS; i++, ksr++) {
		smb_latency_init(&sds[i].sdt_lat);
		(void) strlcpy(ksr->kr_name, smb2_disp_table[i].sdt_name,
		    sizeof (ksr->kr_name));
	}
}

/*
 * smb2_dispatch_stats_fini
 *
 * Frees and destroyes the resources used for statistics.
 */
void
smb2_dispatch_stats_fini(smb_server_t *sv)
{
	smb_disp_stats_t *sds = sv->sv_disp_stats2;
	int	i;

	for (i = 0; i < SMB2__NCMDS; i++)
		smb_latency_destroy(&sds[i].sdt_lat);
}

void
smb2_dispatch_stats_update(smb_server_t *sv,
    smb_kstat_req_t *ksr, int first, int nreq)
{
	smb_disp_stats_t *sds = sv->sv_disp_stats2;
	int	i;
	int	last;

	last = first + nreq - 1;

	if ((first < SMB2__NCMDS) && (last < SMB2__NCMDS))  {
		for (i = first; i <= last; i++, ksr++) {
			ksr->kr_rxb = sds[i].sdt_rxb;
			ksr->kr_txb = sds[i].sdt_txb;
			mutex_enter(&sds[i].sdt_lat.ly_mutex);
			ksr->kr_nreq = sds[i].sdt_lat.ly_a_nreq;
			ksr->kr_sum = sds[i].sdt_lat.ly_a_sum;
			ksr->kr_a_mean = sds[i].sdt_lat.ly_a_mean;
			ksr->kr_a_stddev =
			    sds[i].sdt_lat.ly_a_stddev;
			ksr->kr_d_mean = sds[i].sdt_lat.ly_d_mean;
			ksr->kr_d_stddev =
			    sds[i].sdt_lat.ly_d_stddev;
			sds[i].sdt_lat.ly_d_mean = 0;
			sds[i].sdt_lat.ly_d_nreq = 0;
			sds[i].sdt_lat.ly_d_stddev = 0;
			sds[i].sdt_lat.ly_d_sum = 0;
			mutex_exit(&sds[i].sdt_lat.ly_mutex);
		}
	}
}

void
smb2_network_disconnect(smb_session_t *session)
{
	smb_rwx_rwenter(&session->s_lock, RW_WRITER);
	switch (session->s_state) {
	case SMB_SESSION_STATE_DISCONNECTED:
	case SMB_SESSION_STATE_TERMINATED:
		break;
	default:
		smb_soshutdown(session->sock);
		session->s_state = SMB_SESSION_STATE_DISCONNECTED;
		break;
	}
	smb_rwx_rwexit(&session->s_lock);
}
