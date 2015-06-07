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
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */


#include <smbsrv/smb2_kproto.h>
#include <smbsrv/smb_kstat.h>
#include <smbsrv/smb2.h>

#define	INHERIT_ID	((uint16_t)-1)

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
	uint16_t		ar_cmd_code;
	uint16_t		ar_tid;
	uint32_t		ar_pid;
	uint32_t		ar_hdr_flags;
	uint64_t		ar_messageid;
} smb2_async_req_t;

static int smb2sr_dispatch(smb_request_t *,
	smb_sdrc_t (*)(smb_request_t *));

void smb2sr_do_async(smb_request_t *);
smb_sdrc_t smb2_invalid_cmd(smb_request_t *);

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

	/*
	 * Note: Cancel gets the "invalid command" handler because
	 * that's always handled directly in the reader.  We should
	 * never get to the function using this table, but note:
	 * We CAN get here if a nasty client adds cancel to some
	 * compound message, which is a protocol violation.
	 */
	{  "smb2_cancel", NULL,
	    smb2_invalid_cmd, NULL, 0, 0 },

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
	uint32_t magic;
	uint16_t command;
	int rc;

	magic = LE_IN32(sr->sr_request_buf);
	if (magic != SMB2_PROTOCOL_MAGIC) {
		smb_request_free(sr);
		/* will drop the connection */
		return (EPROTO);
	}

	/*
	 * Execute Cancel requests immediately, (here in the
	 * reader thread) so they won't wait for any other
	 * commands we might already have in the task queue.
	 * Cancel also skips signature verification and
	 * does not consume a sequence number.
	 * [MS-SMB2] 3.2.4.24 Cancellation...
	 */
	command = LE_IN16((uint8_t *)sr->sr_request_buf + 12);
	if (command == SMB2_CANCEL) {
		rc = smb2sr_newrq_cancel(sr);
		smb_request_free(sr);
		return (rc);
	}

	/*
	 * Submit the request to the task queue, which calls
	 * smb2_dispatch_request when the workload permits.
	 */
	sr->sr_time_submitted = gethrtime();
	sr->sr_state = SMB_REQ_STATE_SUBMITTED;
	sr->work_func = smb2sr_work;
	smb_srqueue_waitq_enter(sr->session->s_srqueue);
	(void) taskq_dispatch(sr->session->s_server->sv_worker_pool,
	    smb_session_worker, sr, TQ_SLEEP);

	return (0);

}

/*
 * smb2sr_work
 *
 * This function processes each SMB command in the current request
 * (which may be a compound request) building a reply containing
 * SMB reply messages, one-to-one with the SMB commands.  Some SMB
 * commands (change notify, blocking pipe read) may require both an
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
 * This function must always free the smb request.
 */
void
smb2sr_work(struct smb_request *sr)
{
	smb_session_t		*session;
	uint32_t		msg_len;
	int			rc;
	boolean_t		disconnect = B_FALSE;

	session = sr->session;

	ASSERT(sr->tid_tree == 0);
	ASSERT(sr->uid_user == 0);
	ASSERT(sr->fid_ofile == 0);
	sr->smb_fid = (uint16_t)-1;

	/* temporary until we identify a user */
	sr->user_cr = zone_kcred();

	mutex_enter(&sr->sr_mutex);
	switch (sr->sr_state) {
	case SMB_REQ_STATE_SUBMITTED:
	case SMB_REQ_STATE_CLEANED_UP:
		sr->sr_state = SMB_REQ_STATE_ACTIVE;
		break;
	default:
		ASSERT(0);
		/* FALLTHROUGH */
	case SMB_REQ_STATE_CANCELED:
		goto complete_unlock_free;
	}
	mutex_exit(&sr->sr_mutex);

cmd_start:
	/*
	 * Reserve space for the reply header, and save the offset.
	 * The reply header will be overwritten later.  If we have
	 * already exhausted the output space, then this client is
	 * trying something funny.  Log it and kill 'em.
	 */
	sr->smb2_reply_hdr = sr->reply.chain_offset;
	rc = smb_mbc_encodef(&sr->reply, "#.", SMB2_HDR_SIZE);
	if (rc != 0) {
		cmn_err(CE_WARN, "clnt %s excessive reply",
		    session->ip_addr_str);
		disconnect = B_TRUE;
		goto cleanup;
	}

	/*
	 * Decode the request header
	 *
	 * Most problems with decoding will result in the error
	 * STATUS_INVALID_PARAMETER.  If the decoding problem
	 * prevents continuing, we'll close the connection.
	 * [MS-SMB2] 3.3.5.2.6 Handling Incorrectly Formatted...
	 */
	sr->smb2_status = 0;
	sr->smb2_cmd_hdr = sr->command.chain_offset;
	if ((rc = smb2_decode_header(sr)) != 0) {
		cmn_err(CE_WARN, "clnt %s bad SMB2 header",
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
	 * or the end of the message.  The signing check in the
	 * dispatch function needs the entire SMB2 command. We'll
	 * advance chain_offset up to the end of the header before
	 * the command specific decoders.
	 */
	(void) MBC_SHADOW_CHAIN(&sr->smb_data, &sr->command,
	    sr->smb2_cmd_hdr, msg_len);

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
	 */
	if (sr->smb2_credit_charge == 0)
		sr->smb2_credit_charge = 1;
	sr->smb2_credit_response = sr->smb2_credit_request;
	if (sr->smb2_credit_request != sr->smb2_credit_charge) {
		uint16_t cur, d;

		mutex_enter(&session->s_credits_mutex);
		cur = session->s_cur_credits;

		/* Apply the credit charge & request. */
		cur -= sr->smb2_credit_charge;
		cur += sr->smb2_credit_request;
		if (cur & 0x8000) {
			/*
			 * underflow or overflow (bad charge/request)
			 * leave credits unchanged (response=charge)
			 */
			cur = session->s_cur_credits;
			sr->smb2_credit_response = sr->smb2_credit_charge;
			DTRACE_PROBE1(smb2__credit__bad, smb_request_t, sr);
		}

		/*
		 * If new credits would be below min,
		 * grant additional credits.
		 */
		if (cur < SMB_PI_MIN_CREDITS) {
			d = SMB_PI_MIN_CREDITS - cur;
			cur = SMB_PI_MIN_CREDITS;
			sr->smb2_credit_response += d;
			DTRACE_PROBE1(smb2__credit__min, smb_request_t, sr);
		}

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

		session->s_cur_credits = cur;
		mutex_exit(&session->s_credits_mutex);
	}

	/*
	 * Common dispatch (for sync & async)
	 */
	rc = smb2sr_dispatch(sr, NULL);
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
		cmn_err(CE_NOTE, "smb2sr_dispatch -> 0x%x", rc);
#endif
		/* FALLTHROUGH */
	case SDRC_ERROR:
		if (sr->smb2_status == 0)
			sr->smb2_status = NT_STATUS_INTERNAL_ERROR;
		break;
	case SDRC_DROP_VC:
		disconnect = B_TRUE;
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
	 */
	sr->smb2_hdr_flags |= SMB2_FLAGS_SERVER_TO_REDIR;
	(void) smb2_encode_header(sr, B_TRUE);

	if (sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED)
		smb2_sign_reply(sr);

	if (sr->smb2_next_command != 0)
		goto cmd_start;

	/*
	 * We've done all the commands in this compound.
	 * Send it out.
	 */
	smb2_send_reply(sr);

	/*
	 * If any of the requests "went async", process those now.
	 */
	if (sr->sr_async_req != NULL) {
		smb2sr_do_async(sr);
	}

cleanup:
	if (disconnect) {
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


	mutex_enter(&sr->sr_mutex);
complete_unlock_free:
	sr->sr_state = SMB_REQ_STATE_COMPLETED;
	mutex_exit(&sr->sr_mutex);

	smb_request_free(sr);
}

/*
 * Dispatch an async request using saved information.
 * See smb2sr_save_async and [MS-SMB2] 3.3.4.2
 */
void
smb2sr_do_async(smb_request_t *sr)
{
	smb2_async_req_t *ar;
	int rc;

	/*
	 * Restore what smb2_decode_header found.
	 */
	ar = sr->sr_async_req;
	sr->smb2_cmd_hdr   = ar->ar_cmd_hdr;
	sr->smb2_cmd_code  = ar->ar_cmd_code;
	sr->smb2_hdr_flags = ar->ar_hdr_flags;
	sr->smb2_async_id  = (uintptr_t)ar;
	sr->smb2_messageid = ar->ar_messageid;
	sr->smb_pid = ar->ar_pid;
	sr->smb_tid = ar->ar_tid;
	sr->smb2_status = 0;

	/*
	 * Async requests don't grant credits, because any credits
	 * should have gone out with the interim reply.
	 */
	sr->smb2_credit_response = 0;

	/*
	 * Setup input mbuf_chain
	 */
	ASSERT(ar->ar_cmd_len >= SMB2_HDR_SIZE);
	(void) MBC_SHADOW_CHAIN(&sr->smb_data, &sr->command,
	    sr->smb2_cmd_hdr + SMB2_HDR_SIZE,
	    ar->ar_cmd_len - SMB2_HDR_SIZE);

	/*
	 * Setup output mbuf_chain
	 */
	MBC_FLUSH(&sr->reply);
	sr->smb2_reply_hdr = sr->reply.chain_offset;
	(void) smb_mbc_encodef(&sr->reply, "#.", SMB2_HDR_SIZE);

	/*
	 * Call the common dispatch code, but override the
	 * command handler function with the async handler
	 * (ar->ar_func) which will be used instead of the
	 * normal handler from the dispatch table.
	 * The SMB signature was already checked.
	 */
	rc = smb2sr_dispatch(sr, ar->ar_func);
	if (rc != 0 && sr->smb2_status == 0)
		sr->smb2_status = NT_STATUS_INTERNAL_ERROR;

	/*
	 * Overwrite the SMB2 header for the response of
	 * this command (possibly part of a compound).
	 */
	sr->smb2_hdr_flags |= SMB2_FLAGS_SERVER_TO_REDIR;
	sr->smb2_next_reply = 0;
	(void) smb2_encode_header(sr, B_TRUE);

	if (sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED)
		smb2_sign_reply(sr);

	/*
	 * An async reply goes alone (no compound).
	 */
	smb2_send_reply(sr);

	/*
	 * Done.  Unlink and free.
	 */
	sr->sr_async_req = NULL;
	kmem_free(ar, sizeof (*ar));
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
 * Therefore, if this is the first (only) request needing
 * async processing, this returns STATUS_PENDING. Otherwise
 * return STATUS_INSUFFICIENT_RESOURCES.
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

	if (sr->sr_async_req != NULL)
		return (NT_STATUS_INSUFFICIENT_RESOURCES);

	ar = kmem_zalloc(sizeof (*ar), KM_SLEEP);

	/*
	 * Place an interim response in the compound reply.
	 * The interim reply gets the async flag, as does
	 * the final reply (via the saved ar_hdr_flags).
	 */
	sr->smb2_hdr_flags |= SMB2_FLAGS_ASYNC_COMMAND;
	sr->smb2_async_id = (uintptr_t)ar;

	ar->ar_func = async_func;
	ar->ar_cmd_hdr = sr->smb2_cmd_hdr;
	ar->ar_cmd_len = sr->smb_data.max_bytes - sr->smb2_cmd_hdr;

	ar->ar_cmd_code = sr->smb2_cmd_code;
	ar->ar_hdr_flags = sr->smb2_hdr_flags;
	ar->ar_messageid = sr->smb2_messageid;
	ar->ar_pid = sr->smb_pid;
	ar->ar_tid = sr->smb_tid;

	sr->sr_async_req = ar;

	/* Interim responses are NOT signed. */
	sr->smb2_hdr_flags &= ~SMB2_FLAGS_SIGNED;

	return (NT_STATUS_PENDING);
}

/*
 * This is the common dispatch function for SMB2, used for both
 * synchronous and asynchronous requests.  In the async case,
 * this runs twice: once for the initial processing where the
 * initial handler returns NT_STATUS_PENDING, and then a second
 * time (with async_func != NULL) for the "real work".
 * Note the async_func == NULL for "normal" calls, and the
 * handler function is taken from the dispatch table.
 */
static int
smb2sr_dispatch(smb_request_t *sr,
	smb_sdrc_t	(*async_func)(smb_request_t *))
{
	const smb_disp_entry_t	*sdd;
	smb_disp_stats_t	*sds;
	smb_session_t		*session;
	smb_server_t		*server;
	boolean_t		related;
	int			rc = 0;

	session = sr->session;
	server = session->s_server;

	/*
	 * Validate the commmand code, get dispatch table entries.
	 * [MS-SMB2] 3.3.5.2.6 Handling Incorrectly Formatted...
	 *
	 * The last slot in the dispatch table is used to handle
	 * invalid commands.  Same for statistics.
	 */
	if (sr->smb2_cmd_code < SMB2_INVALID_CMD) {
		sdd = &smb2_disp_table[sr->smb2_cmd_code];
		sds = &server->sv_disp_stats2[sr->smb2_cmd_code];
	} else {
		sdd = &smb2_disp_table[SMB2_INVALID_CMD];
		sds = &server->sv_disp_stats2[SMB2_INVALID_CMD];
	}

	if (sr->smb2_hdr_flags & SMB2_FLAGS_SERVER_TO_REDIR) {
		smb2sr_put_error(sr, NT_STATUS_INVALID_PARAMETER);
		goto done;
	}

	/*
	 * If this command is NOT "related" to the previous,
	 * clear out the UID, TID, FID state that might be
	 * left over from the previous command.
	 *
	 * Also, if the command IS related, but is declining to
	 * inherit the previous UID or TID, then clear out the
	 * previous session or tree now.  This simplifies the
	 * inheritance logic below.  Similar logic for FIDs
	 * happens in smb2sr_lookup_fid()
	 */
	related = (sr->smb2_hdr_flags & SMB2_FLAGS_RELATED_OPERATIONS);
	if (!related &&
	    sr->fid_ofile != NULL) {
		smb_ofile_request_complete(sr->fid_ofile);
		smb_ofile_release(sr->fid_ofile);
		sr->fid_ofile = NULL;
	}
	if ((!related || sr->smb_tid != INHERIT_ID) &&
	    sr->tid_tree != NULL) {
		smb_tree_release(sr->tid_tree);
		sr->tid_tree = NULL;
	}
	if ((!related || sr->smb_uid != INHERIT_ID) &&
	    sr->uid_user != NULL) {
		smb_user_release(sr->uid_user);
		sr->uid_user = NULL;
	}

	/*
	 * Make sure we have a user and tree as needed
	 * according to the flags for the this command.
	 * In a compound, a "related" command may inherit
	 * the UID, TID, and FID from previous commands
	 * using the special INHERIT_ID (all ones).
	 */

	if ((sdd->sdt_flags & SDDF_SUPPRESS_UID) == 0) {
		/*
		 * This command requires a user session.
		 */
		if (related && sr->smb_uid == INHERIT_ID &&
		    sr->uid_user != NULL) {
			sr->smb_uid = sr->uid_user->u_uid;
		} else {
			ASSERT3P(sr->uid_user, ==, NULL);
			sr->uid_user = smb_session_lookup_uid(session,
			    sr->smb_uid);
		}
		if (sr->uid_user == NULL) {
			/* [MS-SMB2] 3.3.5.2.9 Verifying the Session */
			smb2sr_put_error(sr, NT_STATUS_USER_SESSION_DELETED);
			goto done;
		}
		sr->user_cr = smb_user_getcred(sr->uid_user);
	}

	if ((sdd->sdt_flags & SDDF_SUPPRESS_TID) == 0) {
		/*
		 * This command requires a tree connection.
		 */
		if (related && sr->smb_tid == INHERIT_ID &&
		    sr->tid_tree != NULL) {
			sr->smb_tid = sr->tid_tree->t_tid;
		} else {
			ASSERT3P(sr->tid_tree, ==, NULL);
			sr->tid_tree = smb_session_lookup_tree(session,
			    sr->smb_tid);
		}
		if (sr->tid_tree == NULL) {
			/* [MS-SMB2] 3.3.5.2.11 Verifying the Tree Connect */
			smb2sr_put_error(sr, NT_STATUS_NETWORK_NAME_DELETED);
			goto done;
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
	 * Note: If async_func != NULL, we're handling a command that
	 * went async. In that case, we've already checked the
	 * signature, so there's no need to check it again.
	 */
	if ((sdd->sdt_flags & SDDF_SUPPRESS_UID) == 0 &&
	    async_func == NULL && sr->uid_user != NULL &&
	    (sr->uid_user->u_sign_flags & SMB_SIGNING_CHECK) != 0) {
		/*
		 * This request type should be signed, and
		 * we're configured to require signatures.
		 */
		if ((sr->smb2_hdr_flags & SMB2_FLAGS_SIGNED) == 0) {
			smb2sr_put_error(sr, NT_STATUS_ACCESS_DENIED);
			goto done;
		}
		rc = smb2_sign_check_request(sr);
		if (rc != 0) {
			DTRACE_PROBE1(smb2__sign__check, smb_request_t, sr);
			smb2sr_put_error(sr, NT_STATUS_ACCESS_DENIED);
			goto done;
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
	 * The real work: call the SMB2 command handler.
	 */
	sr->sr_time_start = gethrtime();
	if (async_func != NULL) {
		rc = (*async_func)(sr);
	} else {
		/* NB: not using pre_op */
		rc = (*sdd->sdt_function)(sr);
		/* NB: not using post_op */
	}

	MBC_FLUSH(&sr->raw_data);

done:
	/*
	 * Pad the reply to align(8) if necessary.
	 */
	if (sr->reply.chain_offset & 7) {
		int padsz = 8 - (sr->reply.chain_offset & 7);
		(void) smb_mbc_encodef(&sr->reply, "#.", padsz);
	}
	ASSERT((sr->reply.chain_offset & 7) == 0);

	/*
	 * Record some statistics: latency, rx bytes, tx bytes.
	 * Note that async commands get special treatment because
	 * they come through here twice.  The first call does the
	 * sync. part, and for that we want to record the latency,
	 * as well as bytes received and transmitted.  The second
	 * call is the async part, for which we record only the
	 * bytes transmitted (because it does actually send again).
	 * It doesn't make sense to measure latency on the async.
	 * part of any call, because the waits are indefinite.
	 * Also don't add bytes received on the async call, as
	 * there is only one receive, and that was accounted for
	 * during the sync. part of dispatch handling.
	 */
	if (async_func == NULL) {
		/* Sync. part of dispatch */
		smb_latency_add_sample(&sds->sdt_lat,
		    gethrtime() - sr->sr_time_start);
		atomic_add_64(&sds->sdt_rxb,
		    (int64_t)(sr->command.chain_offset - sr->smb2_cmd_hdr));
	}
	/* Both sync. and async. */
	atomic_add_64(&sds->sdt_txb,
	    (int64_t)(sr->reply.chain_offset - sr->smb2_reply_hdr));

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

	sr->smb_uid = (uint16_t)ssnid;	/* XXX wide UIDs */

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
	uint64_t ssnid = sr->smb_uid;
	uint64_t pid_tid_aid; /* pid+tid, or async id */
	int rc;

	if (sr->smb2_hdr_flags & SMB2_FLAGS_ASYNC_COMMAND) {
		pid_tid_aid = sr->smb2_async_id;
	} else {
		pid_tid_aid = sr->smb_pid |
		    ((uint64_t)sr->smb_tid) << 32;
	}

	if (overwrite) {
		rc = smb_mbc_poke(&sr->reply,
		    sr->smb2_reply_hdr,
		    "Nwwlwwllqqq16c",
		    SMB2_HDR_SIZE,		/* w */
		    sr->smb2_credit_charge,	/* w */
		    sr->smb2_status,		/* l */
		    sr->smb2_cmd_code,		/* w */
		    sr->smb2_credit_response,	/* w */
		    sr->smb2_hdr_flags,		/* l */
		    sr->smb2_next_reply,	/* l */
		    sr->smb2_messageid,		/* q */
		    pid_tid_aid,		/* q */
		    ssnid,			/* q */
		    sr->smb2_sig);		/* 16c */
	} else {
		rc = smb_mbc_encodef(&sr->reply,
		    "Nwwlwwllqqq16c",
		    SMB2_HDR_SIZE,		/* w */
		    sr->smb2_credit_charge,	/* w */
		    sr->smb2_status,		/* l */
		    sr->smb2_cmd_code,		/* w */
		    sr->smb2_credit_response,	/* w */
		    sr->smb2_hdr_flags,		/* l */
		    sr->smb2_next_reply,	/* l */
		    sr->smb2_messageid,		/* q */
		    pid_tid_aid,		/* q */
		    ssnid,			/* q */
		    sr->smb2_sig);		/* 16c */
	}

	return (rc);
}

void
smb2_send_reply(smb_request_t *sr)
{

	if (smb_session_send(sr->session, 0, &sr->reply) == 0)
		sr->reply.chain = 0;
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
 * or obtained via FID lookup.
 */
uint32_t
smb2sr_lookup_fid(smb_request_t *sr, smb2fid_t *fid)
{
	boolean_t related = sr->smb2_hdr_flags &
	    SMB2_FLAGS_RELATED_OPERATIONS;

	if ((!related || fid->temporal != ~0LL) &&
	    sr->fid_ofile != NULL) {
		smb_ofile_request_complete(sr->fid_ofile);
		smb_ofile_release(sr->fid_ofile);
		sr->fid_ofile = NULL;
	}

	if (related && fid->temporal == ~0LL &&
	    sr->fid_ofile != NULL) {
		sr->smb_fid = sr->fid_ofile->f_fid;
	} else {
		ASSERT(sr->fid_ofile == NULL);
		sr->smb_fid = (uint16_t)fid->temporal;
		sr->fid_ofile = smb_ofile_lookup_by_fid(sr,
		    sr->smb_fid);
	}
	if (sr->fid_ofile == NULL)
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
