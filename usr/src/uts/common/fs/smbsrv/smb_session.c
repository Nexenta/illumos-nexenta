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
 * Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/atomic.h>
#include <sys/synch.h>
#include <sys/types.h>
#include <sys/sdt.h>
#include <sys/random.h>
#include <smbsrv/netbios.h>
#include <smbsrv/smb2_kproto.h>
#include <smbsrv/string.h>
#include <netinet/tcp.h>

/* How many iovec we'll handle as a local array (no allocation) */
#define	SMB_LOCAL_IOV_MAX	16

#define	SMB_NEW_KID()	atomic_inc_64_nv(&smb_kids)

static volatile uint64_t smb_kids;

/*
 * We track the keepalive in minutes, but this constant
 * specifies it in seconds, so convert to minutes.
 */
uint32_t smb_keep_alive = SMB_PI_KEEP_ALIVE_MIN / 60;

/*
 * The variable smb_cancel_delay is the minimum age (in mSec) of an
 * active request for it to be eligible for cancellation in "pass 0".
 * It's also used in the protocol-level cancel handlers for the
 * amount of time to delay between "pass 0" and "pass 1".
 * See smb_request_cancel()
 */
int smb_cancel_delay = 100; /* mSec */

/*
 * There are many smbtorture test cases that send
 * racing requests, and where the tests fail if we
 * don't execute them in exactly the order sent.
 * These are test bugs.  The protocol makes no
 * guarantees about execution order of requests
 * that are concurrently active.
 *
 * Nonetheless, smbtorture has many useful tests,
 * so we have this work-around we can enable to
 * basically force sequential execution.  When
 * enabled, insert a delay after each request is
 * issued a taskq job.  Enable this with mdb by
 * setting smb_reader_delay to 10.  Don't make it
 * more than 500 or so or the server will appear
 * to be so slow that tests may time out.
 */
int smb_reader_delay = 0;  /* mSec. */

static int  smbsr_newrq_initial(smb_request_t *);

static void smb_session_cancel(smb_session_t *);
static int smb_session_reader(smb_session_t *);
static int smb_session_xprt_puthdr(smb_session_t *,
    uint8_t msg_type, uint32_t msg_len,
    uint8_t *dst, size_t dstlen);
static smb_tree_t *smb_session_get_tree(smb_session_t *, smb_tree_t *);
static void smb_session_logoff(smb_session_t *);
static void smb_request_init_command_mbuf(smb_request_t *sr);
static void smb_session_genkey(smb_session_t *);
static int smb_session_kstat_update(kstat_t *, int);
void session_stats_init(smb_server_t *, smb_session_t *);
void session_stats_fini(smb_session_t *);

static void
smb_durable_expire(void *arg)
{
	smb_ofile_t *of = (smb_ofile_t *)arg;

	smb_ofile_close(of, 0);
	smb_ofile_release(of);
}

static void
smb_durable_timers(smb_server_t *sv)
{
	smb_hash_t *hash;
	int i;
	smb_llist_t *bucket;
	smb_ofile_t *of;
	hrtime_t expire_time;

	hash = sv->sv_persistid_ht;
	expire_time = gethrtime();

	for (i = 0; i < hash->num_buckets; i++) {
		bucket = &hash->buckets[i].b_list;
		smb_llist_enter(bucket, RW_READER);
		of = smb_llist_head(bucket);
		while (of != NULL) {
			SMB_OFILE_VALID(of);
			mutex_enter(&of->f_mutex);
			/* STATE_ORPHANED implies dh_expire_time != 0 */
			if (of->f_state == SMB_OFILE_STATE_ORPHANED &&
			    of->dh_expire_time <= expire_time) {
				of->f_state = SMB_OFILE_STATE_EXPIRED;
				/* inline smb_ofile_hold_internal() */
				of->f_refcnt++;
				smb_llist_post(bucket, of, smb_durable_expire);
			}
			mutex_exit(&of->f_mutex);
			of = smb_llist_next(bucket, of);
		}
		smb_llist_exit(bucket);
	}
}

void
smb_session_timers(smb_server_t *sv)
{
	smb_session_t	*session;
	smb_llist_t	*ll;

	smb_durable_timers(sv);

	ll = &sv->sv_session_list;
	smb_llist_enter(ll, RW_READER);
	session = smb_llist_head(ll);
	while (session != NULL) {
		/*
		 * Walk through the table and decrement each keep_alive
		 * timer that has not timed out yet. (keepalive > 0)
		 */
		SMB_SESSION_VALID(session);
		if (session->keep_alive &&
		    (session->keep_alive != (uint32_t)-1))
			session->keep_alive--;

		if (atomic_swap_32(&session->s_expire_cnt, 0) != 0) {
			smb_tree_t *tree;
			smb_llist_t *tl = &session->s_tree_list;

			smb_llist_enter(tl, RW_READER);
			tree = smb_llist_head(tl);
			while (tree != NULL) {
				smb_llist_flush(&tree->t_ofile_list);
				tree = smb_llist_next(tl, tree);
			}
			smb_llist_exit(tl);
			smb_llist_flush(&session->s_user_list);
		}
		session = smb_llist_next(ll, session);
	}
	smb_llist_exit(ll);
}

void
smb_session_correct_keep_alive_values(smb_llist_t *ll, uint32_t new_keep_alive)
{
	smb_session_t		*sn;

	/*
	 * Caller specifies seconds, but we track in minutes, so
	 * convert to minutes (rounded up).
	 */
	new_keep_alive = (new_keep_alive + 59) / 60;

	if (new_keep_alive == smb_keep_alive)
		return;
	/*
	 * keep alive == 0 means do not drop connection if it's idle
	 */
	smb_keep_alive = (new_keep_alive) ? new_keep_alive : -1;

	/*
	 * Walk through the table and set each session to the new keep_alive
	 * value if they have not already timed out.  Block clock interrupts.
	 */
	smb_llist_enter(ll, RW_READER);
	sn = smb_llist_head(ll);
	while (sn != NULL) {
		SMB_SESSION_VALID(sn);
		if (sn->keep_alive != 0)
			sn->keep_alive = new_keep_alive;
		sn = smb_llist_next(ll, sn);
	}
	smb_llist_exit(ll);
}

/*
 * Send a session message - supports SMB-over-NBT and SMB-over-TCP.
 * If an mbuf chain is provided (optional), it will be freed and
 * set to NULL -- unconditionally!  (error or not)
 *
 * Builds a I/O vector (uio/iov) to do the send from mbufs, plus one
 * segment for the 4-byte NBT header.
 */
int
smb_session_send(smb_session_t *session, uint8_t nbt_type, mbuf_chain_t *mbc)
{
	uio_t		uio;
	iovec_t		local_iov[SMB_LOCAL_IOV_MAX];
	iovec_t		*alloc_iov = NULL;
	int		alloc_sz = 0;
	mbuf_t		*m;
	uint8_t		nbt_hdr[NETBIOS_HDR_SZ];
	uint32_t	nbt_len;
	int		i, nseg;
	int		rc;

	switch (session->s_state) {
	case SMB_SESSION_STATE_DISCONNECTED:
	case SMB_SESSION_STATE_TERMINATED:
		rc = ENOTCONN;
		goto out;
	default:
		break;
	}

	/*
	 * Setup the IOV.  First, count the number of IOV segments
	 * (plus one for the NBT header) and decide whether we
	 * need to allocate an iovec or can use local_iov;
	 */
	bzero(&uio, sizeof (uio));
	nseg = 1;
	m = (mbc != NULL) ? mbc->chain : NULL;
	while (m != NULL) {
		nseg++;
		m = m->m_next;
	}
	if (nseg <= SMB_LOCAL_IOV_MAX) {
		uio.uio_iov = local_iov;
	} else {
		alloc_sz = nseg * sizeof (iovec_t);
		alloc_iov = kmem_alloc(alloc_sz, KM_SLEEP);
		uio.uio_iov = alloc_iov;
	}
	uio.uio_iovcnt = nseg;
	uio.uio_segflg = UIO_SYSSPACE;
	uio.uio_extflg = UIO_COPY_DEFAULT;

	/*
	 * Build the iov list, meanwhile computing the length of
	 * the SMB payload (to put in the NBT header).
	 */
	uio.uio_iov[0].iov_base = (void *)nbt_hdr;
	uio.uio_iov[0].iov_len = sizeof (nbt_hdr);
	i = 1;
	nbt_len = 0;
	m = (mbc != NULL) ? mbc->chain : NULL;
	while (m != NULL) {
		uio.uio_iov[i].iov_base = m->m_data;
		uio.uio_iov[i++].iov_len = m->m_len;
		nbt_len += m->m_len;
		m = m->m_next;
	}
	ASSERT3S(i, ==, nseg);

	/*
	 * Set the NBT header, set uio_resid
	 */
	uio.uio_resid = nbt_len + NETBIOS_HDR_SZ;
	rc = smb_session_xprt_puthdr(session, nbt_type, nbt_len,
	    nbt_hdr, NETBIOS_HDR_SZ);
	if (rc != 0)
		goto out;

	smb_server_add_txb(session->s_server, (int64_t)uio.uio_resid);
	rc = smb_net_send_uio(session, &uio);

out:
	if (alloc_iov != NULL)
		kmem_free(alloc_iov, alloc_sz);
	if ((mbc != NULL) && (mbc->chain != NULL)) {
		m_freem(mbc->chain);
		mbc->chain = NULL;
		mbc->flags = 0;
	}
	return (rc);
}

/*
 * Read, process and respond to a NetBIOS session request.
 *
 * A NetBIOS session must be established for SMB-over-NetBIOS.  Validate
 * the calling and called name format and save the client NetBIOS name,
 * which is used when a NetBIOS session is established to check for and
 * cleanup leftover state from a previous session.
 *
 * Session requests are not valid for SMB-over-TCP, which is unfortunate
 * because without the client name leftover state cannot be cleaned up
 * if the client is behind a NAT server.
 */
static int
smb_netbios_session_request(struct smb_session *session)
{
	int			rc;
	char			*calling_name;
	char			*called_name;
	char 			client_name[NETBIOS_NAME_SZ];
	struct mbuf_chain 	mbc;
	char 			*names = NULL;
	smb_wchar_t		*wbuf = NULL;
	smb_xprt_t		hdr;
	char *p;
	int rc1, rc2;

	session->keep_alive = smb_keep_alive;

	if ((rc = smb_session_xprt_gethdr(session, &hdr)) != 0)
		return (rc);

	DTRACE_PROBE2(receive__session__req__xprthdr, struct session *, session,
	    smb_xprt_t *, &hdr);

	if ((hdr.xh_type != SESSION_REQUEST) ||
	    (hdr.xh_length != NETBIOS_SESSION_REQUEST_DATA_LENGTH)) {
		DTRACE_PROBE1(receive__session__req__failed,
		    struct session *, session);
		return (EINVAL);
	}

	names = kmem_alloc(hdr.xh_length, KM_SLEEP);

	if ((rc = smb_sorecv(session->sock, names, hdr.xh_length)) != 0) {
		kmem_free(names, hdr.xh_length);
		DTRACE_PROBE1(receive__session__req__failed,
		    struct session *, session);
		return (rc);
	}

	DTRACE_PROBE3(receive__session__req__data, struct session *, session,
	    char *, names, uint32_t, hdr.xh_length);

	called_name = &names[0];
	calling_name = &names[NETBIOS_ENCODED_NAME_SZ + 2];

	rc1 = netbios_name_isvalid(called_name, 0);
	rc2 = netbios_name_isvalid(calling_name, client_name);

	if (rc1 == 0 || rc2 == 0) {

		DTRACE_PROBE3(receive__invalid__session__req,
		    struct session *, session, char *, names,
		    uint32_t, hdr.xh_length);

		kmem_free(names, hdr.xh_length);
		MBC_INIT(&mbc, MAX_DATAGRAM_LENGTH);
		(void) smb_mbc_encodef(&mbc, "b",
		    DATAGRAM_INVALID_SOURCE_NAME_FORMAT);
		(void) smb_session_send(session, NEGATIVE_SESSION_RESPONSE,
		    &mbc);
		return (EINVAL);
	}

	DTRACE_PROBE3(receive__session__req__calling__decoded,
	    struct session *, session,
	    char *, calling_name, char *, client_name);

	/*
	 * The client NetBIOS name is in oem codepage format.
	 * We need to convert it to unicode and store it in
	 * multi-byte format.  We also need to strip off any
	 * spaces added as part of the NetBIOS name encoding.
	 */
	wbuf = kmem_alloc((SMB_PI_MAX_HOST * sizeof (smb_wchar_t)), KM_SLEEP);
	(void) oemtoucs(wbuf, client_name, SMB_PI_MAX_HOST, OEM_CPG_850);
	(void) smb_wcstombs(session->workstation, wbuf, SMB_PI_MAX_HOST);
	kmem_free(wbuf, (SMB_PI_MAX_HOST * sizeof (smb_wchar_t)));

	if ((p = strchr(session->workstation, ' ')) != 0)
		*p = '\0';

	kmem_free(names, hdr.xh_length);
	return (smb_session_send(session, POSITIVE_SESSION_RESPONSE, NULL));
}

/*
 * Read 4-byte header from the session socket and build an in-memory
 * session transport header.  See smb_xprt_t definition for header
 * format information.
 *
 * Direct hosted NetBIOS-less SMB (SMB-over-TCP) uses port 445.  The
 * first byte of the four-byte header must be 0 and the next three
 * bytes contain the length of the remaining data.
 */
int
smb_session_xprt_gethdr(smb_session_t *session, smb_xprt_t *ret_hdr)
{
	int		rc;
	unsigned char	buf[NETBIOS_HDR_SZ];

	if ((rc = smb_sorecv(session->sock, buf, NETBIOS_HDR_SZ)) != 0)
		return (rc);

	switch (session->s_local_port) {
	case IPPORT_NETBIOS_SSN:
		ret_hdr->xh_type = buf[0];
		ret_hdr->xh_length = (((uint32_t)buf[1] & 1) << 16) |
		    ((uint32_t)buf[2] << 8) |
		    ((uint32_t)buf[3]);
		break;

	case IPPORT_SMB:
		ret_hdr->xh_type = buf[0];

		if (ret_hdr->xh_type != 0) {
			cmn_err(CE_WARN, "invalid NBT type (%u) from %s",
			    ret_hdr->xh_type, session->ip_addr_str);
			return (EPROTO);
		}

		ret_hdr->xh_length = ((uint32_t)buf[1] << 16) |
		    ((uint32_t)buf[2] << 8) |
		    ((uint32_t)buf[3]);
		break;

	default:
		cmn_err(CE_WARN, "invalid port %u", session->s_local_port);
		return (EPROTO);
	}

	return (0);
}

/*
 * Encode a transport session packet header into a 4-byte buffer.
 */
static int
smb_session_xprt_puthdr(smb_session_t *session,
    uint8_t msg_type, uint32_t msg_length,
    uint8_t *buf, size_t buflen)
{
	if (buf == NULL || buflen < NETBIOS_HDR_SZ) {
		return (-1);
	}

	switch (session->s_local_port) {
	case IPPORT_NETBIOS_SSN:
		/* Per RFC 1001, 1002: msg. len < 128KB */
		if (msg_length >= (1 << 17))
			return (-1);
		buf[0] = msg_type;
		buf[1] = ((msg_length >> 16) & 1);
		buf[2] = (msg_length >> 8) & 0xff;
		buf[3] = msg_length & 0xff;
		break;

	case IPPORT_SMB:
		/*
		 * SMB over TCP is like NetBIOS but the one byte
		 * message type is always zero, and the length
		 * part is three bytes.  It could actually use
		 * longer messages, but this is conservative.
		 */
		if (msg_length >= (1 << 24))
			return (-1);
		buf[0] = msg_type;
		buf[1] = (msg_length >> 16) & 0xff;
		buf[2] = (msg_length >> 8) & 0xff;
		buf[3] = msg_length & 0xff;
		break;

	default:
		cmn_err(CE_WARN, "invalid port %u", session->s_local_port);
		return (-1);
	}

	return (0);
}

static void
smb_request_init_command_mbuf(smb_request_t *sr)
{

	/*
	 * Setup mbuf using the buffer we allocated.
	 */
	MBC_ATTACH_BUF(&sr->command, sr->sr_request_buf, sr->sr_req_length);

	sr->command.flags = 0;
	sr->command.shadow_of = NULL;
}

/*
 * smb_request_cancel
 *
 * Handle a cancel for a request properly depending on the current request
 * state.  Return B_TRUE if a request was cancelled.
 *
 * SMB Cancel has an inherent race with the request being cancelled.
 * If a cancel is processed before the request being cancelled, that
 * request might not have been decoded yet and will not be found.
 *
 * When a client issues a cancel, we run it in two passes.  In the
 * "pass 0", we cancel a request in any of the "WAIT" states, or an
 * active request as long as it's had some time to run.  If the
 * request is cancelled in the first pass, we're done.  Otherwise,
 * the caller delays for smb_cancel_delay and calls "pass 1", where
 * we do our best to make the request complete soon.
 *
 * Usually, cancel arrives long after the request being cancelled,
 * and we're done after "pass 0".  However on rare occasion, we've
 * seen Windows send an SMB2 (sync) cancel shortly after a notify
 * request.  There are also some smbtorture "notify" test cases
 * that send notify requests "back to back" with a cancel, and
 * expect the notify to be processed.  Those situations cause a
 * delay and "pass 1" in the cancel handler.
 */
boolean_t
smb_request_cancel(smb_request_t *sr, int pass)
{
	void (*cancel_method)(smb_request_t *) = NULL;

	mutex_enter(&sr->sr_mutex);
	switch (sr->sr_state) {

	case SMB_REQ_STATE_INITIALIZING:
	case SMB_REQ_STATE_SUBMITTED:
		if (pass == 0) {
			mutex_exit(&sr->sr_mutex);
			return (B_FALSE);
		}
		sr->sr_state = SMB_REQ_STATE_CANCELLED;
		break;

	case SMB_REQ_STATE_ACTIVE:
	case SMB_REQ_STATE_CLEANED_UP:
		if (pass == 0 && gethrtime() <
		    (sr->sr_time_active + MSEC2NSEC(smb_cancel_delay))) {
			/* This SR is too young to die. */
			mutex_exit(&sr->sr_mutex);
			return (B_FALSE);
		}
		sr->sr_state = SMB_REQ_STATE_CANCELLED;
		break;

	case SMB_REQ_STATE_WAITING_AUTH:
	case SMB_REQ_STATE_WAITING_FCN1:
	case SMB_REQ_STATE_WAITING_LOCK:
	case SMB_REQ_STATE_WAITING_PIPE:
		/*
		 * These are states that have a cancel_method.
		 * Make the state change now, to ensure that
		 * we call cancel_method exactly once.  Do the
		 * method call below, after we drop sr_mutex.
		 * When the cancelled request thread resumes,
		 * it should re-take sr_mutex and set sr_state
		 * to CANCELLED, then return STATUS_CANCELLED.
		 */
		sr->sr_state = SMB_REQ_STATE_CANCEL_PENDING;
		cancel_method = sr->cancel_method;
		VERIFY(cancel_method != NULL);
		break;

	case SMB_REQ_STATE_WAITING_FCN2:
	case SMB_REQ_STATE_COMPLETED:
	case SMB_REQ_STATE_CANCEL_PENDING:
	case SMB_REQ_STATE_CANCELLED:
		/*
		 * No action required for these states since the request
		 * is completing.
		 */
		break;

	case SMB_REQ_STATE_FREE:
	default:
		SMB_PANIC();
	}
	mutex_exit(&sr->sr_mutex);

	if (cancel_method != NULL) {
		cancel_method(sr);
	}

	return (B_TRUE);
}

/*
 * smb_session_receiver
 *
 * Receives request from the network and dispatches them to a worker.
 */
void
smb_session_receiver(smb_session_t *session)
{
	int	rc = 0;

	SMB_SESSION_VALID(session);

	session->s_thread = curthread;

	if (session->s_local_port == IPPORT_NETBIOS_SSN) {
		rc = smb_netbios_session_request(session);
		if (rc != 0) {
			smb_rwx_rwenter(&session->s_lock, RW_WRITER);
			session->s_state = SMB_SESSION_STATE_DISCONNECTED;
			smb_rwx_rwexit(&session->s_lock);
			return;
		}
	}

	smb_rwx_rwenter(&session->s_lock, RW_WRITER);
	session->s_state = SMB_SESSION_STATE_ESTABLISHED;
	smb_rwx_rwexit(&session->s_lock);

	(void) smb_session_reader(session);

	smb_rwx_rwenter(&session->s_lock, RW_WRITER);
	session->s_state = SMB_SESSION_STATE_DISCONNECTED;
	session->logoff_time = gethrtime();
	smb_rwx_rwexit(&session->s_lock);

	smb_soshutdown(session->sock);

	DTRACE_PROBE2(session__drop, struct session *, session, int, rc);

	smb_session_cancel(session);
	/*
	 * At this point everything related to the session should have been
	 * cleaned up and we expect that nothing will attempt to use the
	 * socket.
	 */
}

/*
 * smb_session_disconnect
 *
 * Disconnects the session passed in.
 */
void
smb_session_disconnect(smb_session_t *session)
{
	SMB_SESSION_VALID(session);

	smb_rwx_rwenter(&session->s_lock, RW_WRITER);
	switch (session->s_state) {
	case SMB_SESSION_STATE_INITIALIZED:
	case SMB_SESSION_STATE_CONNECTED:
	case SMB_SESSION_STATE_ESTABLISHED:
	case SMB_SESSION_STATE_NEGOTIATED:
		smb_soshutdown(session->sock);
		session->s_state = SMB_SESSION_STATE_DISCONNECTED;
		_NOTE(FALLTHRU)
	case SMB_SESSION_STATE_DISCONNECTED:
	case SMB_SESSION_STATE_TERMINATED:
		break;
	}
	smb_rwx_rwexit(&session->s_lock);
}

/*
 * Read and process SMB requests.
 *
 * Returns:
 *	0	Success
 *	1	Unable to read transport header
 *	2	Invalid transport header type
 *	3	Invalid SMB length (too small)
 *	4	Unable to read SMB header
 *	5	Invalid SMB header (bad magic number)
 *	6	Unable to read SMB data
 */
static int
smb_session_reader(smb_session_t *session)
{
	smb_server_t	*sv;
	smb_request_t	*sr = NULL;
	smb_xprt_t	hdr;
	uint8_t		*req_buf;
	uint32_t	resid;
	int		rc;

	sv = session->s_server;

	for (;;) {

		rc = smb_session_xprt_gethdr(session, &hdr);
		if (rc)
			return (rc);

		DTRACE_PROBE2(session__receive__xprthdr, session_t *, session,
		    smb_xprt_t *, &hdr);

		if (hdr.xh_type != SESSION_MESSAGE) {
			/*
			 * Anything other than SESSION_MESSAGE or
			 * SESSION_KEEP_ALIVE is an error.  A SESSION_REQUEST
			 * may indicate a new session request but we need to
			 * close this session and we can treat it as an error
			 * here.
			 */
			if (hdr.xh_type == SESSION_KEEP_ALIVE) {
				session->keep_alive = smb_keep_alive;
				continue;
			}
			return (EPROTO);
		}

		if (hdr.xh_length == 0) {
			/* zero length is another form of keep alive */
			session->keep_alive = smb_keep_alive;
			continue;
		}

		if (hdr.xh_length < SMB_HEADER_LEN)
			return (EPROTO);
		if (hdr.xh_length > session->cmd_max_bytes)
			return (EPROTO);

		session->keep_alive = smb_keep_alive;

		/*
		 * Allocate a request context, read the whole message.
		 * If the request alloc fails, we've disconnected
		 * and won't be able to send the reply anyway, so bail now.
		 */
		if ((sr = smb_request_alloc(session, hdr.xh_length)) == NULL)
			break;

		req_buf = (uint8_t *)sr->sr_request_buf;
		resid = hdr.xh_length;

		rc = smb_sorecv(session->sock, req_buf, resid);
		if (rc) {
			smb_request_free(sr);
			break;
		}

		/* accounting: requests, received bytes */
		smb_server_inc_req(sv);
		smb_server_add_rxb(sv,
		    (int64_t)(hdr.xh_length + NETBIOS_HDR_SZ));

		/*
		 * Initialize command MBC to represent the received data.
		 */
		smb_request_init_command_mbuf(sr);

		DTRACE_PROBE1(session__receive__smb, smb_request_t *, sr);

		rc = session->newrq_func(sr);
		sr = NULL;	/* enqueued or freed */
		if (rc != 0)
			break;

		/* See notes where this is defined (above). */
		if (smb_reader_delay) {
			delay(MSEC_TO_TICK(smb_reader_delay));
		}
	}
	return (rc);
}

/*
 * This is the initial handler for new smb requests, called from
 * from smb_session_reader when we have not yet seen any requests.
 * The first SMB request must be "negotiate", which determines
 * which protocol and dialect we'll be using.  That's the ONLY
 * request type handled here, because with all later requests,
 * we know the protocol and handle those with either the SMB1 or
 * SMB2 handlers:  smb1sr_post() or smb2sr_post().
 * Those do NOT allow SMB negotiate, because that's only allowed
 * as the first request on new session.
 *
 * This and other "post a request" handlers must either enqueue
 * the new request for the session taskq, or smb_request_free it
 * (in case we've decided to drop this connection).  In this
 * (special) new request handler, we always free the request.
 */
static int
smbsr_newrq_initial(smb_request_t *sr)
{
	uint32_t magic;
	int rc = EPROTO;

	mutex_enter(&sr->sr_mutex);
	sr->sr_state = SMB_REQ_STATE_ACTIVE;
	mutex_exit(&sr->sr_mutex);

	magic = SMB_READ_PROTOCOL(sr->sr_request_buf);
	if (magic == SMB_PROTOCOL_MAGIC)
		rc = smb1_newrq_negotiate(sr);
	if (magic == SMB2_PROTOCOL_MAGIC)
		rc = smb2_newrq_negotiate(sr);

	mutex_enter(&sr->sr_mutex);
	sr->sr_state = SMB_REQ_STATE_COMPLETED;
	mutex_exit(&sr->sr_mutex);

	smb_request_free(sr);
	return (rc);
}

/*
 * Port will be IPPORT_NETBIOS_SSN or IPPORT_SMB.
 */
smb_session_t *
smb_session_create(ksocket_t new_so, uint16_t port, smb_server_t *sv,
    int family)
{
	struct sockaddr_in	sin;
	socklen_t		slen;
	struct sockaddr_in6	sin6;
	smb_session_t		*session;
	int64_t			now;
	uint16_t		rport;

	session = kmem_cache_alloc(smb_cache_session, KM_SLEEP);
	bzero(session, sizeof (smb_session_t));

	if (smb_idpool_constructor(&session->s_uid_pool)) {
		kmem_cache_free(smb_cache_session, session);
		return (NULL);
	}
	if (smb_idpool_constructor(&session->s_tid_pool)) {
		smb_idpool_destructor(&session->s_uid_pool);
		kmem_cache_free(smb_cache_session, session);
		return (NULL);
	}

	now = ddi_get_lbolt64();

	session->s_kid = SMB_NEW_KID();
	session->s_state = SMB_SESSION_STATE_INITIALIZED;
	session->native_os = NATIVE_OS_UNKNOWN;
	session->opentime = now;
	session->keep_alive = smb_keep_alive;
	session->activity_timestamp = now;
	session->s_refcnt = 1;
	smb_session_genkey(session);

	mutex_init(&session->s_credits_mutex, NULL, MUTEX_DEFAULT, NULL);

	smb_slist_constructor(&session->s_req_list, sizeof (smb_request_t),
	    offsetof(smb_request_t, sr_session_lnd));

	smb_llist_constructor(&session->s_user_list, sizeof (smb_user_t),
	    offsetof(smb_user_t, u_lnd));

	smb_llist_constructor(&session->s_tree_list, sizeof (smb_tree_t),
	    offsetof(smb_tree_t, t_lnd));

	smb_llist_constructor(&session->s_xa_list, sizeof (smb_xa_t),
	    offsetof(smb_xa_t, xa_lnd));

	smb_net_txl_constructor(&session->s_txlst);

	smb_rwx_init(&session->s_lock);

	if (new_so != NULL) {
		if (family == AF_INET) {
			slen = sizeof (sin);
			(void) ksocket_getsockname(new_so,
			    (struct sockaddr *)&sin, &slen, CRED());
			bcopy(&sin.sin_addr,
			    &session->local_ipaddr.au_addr.au_ipv4,
			    sizeof (in_addr_t));
			slen = sizeof (sin);
			(void) ksocket_getpeername(new_so,
			    (struct sockaddr *)&sin, &slen, CRED());
			bcopy(&sin.sin_addr,
			    &session->ipaddr.au_addr.au_ipv4,
			    sizeof (in_addr_t));
			rport = sin.sin_port;
		} else {
			slen = sizeof (sin6);
			(void) ksocket_getsockname(new_so,
			    (struct sockaddr *)&sin6, &slen, CRED());
			bcopy(&sin6.sin6_addr,
			    &session->local_ipaddr.au_addr.au_ipv6,
			    sizeof (in6_addr_t));
			slen = sizeof (sin6);
			(void) ksocket_getpeername(new_so,
			    (struct sockaddr *)&sin6, &slen, CRED());
			bcopy(&sin6.sin6_addr,
			    &session->ipaddr.au_addr.au_ipv6,
			    sizeof (in6_addr_t));
			rport = sin6.sin6_port;
		}
		session->ipaddr.a_family = family;
		session->local_ipaddr.a_family = family;
		session->s_local_port = port;
		session->s_remote_port = ntohs(rport);
		session->sock = new_so;
		(void) smb_inet_ntop(&session->ipaddr,
		    session->ip_addr_str, INET6_ADDRSTRLEN);
		if (port == IPPORT_NETBIOS_SSN)
			smb_server_inc_nbt_sess(sv);
		else
			smb_server_inc_tcp_sess(sv);
	}
	session->s_server = sv;
	smb_server_get_cfg(sv, &session->s_cfg);
	session->s_srqueue = &sv->sv_srqueue;

	/*
	 * The initial new request handler is special,
	 * and only accepts negotiation requests.
	 */
	session->newrq_func = smbsr_newrq_initial;

	/* These may increase in SMB2 negotiate. */
	session->cmd_max_bytes = SMB_REQ_MAX_SIZE;
	session->reply_max_bytes = SMB_REQ_MAX_SIZE;

	session_stats_init(sv, session);

	session->s_magic = SMB_SESSION_MAGIC;

	return (session);
}

void
session_stats_init(smb_server_t *sv, smb_session_t *ss)
{
	static const char	*kr_names[] = SMBSRV_CLSH__NAMES;
	char			ks_name[KSTAT_STRLEN];
	char			*ipaddr_str = ss->ip_addr_str;
	smbsrv_clsh_kstats_t	*ksr;
	int			idx;

	/* Don't include the special internal session (sv->sv_session). */
	if (ss->sock == NULL)
		return;

	/*
	 * If ipv6_enable is set to true, IPv4 addresses will be prefixed
	 * with ::ffff: (IPv4-mapped IPv6 address), strip it.
	 */
	if (strncasecmp(ipaddr_str, "::ffff:", 7) == 0)
		ipaddr_str += 7;

	/*
	 * Create raw kstats for sessions with a name composed as:
	 * cl/$IPADDR  and instance ss->s_kid
	 * These will look like: smbsrv:0:cl/10.10.0.5
	 */
	(void) snprintf(ks_name, sizeof (ks_name), "cl/%s", ipaddr_str);

	ss->s_ksp = kstat_create_zone(SMBSRV_KSTAT_MODULE, ss->s_kid,
	    ks_name, SMBSRV_KSTAT_CLASS, KSTAT_TYPE_RAW,
	    sizeof (smbsrv_clsh_kstats_t), 0, sv->sv_zid);

	if (ss->s_ksp == NULL)
		return;

	ss->s_ksp->ks_update = smb_session_kstat_update;
	ss->s_ksp->ks_private = ss;

	/*
	 * In-line equivalent of smb_dispatch_stats_init
	 */
	ksr = (smbsrv_clsh_kstats_t *)ss->s_ksp->ks_data;
	for (idx = 0; idx < SMBSRV_CLSH__NREQ; idx++) {
		smb_latency_init(&ss->s_stats[idx].sdt_lat);
		(void) strlcpy(ksr->ks_clsh[idx].kr_name, kr_names[idx],
		    KSTAT_STRLEN);
	}

	kstat_install(ss->s_ksp);
}

void
session_stats_fini(smb_session_t *ss)
{
	int	idx;

	for (idx = 0; idx < SMBSRV_CLSH__NREQ; idx++)
		smb_latency_destroy(&ss->s_stats[idx].sdt_lat);
}

/*
 * Update the kstat data from our private stats.
 */
static int
smb_session_kstat_update(kstat_t *ksp, int rw)
{
	smb_session_t *session;
	smb_disp_stats_t *sds;
	smbsrv_clsh_kstats_t	*clsh;
	smb_kstat_req_t	*ksr;
	int i;

	if (rw == KSTAT_WRITE)
		return (EACCES);

	session = ksp->ks_private;
	SMB_SESSION_VALID(session);
	sds = session->s_stats;

	clsh = (smbsrv_clsh_kstats_t *)ksp->ks_data;
	ksr = clsh->ks_clsh;

	for (i = 0; i < SMBSRV_CLSH__NREQ; i++, ksr++, sds++) {
		ksr->kr_rxb = sds->sdt_rxb;
		ksr->kr_txb = sds->sdt_txb;
		mutex_enter(&sds->sdt_lat.ly_mutex);
		ksr->kr_nreq = sds->sdt_lat.ly_a_nreq;
		ksr->kr_sum = sds->sdt_lat.ly_a_sum;
		ksr->kr_a_mean = sds->sdt_lat.ly_a_mean;
		ksr->kr_a_stddev = sds->sdt_lat.ly_a_stddev;
		ksr->kr_d_mean = sds->sdt_lat.ly_d_mean;
		ksr->kr_d_stddev = sds->sdt_lat.ly_d_stddev;
		sds->sdt_lat.ly_d_mean = 0;
		sds->sdt_lat.ly_d_nreq = 0;
		sds->sdt_lat.ly_d_stddev = 0;
		sds->sdt_lat.ly_d_sum = 0;
		mutex_exit(&sds->sdt_lat.ly_mutex);
	}

	return (0);
}

void
smb_session_delete(smb_session_t *session)
{

	ASSERT(session->s_magic == SMB_SESSION_MAGIC);

	if (session->s_ksp != NULL) {
		kstat_delete(session->s_ksp);
		session->s_ksp = NULL;
		session_stats_fini(session);
	}

	if (session->sign_fini != NULL)
		session->sign_fini(session);

	if (session->signing.mackey != NULL) {
		kmem_free(session->signing.mackey,
		    session->signing.mackey_len);
	}

	session->s_magic = 0;

	smb_rwx_destroy(&session->s_lock);
	smb_net_txl_destructor(&session->s_txlst);

	mutex_destroy(&session->s_credits_mutex);

	smb_slist_destructor(&session->s_req_list);
	smb_llist_destructor(&session->s_tree_list);
	smb_llist_destructor(&session->s_user_list);
	smb_llist_destructor(&session->s_xa_list);

	ASSERT(session->s_tree_cnt == 0);
	ASSERT(session->s_file_cnt == 0);
	ASSERT(session->s_dir_cnt == 0);

	smb_idpool_destructor(&session->s_tid_pool);
	smb_idpool_destructor(&session->s_uid_pool);
	if (session->sock != NULL) {
		if (session->s_local_port == IPPORT_NETBIOS_SSN)
			smb_server_dec_nbt_sess(session->s_server);
		else
			smb_server_dec_tcp_sess(session->s_server);
		smb_sodestroy(session->sock);
	}
	kmem_cache_free(smb_cache_session, session);
}

static void
smb_session_cancel(smb_session_t *session)
{
	smb_xa_t	*xa, *nextxa;

	/* All the request currently being treated must be canceled. */
	smb_session_cancel_requests(session, NULL, NULL);

	/*
	 * We wait for the completion of all the requests associated with
	 * this session.
	 */
	smb_slist_wait_for_empty(&session->s_req_list);

	/*
	 * At this point the reference count of the files and directories
	 * should be zero. It should be possible to destroy them without
	 * any problem, which should trigger the destruction of other objects.
	 */
	xa = smb_llist_head(&session->s_xa_list);
	while (xa) {
		nextxa = smb_llist_next(&session->s_xa_list, xa);
		smb_xa_close(xa);
		xa = nextxa;
	}

	/*
	 * do this here so that any request that causes handles
	 * to be closed before the connection was lost don't
	 * save durable handles accidentally
	 */
	if (session->s_server->sv_state == SMB_SERVER_STATE_RUNNING) {
		session->conn_lost = B_TRUE;
		session->logoff_time = gethrtime();
	}

	smb_session_logoff(session);
}

/*
 * Cancel requests.  If a non-null tree is specified, only requests specific
 * to that tree will be cancelled.  If a non-null sr is specified, that sr
 * will be not be cancelled - this would typically be the caller's sr.
 */
void
smb_session_cancel_requests(
    smb_session_t	*session,
    smb_tree_t		*tree,
    smb_request_t	*exclude_sr)
{
	smb_request_t	*sr;

	smb_slist_enter(&session->s_req_list);
	sr = smb_slist_head(&session->s_req_list);

	while (sr) {
		ASSERT(sr->sr_magic == SMB_REQ_MAGIC);
		if ((sr != exclude_sr) &&
		    (tree == NULL || sr->tid_tree == tree))
			(void) smb_request_cancel(sr, 1);

		sr = smb_slist_next(&session->s_req_list, sr);
	}

	smb_slist_exit(&session->s_req_list);
}

/*
 * Find a user on the specified session by SMB UID.
 */
smb_user_t *
smb_session_lookup_uid(smb_session_t *session, uint16_t uid)
{
	return (smb_session_lookup_uid_st(session, 0, uid,
	    SMB_USER_STATE_LOGGED_ON));
}

/*
 * Find a user on the specified session by SMB2 SSNID.
 */
smb_user_t *
smb_session_lookup_ssnid(smb_session_t *session, uint64_t ssnid)
{
	return (smb_session_lookup_uid_st(session, ssnid, 0,
	    SMB_USER_STATE_LOGGED_ON));
}

smb_user_t *
smb_session_lookup_uid_st(smb_session_t *session, uint64_t ssnid,
    uint16_t uid, smb_user_state_t st)
{
	smb_user_t	*user;
	smb_llist_t	*user_list;

	SMB_SESSION_VALID(session);

	user_list = &session->s_user_list;
	smb_llist_enter(user_list, RW_READER);

	user = smb_llist_head(user_list);
	while (user) {
		SMB_USER_VALID(user);
		ASSERT(user->u_session == session);

		if ((user->u_ssnid == ssnid || user->u_uid == uid) &&
		    user->u_state == st) {
			smb_user_hold_internal(user);
			break;
		}

		user = smb_llist_next(user_list, user);
	}

	smb_llist_exit(user_list);
	return (user);
}

void
smb_session_post_user(smb_session_t *session, smb_user_t *user)
{
	SMB_USER_VALID(user);
	ASSERT(user->u_refcnt == 0);
	ASSERT(user->u_state == SMB_USER_STATE_LOGGED_OFF);
	ASSERT(user->u_session == session);

	smb_llist_post(&session->s_user_list, user, smb_user_delete);
}

/*
 * Find a tree by tree-id.
 */
smb_tree_t *
smb_session_lookup_tree(
    smb_session_t	*session,
    uint16_t		tid)
{
	smb_tree_t	*tree;

	SMB_SESSION_VALID(session);

	smb_llist_enter(&session->s_tree_list, RW_READER);
	tree = smb_llist_head(&session->s_tree_list);

	while (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);

		if (tree->t_tid == tid) {
			if (smb_tree_hold(tree)) {
				smb_llist_exit(&session->s_tree_list);
				return (tree);
			} else {
				smb_llist_exit(&session->s_tree_list);
				return (NULL);
			}
		}

		tree = smb_llist_next(&session->s_tree_list, tree);
	}

	smb_llist_exit(&session->s_tree_list);
	return (NULL);
}

/*
 * Find the first connected tree that matches the specified sharename.
 * If the specified tree is NULL the search starts from the beginning of
 * the user's tree list.  If a tree is provided the search starts just
 * after that tree.
 */
smb_tree_t *
smb_session_lookup_share(
    smb_session_t	*session,
    const char		*sharename,
    smb_tree_t		*tree)
{
	SMB_SESSION_VALID(session);
	ASSERT(sharename);

	smb_llist_enter(&session->s_tree_list, RW_READER);

	if (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		tree = smb_llist_next(&session->s_tree_list, tree);
	} else {
		tree = smb_llist_head(&session->s_tree_list);
	}

	while (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		if (smb_strcasecmp(tree->t_sharename, sharename, 0) == 0) {
			if (smb_tree_hold(tree)) {
				smb_llist_exit(&session->s_tree_list);
				return (tree);
			}
		}
		tree = smb_llist_next(&session->s_tree_list, tree);
	}

	smb_llist_exit(&session->s_tree_list);
	return (NULL);
}

/*
 * Find the first connected tree that matches the specified volume name.
 * If the specified tree is NULL the search starts from the beginning of
 * the user's tree list.  If a tree is provided the search starts just
 * after that tree.
 */
smb_tree_t *
smb_session_lookup_volume(
    smb_session_t	*session,
    const char		*name,
    smb_tree_t		*tree)
{
	SMB_SESSION_VALID(session);
	ASSERT(name);

	smb_llist_enter(&session->s_tree_list, RW_READER);

	if (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		tree = smb_llist_next(&session->s_tree_list, tree);
	} else {
		tree = smb_llist_head(&session->s_tree_list);
	}

	while (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);

		if (smb_strcasecmp(tree->t_volume, name, 0) == 0) {
			if (smb_tree_hold(tree)) {
				smb_llist_exit(&session->s_tree_list);
				return (tree);
			}
		}

		tree = smb_llist_next(&session->s_tree_list, tree);
	}

	smb_llist_exit(&session->s_tree_list);
	return (NULL);
}

/*
 * Disconnect all trees that match the specified client process-id.
 */
void
smb_session_close_pid(
    smb_session_t	*session,
    uint32_t		pid)
{
	smb_tree_t	*tree;

	SMB_SESSION_VALID(session);

	tree = smb_session_get_tree(session, NULL);
	while (tree) {
		smb_tree_t *next;
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		smb_tree_close_pid(tree, pid);
		next = smb_session_get_tree(session, tree);
		smb_tree_release(tree);
		tree = next;
	}
}

static void
smb_session_tree_dtor(void *t)
{
	smb_tree_t	*tree = (smb_tree_t *)t;

	smb_tree_disconnect(tree, B_TRUE);
	/* release the ref acquired during the traversal loop */
	smb_tree_release(tree);
}


/*
 * Disconnect all trees that this user has connected.
 */
void
smb_session_disconnect_owned_trees(
    smb_session_t	*session,
    smb_user_t		*owner)
{
	smb_tree_t	*tree;
	smb_llist_t	*tree_list = &session->s_tree_list;

	SMB_SESSION_VALID(session);
	SMB_USER_VALID(owner);

	smb_llist_enter(tree_list, RW_READER);

	tree = smb_llist_head(tree_list);
	while (tree) {
		if ((tree->t_owner == owner) &&
		    smb_tree_hold(tree)) {
			/*
			 * smb_tree_hold() succeeded, hence we are in state
			 * SMB_TREE_STATE_CONNECTED; schedule this tree
			 * for asynchronous disconnect, which will fire
			 * after we drop the llist traversal lock.
			 */
			smb_llist_post(tree_list, tree, smb_session_tree_dtor);
		}
		tree = smb_llist_next(tree_list, tree);
	}

	/* drop the lock and flush the dtor queue */
	smb_llist_exit(tree_list);
}

/*
 * Disconnect all trees that this user has connected.
 */
void
smb_session_disconnect_trees(
    smb_session_t	*session)
{
	smb_tree_t	*tree, *next_tree;

	SMB_SESSION_VALID(session);

	tree = smb_session_get_tree(session, NULL);
	while (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		smb_tree_disconnect(tree, B_TRUE);
		next_tree = smb_session_get_tree(session, tree);
		smb_tree_release(tree);
		tree = next_tree;
	}
}

/*
 * Disconnect all trees that match the specified share name.
 */
void
smb_session_disconnect_share(
    smb_session_t	*session,
    const char		*sharename)
{
	smb_tree_t	*tree;
	smb_tree_t	*next;

	SMB_SESSION_VALID(session);

	tree = smb_session_lookup_share(session, sharename, NULL);
	while (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		ASSERT(tree->t_session == session);
		smb_tree_disconnect(tree, B_TRUE);
		smb_session_cancel_requests(session, tree, NULL);
		next = smb_session_lookup_share(session, sharename, tree);
		smb_tree_release(tree);
		tree = next;
	}
	smb_llist_flush(&session->s_tree_list);
}

void
smb_session_post_tree(smb_session_t *session, smb_tree_t *tree)
{
	SMB_SESSION_VALID(session);
	SMB_TREE_VALID(tree);
	ASSERT0(tree->t_refcnt);
	ASSERT(tree->t_state == SMB_TREE_STATE_DISCONNECTED);
	ASSERT(tree->t_session == session);

	smb_llist_post(&session->s_tree_list, tree, smb_tree_dealloc);
}

/*
 * Get the next connected tree in the list.  A reference is taken on
 * the tree, which can be released later with smb_tree_release().
 *
 * If the specified tree is NULL the search starts from the beginning of
 * the tree list.  If a tree is provided the search starts just after
 * that tree.
 *
 * Returns NULL if there are no connected trees in the list.
 */
static smb_tree_t *
smb_session_get_tree(
    smb_session_t	*session,
    smb_tree_t		*tree)
{
	smb_llist_t	*tree_list;

	SMB_SESSION_VALID(session);
	tree_list = &session->s_tree_list;

	smb_llist_enter(tree_list, RW_READER);

	if (tree) {
		ASSERT3U(tree->t_magic, ==, SMB_TREE_MAGIC);
		tree = smb_llist_next(tree_list, tree);
	} else {
		tree = smb_llist_head(tree_list);
	}

	while (tree) {
		if (smb_tree_hold(tree))
			break;

		tree = smb_llist_next(tree_list, tree);
	}

	smb_llist_exit(tree_list);
	return (tree);
}

/*
 * Logoff all users associated with the specified session.
 */
static void
smb_session_logoff(smb_session_t *session)
{
	smb_user_t	*user;

	SMB_SESSION_VALID(session);

	smb_session_disconnect_trees(session);

	smb_llist_enter(&session->s_user_list, RW_READER);

	user = smb_llist_head(&session->s_user_list);
	while (user) {
		SMB_USER_VALID(user);
		ASSERT(user->u_session == session);

		switch (user->u_state) {
		case SMB_USER_STATE_LOGGING_ON:
		case SMB_USER_STATE_LOGGED_ON:
			smb_user_hold_internal(user);
			smb_user_logoff(user);
			smb_user_release(user);
			break;

		case SMB_USER_STATE_LOGGED_OFF:
		case SMB_USER_STATE_LOGGING_OFF:
			break;

		default:
			ASSERT(0);
			break;
		}

		user = smb_llist_next(&session->s_user_list, user);
	}

	smb_llist_exit(&session->s_user_list);
}

/*
 * Copy the session workstation/client name to buf.  If the workstation
 * is an empty string (which it will be on TCP connections), use the
 * client IP address.
 */
void
smb_session_getclient(smb_session_t *sn, char *buf, size_t buflen)
{

	*buf = '\0';

	if (sn->workstation[0] != '\0') {
		(void) strlcpy(buf, sn->workstation, buflen);
		return;
	}

	(void) strlcpy(buf, sn->ip_addr_str, buflen);
}

/*
 * Check whether or not the specified client name is the client of this
 * session.  The name may be in UNC format (\\CLIENT).
 *
 * A workstation/client name is setup on NBT connections as part of the
 * NetBIOS session request but that isn't available on TCP connections.
 * If the session doesn't have a client name we typically return the
 * client IP address as the workstation name on MSRPC requests.  So we
 * check for the IP address here in addition to the workstation name.
 */
boolean_t
smb_session_isclient(smb_session_t *sn, const char *client)
{

	client += strspn(client, "\\");

	if (smb_strcasecmp(client, sn->workstation, 0) == 0)
		return (B_TRUE);

	if (smb_strcasecmp(client, sn->ip_addr_str, 0) == 0)
		return (B_TRUE);

	return (B_FALSE);
}

/*
 * smb_request_alloc
 *
 * Allocate an smb_request_t structure from the kmem_cache.  Partially
 * initialize the found/new request.
 *
 * Returns pointer to a request, or NULL if the session state is
 * one in which new requests are no longer allowed.
 */
smb_request_t *
smb_request_alloc(smb_session_t *session, int req_length)
{
	smb_request_t	*sr;

	ASSERT(session->s_magic == SMB_SESSION_MAGIC);
	ASSERT(req_length <= session->cmd_max_bytes);

	sr = kmem_cache_alloc(smb_cache_request, KM_SLEEP);

	/*
	 * Future:  Use constructor to pre-initialize some fields.  For now
	 * there are so many fields that it is easiest just to zero the
	 * whole thing and start over.
	 */
	bzero(sr, sizeof (smb_request_t));

	mutex_init(&sr->sr_mutex, NULL, MUTEX_DEFAULT, NULL);
	smb_srm_init(sr);
	sr->session = session;
	sr->sr_server = session->s_server;
	sr->sr_gmtoff = session->s_server->si_gmtoff;
	sr->sr_cfg = &session->s_cfg;
	sr->command.max_bytes = req_length;
	sr->reply.max_bytes = session->reply_max_bytes;
	sr->sr_req_length = req_length;
	if (req_length)
		sr->sr_request_buf = kmem_alloc(req_length, KM_SLEEP);
	sr->sr_magic = SMB_REQ_MAGIC;
	sr->sr_state = SMB_REQ_STATE_INITIALIZING;

	/*
	 * Only allow new SMB requests in some states.
	 */
	smb_rwx_rwenter(&session->s_lock, RW_WRITER);
	switch (session->s_state) {
	case SMB_SESSION_STATE_CONNECTED:
	case SMB_SESSION_STATE_INITIALIZED:
	case SMB_SESSION_STATE_ESTABLISHED:
	case SMB_SESSION_STATE_NEGOTIATED:
		smb_slist_insert_tail(&session->s_req_list, sr);
		/* Internal smb_session_hold, as we have s_lock */
		session->s_refcnt++;
		break;

	default:
		ASSERT(0);
		/* FALLTHROUGH */
	case SMB_SESSION_STATE_DURABLE:
	case SMB_SESSION_STATE_DISCONNECTED:
	case SMB_SESSION_STATE_SHUTDOWN:
	case SMB_SESSION_STATE_TERMINATED:
		/* Disallow new requests in these states. */
		if (sr->sr_request_buf)
			kmem_free(sr->sr_request_buf, sr->sr_req_length);
		sr->session = NULL;
		sr->sr_magic = 0;
		mutex_destroy(&sr->sr_mutex);
		kmem_cache_free(smb_cache_request, sr);
		sr = NULL;
		break;
	}
	smb_rwx_rwexit(&session->s_lock);

	return (sr);
}

/*
 * smb_request_free
 *
 * release the memories which have been allocated for a smb request.
 */
void
smb_request_free(smb_request_t *sr)
{
	ASSERT(sr->sr_magic == SMB_REQ_MAGIC);
	ASSERT(sr->session);
	ASSERT(sr->r_xa == NULL);

	if (sr->fid_ofile != NULL) {
		smb_ofile_request_complete(sr->fid_ofile);
		smb_ofile_release(sr->fid_ofile);
	}

	if (sr->tid_tree != NULL)
		smb_tree_release(sr->tid_tree);

	if (sr->uid_user != NULL)
		smb_user_release(sr->uid_user);

	smb_slist_remove(&sr->session->s_req_list, sr);
	smb_session_release(sr->session);
	sr->session = NULL;

	smb_srm_fini(sr);

	if (sr->sr_request_buf)
		kmem_free(sr->sr_request_buf, sr->sr_req_length);
	if (sr->command.chain)
		m_freem(sr->command.chain);
	if (sr->reply.chain)
		m_freem(sr->reply.chain);
	if (sr->raw_data.chain)
		m_freem(sr->raw_data.chain);

	sr->sr_magic = 0;
	mutex_destroy(&sr->sr_mutex);
	kmem_cache_free(smb_cache_request, sr);
}

boolean_t
smb_session_oplocks_enable(smb_session_t *session)
{
	SMB_SESSION_VALID(session);
	if (session->s_cfg.skc_oplock_enable == 0)
		return (B_FALSE);
	else
		return (B_TRUE);
}

boolean_t
smb_session_levelII_oplocks(smb_session_t *session)
{
	SMB_SESSION_VALID(session);

	/* Clients using SMB2 and later always know about oplocks. */
	if (session->dialect > NT_LM_0_12)
		return (B_TRUE);

	/* Older clients only do Level II oplocks if negotiated. */
	if ((session->capabilities & CAP_LEVEL_II_OPLOCKS) != 0)
		return (B_TRUE);

	return (B_FALSE);
}

static void
smb_session_genkey(smb_session_t *session)
{
	uint8_t		tmp_key[SMB_CHALLENGE_SZ];

	(void) random_get_pseudo_bytes(tmp_key, SMB_CHALLENGE_SZ);
	bcopy(tmp_key, &session->challenge_key, SMB_CHALLENGE_SZ);
	session->challenge_len = SMB_CHALLENGE_SZ;

	(void) random_get_pseudo_bytes(tmp_key, 4);
	session->sesskey = tmp_key[0] | tmp_key[1] << 8 |
	    tmp_key[2] << 16 | tmp_key[3] << 24;
}

void
smb_session_hold(smb_session_t *sess)
{
	SMB_SESSION_VALID(sess);

	smb_rwx_rwenter(&sess->s_lock, RW_WRITER);
	ASSERT(sess->s_state != SMB_SESSION_STATE_SHUTDOWN);
	sess->s_refcnt++;
	smb_rwx_rwexit(&sess->s_lock);
}

void
smb_session_release(smb_session_t *sess)
{
	ASSERT(sess->s_magic == SMB_SESSION_MAGIC);

	smb_rwx_rwenter(&sess->s_lock, RW_WRITER);
	ASSERT(sess->s_refcnt);
	sess->s_refcnt--;

	switch (sess->s_state) {
	case SMB_SESSION_STATE_DISCONNECTED:
	case SMB_SESSION_STATE_DURABLE:
		if (sess->s_refcnt == 0) {
			sess->s_state = SMB_SESSION_STATE_SHUTDOWN;
			smb_server_post_session(sess);
		}
		break;
	case SMB_SESSION_STATE_SHUTDOWN:
	case SMB_SESSION_STATE_TERMINATED:
	case SMB_SESSION_STATE_CONNECTED:
	case SMB_SESSION_STATE_INITIALIZED:
	case SMB_SESSION_STATE_ESTABLISHED:
	case SMB_SESSION_STATE_NEGOTIATED:
		break;

	default:
		ASSERT(0);
		break;
	}
	smb_rwx_rwexit(&sess->s_lock);
}
