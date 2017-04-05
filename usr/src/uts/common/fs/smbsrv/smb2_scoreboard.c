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
 * Copyright 2017 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * With SMB2 and later, cancel processing may race with the command
 * being cancelled.  When the message ID being cancelled is part of a
 * compound request, and that member of the compound is not active
 * at the time the cancel is processed, then that cancel will not
 * find the request. (a "missed cancel")  We deal with that by
 * keeping track of cancellations in a "scoreboard", and check for
 * a missed cancel when processing SMB2 commands that may block.
 *
 * We only check the scoreboard in SMB command-specific handlers when
 * one of them is about to block for something, because we otherwise
 * want to let those handlers run if we can.  This is important for
 * SMB2_notify, which should record some state changes even when
 * the command is immediately cancelled.
 *
 * The "scoreboard" keeps track of whether message IDs have been:
 *   (0) never seen, (1) started, (2) cancelled, or (3) done.
 * It's stored as a circular buffer of state codes for the
 * most recent 1024 message IDs.
 */


#include <smbsrv/smb2_kproto.h>

/*
 * Scoreboard size must be a power of 2, and >= max credits.
 */
#define	SCOREBOARD_SIZE	1024
#if SCOREBOARD_SIZE < SMB_PI_MAXIMUM_CREDITS_MAX
#error "Increase SCOREBOARD_SIZE"
#endif
#define	SCOREBOARD_MASK (SCOREBOARD_SIZE - 1)

enum sb_state { SB_unseen = 0, SB_started = 1, SB_cancelled = 2, SB_done = 3 };

/*
 * Advance the window of valid message IDs.  The amount we advance is
 * normally one (or a small number) so we don't bother with memset
 * for initializing the new part of the window.
 */
static inline void
scoreboard_advance(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx;

	ASSERT(MUTEX_HELD(&s->s_scoreboard_mutex));

	while (s->s_scoreboard_maxid < sr->smb2_messageid) {
		s->s_scoreboard_maxid++;
		idx = s->s_scoreboard_maxid & SCOREBOARD_MASK;
		s->s_scoreboard_arr[idx] = SB_unseen;
	}
}

static inline boolean_t
scoreboard_valid_id(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	uint64_t id = sr->smb2_messageid;
	boolean_t rv = B_FALSE;

	ASSERT(MUTEX_HELD(&s->s_scoreboard_mutex));

	if (id <= s->s_scoreboard_maxid &&
	    id >= (s->s_scoreboard_maxid - SCOREBOARD_MASK))
		rv = B_TRUE;

	return (rv);
}

void
smb2_scoreboard_init(smb_session_t *s)
{
	if (s->s_scoreboard_arr == NULL) {
		/*
		 * Initial valid range is 0..1023, with
		 * message ID zero "used" by negotiate.
		 */
		s->s_scoreboard_maxid = SCOREBOARD_SIZE - 1;
		s->s_scoreboard_arr = kmem_zalloc(SCOREBOARD_SIZE, KM_SLEEP);
		s->s_scoreboard_arr[0] = SB_done;

	}
}

void
smb2_scoreboard_fini(smb_session_t *s)
{
	if (s->s_scoreboard_arr != NULL)
		kmem_free(s->s_scoreboard_arr, SCOREBOARD_SIZE);
}

/*
 * We have a new command, and probably a new message ID.
 * Move the "valid IDs" window forward as necessary,
 * check that we've not already seen this ID, and
 * set the state to "started".
 */
int
smb2_scoreboard_cmd_start(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx = sr->smb2_messageid & SCOREBOARD_MASK;
	int rc = 0;
	boolean_t cancelled = B_FALSE;

	mutex_enter(&s->s_scoreboard_mutex);
	scoreboard_advance(sr);
	switch (s->s_scoreboard_arr[idx]) {
	case SB_unseen:
		s->s_scoreboard_arr[idx] = SB_started;
		break;
	case SB_started:
	case SB_done:
		cmn_err(CE_WARN, "clnt %s dup msg ID 0x%llx",
		    s->ip_addr_str, (long long) sr->smb2_messageid);
		rc = -1; /* duplicate message ID */
		break;
	case SB_cancelled:
		cancelled = B_TRUE;
		break;
	}
	mutex_exit(&s->s_scoreboard_mutex);

	if (cancelled) {
		mutex_enter(&sr->sr_mutex);
		if (sr->sr_state == SMB_REQ_STATE_ACTIVE)
			sr->sr_state = SMB_REQ_STATE_CANCELLED;
		mutex_exit(&sr->sr_mutex);
	}


	return (rc);
}

void
smb2_scoreboard_cmd_done(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx = sr->smb2_messageid & SCOREBOARD_MASK;

	mutex_enter(&s->s_scoreboard_mutex);
	if (scoreboard_valid_id(sr))
		s->s_scoreboard_arr[idx] = SB_done;
	mutex_exit(&s->s_scoreboard_mutex);
}

/*
 * Mark the scoreboard slot for this command as "cancelled".
 * As an aid for debugging and reporting about cancellation,
 * return B_TRUE if this ID was "started" in the scoreboard
 * (meaning we cancelled it).
 */
boolean_t
smb2_scoreboard_cancel(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx = sr->smb2_messageid & SCOREBOARD_MASK;
	boolean_t rv = B_FALSE;

	mutex_enter(&s->s_scoreboard_mutex);
	scoreboard_advance(sr);

	switch (s->s_scoreboard_arr[idx]) {
	case SB_unseen:
		s->s_scoreboard_arr[idx] = SB_cancelled;
		DTRACE_PROBE1(smb2__cancel__before__start,
		    uint64_t, sr->smb2_messageid);
		break;

	case SB_started:
		s->s_scoreboard_arr[idx] = SB_cancelled;
		rv = B_TRUE;
		break;

	case SB_cancelled:
	case SB_done:
		/* leave it as it was */
		break;
	}
	mutex_exit(&s->s_scoreboard_mutex);

	return (rv);
}
