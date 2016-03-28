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
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * SMB: nt_cancel
 *
 * This SMB allows a client to cancel a request currently pending at the
 * server.
 *
 * Client Request                     Description
 * ================================== =================================
 *
 * UCHAR WordCount;                   No words are sent (== 0)
 * USHORT ByteCount;                  No bytes (==0)
 *
 * The Sid, Uid, Pid, Tid, and Mid fields of the SMB are used to locate an
 * pending server request from this session.  If a pending request is
 * found, it is "hurried along" which may result in success or failure of
 * the original request.  No other response is generated for this SMB.
 */

#include <smbsrv/smb_kproto.h>

static int smb1_cancel(smb_request_t *, int);

smb_sdrc_t
smb_pre_nt_cancel(smb_request_t *sr)
{
	DTRACE_SMB_1(op__NtCancel__start, smb_request_t *, sr);
	return (SDRC_SUCCESS);
}

void
smb_post_nt_cancel(smb_request_t *sr)
{
	DTRACE_SMB_1(op__NtCancel__done, smb_request_t *, sr);
}

/*
 * Dispatch handler for SMB_COM_NT_CANCEL.
 * Note that Cancel does NOT get a response.
 *
 * SMB NT Cancel has an inherent race with the request being
 * cancelled.  See comments at smb_request_cancel().
 */
smb_sdrc_t
smb_com_nt_cancel(smb_request_t *sr)
{
	int		cnt;

	cnt = smb1_cancel(sr, 0);
	if (cnt == 0) {
		/*
		 * Did not find the request to be cancelled
		 * (or it hasn't had a chance to run yet).
		 * Delay a little and look again.
		 */
		delay(MSEC_TO_TICK(smb_cancel_delay));
		cnt = smb1_cancel(sr, 1);
	}

	if (cnt != 1) {
		cmn_err(CE_WARN, "SMB nt_cancel failed, "
		    "client=%s, MID=0x%x",
		    sr->session->ip_addr_str,
		    (uint_t)sr->smb_mid);
	}

	return (SDRC_NO_REPLY);
}

static int
smb1_cancel(smb_request_t *sr, int pass)
{
	struct smb_request *req;
	struct smb_session *session;
	int cnt = 0;

	session = sr->session;

	smb_slist_enter(&session->s_req_list);
	req = smb_slist_head(&session->s_req_list);
	while (req) {
		ASSERT(req->sr_magic == SMB_REQ_MAGIC);
		if ((req != sr) &&
		    (req->smb_uid == sr->smb_uid) &&
		    (req->smb_pid == sr->smb_pid) &&
		    (req->smb_tid == sr->smb_tid) &&
		    (req->smb_mid == sr->smb_mid)) {
			if (smb_request_cancel(req, pass))
				cnt++;
		}
		req = smb_slist_next(&session->s_req_list, req);
	}
	smb_slist_exit(&session->s_req_list);

	return (cnt);
}
