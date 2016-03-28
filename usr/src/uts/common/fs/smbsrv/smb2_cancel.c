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
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Dispatch function for SMB2_CANCEL
 */

#include <smbsrv/smb2_kproto.h>

static int smb2_cancel_async(smb_request_t *);
static int smb2_cancel_sync(smb_request_t *, int);

/*
 * Dispatch handler for SMB2_CANCEL.
 * Note that Cancel does NOT get a response.
 *
 * SMB2 Cancel (sync) has an inherent race with the request being
 * cancelled.  See comments at smb_request_cancel().
 *
 * Note that cancelling an async request doesn't have the race
 * because the client doesn't learn about the async ID until we
 * send it to them in an interim reply, and by that point the
 * request has progressed to the point where cancel works.
 */
smb_sdrc_t
smb2_cancel(smb_request_t *sr)
{
	int cnt;

	/*
	 * If we get SMB2 cancel as part of a compound,
	 * that's a protocol violation.  Drop 'em!
	 */
	if (sr->smb2_cmd_hdr != 0 || sr->smb2_next_command != 0)
		return (SDRC_DROP_VC);

	if (sr->smb2_hdr_flags & SMB2_FLAGS_ASYNC_COMMAND) {
		cnt = smb2_cancel_async(sr);
		if (cnt != 1) {
			cmn_err(CE_WARN, "SMB2 cancel failed, "
			    "client=%s, AID=0x%llx",
			    sr->session->ip_addr_str,
			    (u_longlong_t)sr->smb2_async_id);
		}
	} else {
		cnt = smb2_cancel_sync(sr, 0);
		if (cnt == 0) {
			/*
			 * Did not find the request to be cancelled
			 * (or it hasn't had a chance to run yet).
			 * Delay a little and look again.
			 */
			delay(MSEC_TO_TICK(smb_cancel_delay));
			cnt = smb2_cancel_sync(sr, 1);
		}
		if (cnt != 1) {
			cmn_err(CE_WARN, "SMB2 cancel failed, "
			    "client=%s, MID=0x%llx",
			    sr->session->ip_addr_str,
			    (u_longlong_t)sr->smb2_messageid);
		}
	}

	return (SDRC_NO_REPLY);
}

static int
smb2_cancel_sync(smb_request_t *sr, int pass)
{
	struct smb_request *req;
	struct smb_session *session = sr->session;
	int cnt = 0;

	smb_slist_enter(&session->s_req_list);
	req = smb_slist_head(&session->s_req_list);
	while (req) {
		ASSERT(req->sr_magic == SMB_REQ_MAGIC);
		if ((req != sr) &&
		    (req->smb2_messageid == sr->smb2_messageid)) {
			if (smb_request_cancel(req, pass))
				cnt++;
		}
		req = smb_slist_next(&session->s_req_list, req);
	}
	smb_slist_exit(&session->s_req_list);

	return (cnt);
}

static int
smb2_cancel_async(smb_request_t *sr)
{
	struct smb_request *req;
	struct smb_session *session = sr->session;
	int cnt = 0;

	smb_slist_enter(&session->s_req_list);
	req = smb_slist_head(&session->s_req_list);
	while (req) {
		ASSERT(req->sr_magic == SMB_REQ_MAGIC);
		if ((req != sr) &&
		    (req->smb2_async_id == sr->smb2_async_id)) {
			if (smb_request_cancel(req, 1))
				cnt++;
		}
		req = smb_slist_next(&session->s_req_list, req);
	}
	smb_slist_exit(&session->s_req_list);

	return (cnt);
}
