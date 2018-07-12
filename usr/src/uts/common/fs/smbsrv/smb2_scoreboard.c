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

/*
 * "Big theory statement"
 *
 * With SMB2 and later, cancel processing may race with the command
 * being cancelled.  When the message ID being cancelled is part of a
 * compound request, and that member of the compound is not active
 * at the time the cancel is processed, then that cancel will not
 * find the request. (a "missed cancel")  We deal with that by
 * keeping track of cancellations in a "scoreboard", and check for
 * a missed cancel when processing SMB2 commands that may block.
 *
 * When we're about to run an SMB2 command (in smb2sr_work) it calls
 * smb2_scoreboard_cmd_start to check whether this message ID has
 * already been cancelled, and if not, mark the ID as "active".
 * If the ID was cancelled, we set the sr_state to CANCELLED and
 * the command-specific handler terminates processing early.
 *
 * The scoreboard itself is a rolling buffer keeping state for
 * message IDs in the range: "oldest" <= ID < "maxid".  Only the
 * "maxid" value is actually stored (in ssn->s_scoreboard_maxid)
 * because "oldest" is simply: maxid - scoreboard_size
 *
 * Each cell in the scoreboard tracks the information about the
 * message ID for the index value: ID & (scoreboard_size - 1)
 * The states in each cell are enum sb_state (below).
 *
 * As new message IDs are received (at "maxid" or beyond) we must
 * "advance the window" represented by the scoreboard, which means:
 *	(a) Updating "maxid" (from old_max to new_max)
 *	(b) re-initializing cells between old_max..new_max
 *
 * Clients may use any message IDs that:
 *	(a) have never been used before, and
 *	(b) are within max_credits of the oldest active ID
 *
 * Within the above constraints, clients may issue commands with
 * message IDs in any sequence.  It's also apparently possible a
 * client may skip message IDs (leaving them forever unused).
 *
 * When we advance the message ID window, we check that there are
 * no commands still active in the range of message IDs that will be
 * less than "oldest" after the advance.  If there are any commands
 * still active in that range, it means the client is trying to use
 * a range of message IDs greater than max_credits, which is a
 * protocol violation and a reason to disconnect the client.
 */

#include <smbsrv/smb2_kproto.h>

/*
 * Scoreboard size must be a power of 2, and >= max credits.
 * But note: In [MS-SMB2] footnote 166 (Section 3.3.1.1)
 * they say Windows servers allow message IDs covering 2X
 * the maximum credits.  (Sigh... so we must also.)
 */
#define	SCOREBOARD_SIZE (SMB_PI_MAXIMUM_CREDITS_MAX * 2)
#if (SCOREBOARD_SIZE & (SCOREBOARD_SIZE - 1)) != 0
#error "SCOREBOARD_SIZE not a power of 2"
#endif

/*
 * We MAY on occasion want use a larger scoreboard, to keep longer
 * history about message IDs when debugging odd client behavior.
 * Do not adjust while the SMB server is running!
 */
static uint32_t smb2_scoreboard_size = SCOREBOARD_SIZE;

/*
 * Convenience macro
 */
#define	IDX(id)	((uint32_t)(id) & (smb2_scoreboard_size - 1))

/*
 * States of message IDs represented by cells in the scoreboard.
 *
 * The state "unseen" means we have not received this message ID
 * from the client.  The client may use this ID (once) as long as
 * the ID remains within the current message ID window.
 *
 * Note that states: (received, started, cancelled) all imply
 * that we've received a command with that message ID and that
 * the message ID has not yet been "retired".  This is important
 * in relation to other IDs in use because the total range of
 * in-use message IDs is restricted.
 *
 * The states: (done, async) represent message IDs that have been
 * received, processed, and "retired" and should not be reused.
 * The state "async" is a variant of "done" used just to keep
 * track of whether the command completed or "went async".
 * When a command "goes async", it's message ID is "retired".
 * Once a message ID is "retired" (done or aync) it no longer
 * constrains the message ID window.
 *
 * The important state transitions are:
 *
 * unseen -> received
 *	receive a new message ID in some command
 * received -> started
 *	started working on a command (not cancelled)
 * received -> cancelled
 *	command was cancelled before a worker started on it
 * started -> cancelled
 *	command was cancelled while a worker is active on it
 * started -> done
 *	normal command completion
 * started -> async
 *	command "went async" (retiring its message ID)
 * cancelled -> done
 *	cancelled command completion
 */
enum sb_state {
	SB_unseen = 0,
	SB_received,
	SB_started,
	SB_cancelled,
	SB_done,
	SB_async,
};

static inline boolean_t
scoreboard_valid_id(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	uint64_t id = sr->smb2_messageid;
	uint64_t oldest = s->s_scoreboard_maxid - smb2_scoreboard_size;

	ASSERT(MUTEX_HELD(&s->s_scoreboard_mutex));

	if (id < oldest)
		return (B_FALSE);
	if (id >= s->s_scoreboard_maxid)
		return (B_FALSE);

	return (B_TRUE);
}

void
smb2_scoreboard_init(smb_session_t *s)
{
	if (s->s_scoreboard_arr != NULL)
		return;

	/*
	 * Initial valid range is 0..1023, with
	 * message ID zero "done" (smb2_negotiate).
	 */
	s->s_scoreboard_maxid = smb2_scoreboard_size;
	s->s_scoreboard_arr = kmem_zalloc(smb2_scoreboard_size, KM_SLEEP);
	s->s_scoreboard_arr[0] = SB_done;
}

void
smb2_scoreboard_fini(smb_session_t *s)
{
	if (s->s_scoreboard_arr != NULL)
		kmem_free(s->s_scoreboard_arr, smb2_scoreboard_size);
}

/*
 * This is called by smb2sr_newrq (in the reader thread)
 * for every new message ID received from the client.
 *
 * Move the "message IDs" window forward as described in the
 * "Big theory statement" above.  If the new message ID would
 * expand the range of in-use message IDs to anything larger
 * than s->s_max_credits, that's a protocol violation, so
 * return non-zero and we'll drop this client connection.
 * Similarly for re-used message IDs, return non-zero.
 */
int
smb2_scoreboard_cmd_new(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	char *errmsg = NULL;
	uint64_t newmax;
	uint32_t idx;

	mutex_enter(&s->s_scoreboard_mutex);

	/*
	 * Sanity check the new message ID
	 */
	if (sr->smb2_messageid <
	    (s->s_scoreboard_maxid - smb2_scoreboard_size)) {
		DTRACE_PROBE1(msgid__too__low, smb_request_t, sr);
		errmsg = "too low";
		goto out;
	}

	newmax = sr->smb2_messageid + 1;
	if (newmax > s->s_scoreboard_maxid) {
		/*
		 * Need to advance the window.  Make sure there are
		 * no active message IDs in the range that will be
		 * re-initialized as we move the window.  If any
		 * are found, then the new ID is invalid because
		 * it's more than max_credits ahead of the oldest.
		 */
		uint64_t delta = newmax - s->s_scoreboard_maxid;
		if (delta < smb2_scoreboard_size) {
			/*
			 * There should be no active IDs in the range that
			 * will be re-initialized by the window update.
			 */
			uint32_t newidx = IDX(newmax);
			idx = IDX(s->s_scoreboard_maxid);
			while (idx != newidx) {
				switch (s->s_scoreboard_arr[idx]) {
				case SB_received:
				case SB_started:
				case SB_cancelled:
					DTRACE_PROBE2(msgid__too__high,
					    smb_request_t, sr,
					    uint64_t, delta);
					errmsg = "too high (1)";
					goto out;
				default:
					break;
				}
				s->s_scoreboard_arr[idx] = SB_unseen;
				idx = IDX(idx + 1);
			}
		} else {
			/*
			 * delta >= smb2_scoreboard_size
			 *
			 * The client is skipping a range of IDs larger
			 * than our scoreboard.  There should be NO
			 * active IDs anywhere in the scoreboard.
			 */
			for (idx = 0; idx < smb2_scoreboard_size; idx++) {
				switch (s->s_scoreboard_arr[idx]) {
				case SB_received:
				case SB_started:
				case SB_cancelled:
					DTRACE_PROBE2(msgid__too__high,
					    smb_request_t, sr,
					    uint64_t, delta);
					errmsg = "too high (2)";
					goto out;
				default:
					break;
				}
			}
			/*
			 * OK, there are no active message IDs.
			 * We can just reinitialize the whole
			 * scoreboard and set the new maxid.
			 * Note: SB_unseen is zero.
			 */
			bzero(s->s_scoreboard_arr, smb2_scoreboard_size);
		}

		/*
		 * Done re-initializing cells.
		 * Advance the window.
		 */
		s->s_scoreboard_maxid = newmax;
	}

	/*
	 * Now that we know the new ID is somwhere in the
	 * current window, we can update the cell.
	 */
	idx = IDX(sr->smb2_messageid);
	switch (s->s_scoreboard_arr[idx]) {
	case SB_unseen:
		s->s_scoreboard_arr[idx] = SB_received;
		break;
	default:
		DTRACE_PROBE1(msgid__reused, smb_request_t, sr);
		errmsg = "reused";
		goto out;
	}

out:
	mutex_exit(&s->s_scoreboard_mutex);
	if (errmsg != NULL) {
		long long id = (long long) sr->smb2_messageid;
		cmn_err(CE_WARN, "clnt %s msg ID 0x%llx %s",
		    s->ip_addr_str, id, errmsg);
		return (-1);
	}
	return (0);
}

/*
 * This command is about to start service.
 *
 * This is where we check whether we've received an SMB2 cancel
 * for this message ID before a worker could get to the command.
 * If so, leave the scoreboard state as it is and return TRUE,
 * and our caller will set sr_state to cancelled etc.
 *
 * Otherwise (not cancelled) update the scoreboard to show that
 * this command was "started".
 *
 * Note that there's intentionally no window advance here,
 * as that should have happened in _cmd_new.
 */
boolean_t
smb2_scoreboard_cmd_start(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx = IDX(sr->smb2_messageid);
	boolean_t cancelled = B_FALSE;

	mutex_enter(&s->s_scoreboard_mutex);

	/*
	 * It should not be possible to get invalid IDs here
	 * after checks in smb2_scoreboard_cmd_new.  If the
	 * ID is outside the current window, do nothing.
	 */
	if (!scoreboard_valid_id(sr)) {
		cmn_err(CE_WARN, "clnt %s bad ID 0x%llx in _cmd_start",
		    s->ip_addr_str, (long long) sr->smb2_messageid);
		mutex_exit(&s->s_scoreboard_mutex);
		return (cancelled);
	}

	switch (s->s_scoreboard_arr[idx]) {
	case SB_received:
		s->s_scoreboard_arr[idx] = SB_started;
		break;

	case SB_cancelled:
		/*
		 * This command was cancelled before a worker got to it.
		 * Will set sr_state below.  Leave the scoreboard state
		 * at SB_cancelled until smb2_scoreboard_cmd_done
		 */
		cancelled = B_TRUE;
		break;

	default:
		/*
		 * We should have one of the above states after
		 * _cmd_new or _cmd_cancel  Leave the state
		 * (will correct it in _cmd_done).
		 */
		cmn_err(CE_WARN, "clnt %s msg ID 0x%llx "
		    "unexpected state %d in _cmd_start",
		    s->ip_addr_str,
		    (long long) sr->smb2_messageid,
		    s->s_scoreboard_arr[idx]);
		break;
	}

	mutex_exit(&s->s_scoreboard_mutex);
	return (cancelled);
}

/*
 * Called when a message ID should be retired.
 *
 * This sets the scoreboard state to SB_done, or SB_async if the
 * message ID is being retired when a command "goes async".
 * SB_async means the same thing as SB_done, and is used only to
 * have more helpful information when debugging.
 */
void
smb2_scoreboard_cmd_done(smb_request_t *sr, boolean_t async)
{
	smb_session_t *s = sr->session;
	int idx = IDX(sr->smb2_messageid);
	uchar_t newstate = (async) ? SB_async : SB_done;

	mutex_enter(&s->s_scoreboard_mutex);

	/*
	 * It should not be possible to get invalid IDs here
	 * after checks in smb2_scoreboard_cmd_new.  If the
	 * ID is outside the current window, do nothing.
	 */
	if (!scoreboard_valid_id(sr)) {
		cmn_err(CE_WARN, "clnt %s bad ID 0x%llx in _cmd_done",
		    s->ip_addr_str, (long long) sr->smb2_messageid);
		mutex_exit(&s->s_scoreboard_mutex);
		return;
	}

	switch (s->s_scoreboard_arr[idx]) {
	default:
		/*
		 * smb2_scoreboard_cmd_start should have left
		 * one of the scoreboard states below.  If not,
		 * go ahead and mark this cell "done" anyway.
		 */
		cmn_err(CE_WARN, "clnt %s msg ID 0x%llx "
		    "unexpected state %d in _cmd_start",
		    s->ip_addr_str,
		    (long long) sr->smb2_messageid,
		    s->s_scoreboard_arr[idx]);
		/* FALLTHROUGH */
	case SB_cancelled:
	case SB_started:
		s->s_scoreboard_arr[idx] = newstate;
		break;

	}

	mutex_exit(&s->s_scoreboard_mutex);
}

/*
 * Mark the scoreboard slot for this command as "cancelled".
 * As an aid for debugging and reporting about cancellation,
 * return B_TRUE if this command is active (its message ID
 * was "started" in the scoreboard)
 */
boolean_t
smb2_scoreboard_cmd_cancel(smb_request_t *sr)
{
	smb_session_t *s = sr->session;
	int idx = IDX(sr->smb2_messageid);
	boolean_t rv = B_FALSE;

	mutex_enter(&s->s_scoreboard_mutex);

	/*
	 * Clients apparently DO sometimes send invalid
	 * message IDs with SMB2 cancel, so this is not a
	 * logic problem on our side.  Just complain.
	 */
	if (!scoreboard_valid_id(sr)) {
		cmn_err(CE_WARN, "clnt %s cancel ID 0x%llx invalid",
		    s->ip_addr_str, (long long) sr->smb2_messageid);
		mutex_exit(&s->s_scoreboard_mutex);
		return (rv);
	}

	switch (s->s_scoreboard_arr[idx]) {
	case SB_unseen:
		cmn_err(CE_WARN, "clnt %s cancel ID 0x%llx before cmd",
		    s->ip_addr_str, (long long) sr->smb2_messageid);
		break;

	case SB_received:
		s->s_scoreboard_arr[idx] = SB_cancelled;
		DTRACE_PROBE1(msgid__cancel__before__start,
		    smb_request_t, sr);
		break;

	case SB_started:
		s->s_scoreboard_arr[idx] = SB_cancelled;
		/* This command is active */
		rv = B_TRUE;
		break;

	default:
		/* no scoreboard change */
		break;
	}

	mutex_exit(&s->s_scoreboard_mutex);

	return (rv);
}
