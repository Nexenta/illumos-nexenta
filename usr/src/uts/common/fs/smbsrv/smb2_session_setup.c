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

/*
 * Dispatch function for SMB2_SESSION_SETUP
 *
 * Note that the Capabilities supplied in this request are an inferior
 * subset of those given to us previously in the SMB2 Negotiate request.
 * We need to remember the full set of capabilities from SMB2 Negotiate,
 * and therefore ignore the subset of capabilities supplied here.
 */

#include <smbsrv/smb2_kproto.h>

smb_sdrc_t
smb2_session_setup(smb_request_t *sr)
{
	smb_session_t *s;
	smb_arg_sessionsetup_t	*sinfo;
	uint16_t StructureSize;
	uint8_t  Flags;
	uint8_t  SecurityMode;
	uint32_t Capabilities;	/* ignored - see above */
	uint32_t Channel;
	uint16_t SecBufOffset;
	uint16_t SecBufLength;
	uint64_t PrevSessionId;
	uint16_t SessionFlags;
	uint32_t status;
	int skip;
	int rc = 0;

	s = sr->session;
	sinfo = smb_srm_zalloc(sr, sizeof (smb_arg_sessionsetup_t));
	sr->sr_ssetup = sinfo;

	rc = smb_mbc_decodef(
	    &sr->smb_data, "wbbllwwq",
	    &StructureSize,	/* w */
	    &Flags,		/* b */
	    &SecurityMode,	/* b */
	    &Capabilities,	/* l */
	    &Channel,		/* l */
	    &SecBufOffset,	/* w */
	    &SecBufLength,	/* w */
	    &PrevSessionId);	/* q */
	if (rc)
		return (SDRC_ERROR);

	/*
	 * SMB3 multi-channel features are not supported.
	 * Once they are, this will check the dialect and
	 * whether multi-channel was negotiated, i.e.
	 *	if (sr->session->dialect < SMB_VERS_3_0 ||
	 *	    s->IsMultiChannelCapable == False)
	 *		return (error...)
	 */
	if (sr->smb2_hdr_flags & SMB2_SESSION_FLAG_BINDING) {
		status = NT_STATUS_REQUEST_NOT_ACCEPTED;
		goto errout;
	}

	/*
	 * We're normally positioned at the security buffer now,
	 * but there could be some padding before it.
	 */
	skip = (SecBufOffset + sr->smb2_cmd_hdr) -
	    sr->smb_data.chain_offset;
	if (skip < 0)
		return (SDRC_ERROR);
	if (skip > 0)
		(void) smb_mbc_decodef(&sr->smb_data, "#.", skip);

	/*
	 * Get the security buffer
	 */
	sinfo->ssi_iseclen = SecBufLength;
	sinfo->ssi_isecblob = smb_srm_zalloc(sr, sinfo->ssi_iseclen);
	rc = smb_mbc_decodef(&sr->smb_data, "#c",
	    sinfo->ssi_iseclen, sinfo->ssi_isecblob);
	if (rc)
		return (SDRC_ERROR);

	/*
	 * The real auth. work happens in here.
	 */
	status = smb_authenticate_ext(sr);

	SecBufOffset = SMB2_HDR_SIZE + 8;
	SecBufLength = sinfo->ssi_oseclen;
	SessionFlags = 0;

	switch (status) {

	case NT_STATUS_SUCCESS:
		if (sr->uid_user->u_flags & SMB_USER_FLAG_GUEST)
			SessionFlags |= SMB2_SESSION_FLAG_IS_GUEST;
		if (sr->uid_user->u_flags & SMB_USER_FLAG_ANON)
			SessionFlags |= SMB2_SESSION_FLAG_IS_NULL;
		/* Authenticated.  Let them use all their credits. */
		mutex_enter(&s->s_credits_mutex);
		s->s_max_credits = s->s_cfg.skc_maximum_credits;
		mutex_exit(&s->s_credits_mutex);
		break;

	/*
	 * This is not really an error, but tells the client
	 * it should send another session setup request.
	 * Not smb2_put_error because we send a payload.
	 */
	case NT_STATUS_MORE_PROCESSING_REQUIRED:
		sr->smb2_status = status;
		break;

	default:
errout:
		SecBufLength = 0;
		sr->smb2_status = status;
		break;
	}

	/*
	 * SMB2 Session Setup reply
	 */

	rc = smb_mbc_encodef(
	    &sr->reply,
	    "wwww#c",
	    9,	/* StructSize */	/* w */
	    SessionFlags,		/* w */
	    SecBufOffset,		/* w */
	    SecBufLength,		/* w */
	    SecBufLength,		/* # */
	    sinfo->ssi_osecblob);	/* c */
	if (rc)
		return (SDRC_ERROR);

	return (SDRC_SUCCESS);
}
