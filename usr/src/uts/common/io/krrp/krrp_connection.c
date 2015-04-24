/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <sys/strsubr.h>
#include <sys/socketvar.h>
#include <sys/filio.h>

#include "krrp_connection.h"

/* #define KRRP_CONN_DEBUG 1 */

/* Interval in us */
#define	KRRP_THROTTLE_INTERVAL_US 10 * MILLISEC

#define	krrp_conn_callback(conn, ev, ev_arg) \
	(conn)->callback((void *) conn, ev, \
	(uintptr_t) ev_arg, (conn)->callback_arg)

typedef struct {
	kmutex_t	mtx;
	kcondvar_t	cv;
	int			rc;
	boolean_t	cb_done;
} krrp_conn_connect_timeout_t;

static void krrp_conn_throttle_init(krrp_throttle_t *throttle);
static void krrp_conn_throttle_fini(krrp_throttle_t *throttle);
static void krrp_conn_throttle_enable(krrp_throttle_t *throttle);
static void krrp_conn_throttle_disable(krrp_throttle_t *throttle);
static void krrp_conn_throttle_cb(void *void_throttle);
static void krrp_conn_throttle(krrp_throttle_t *throttle, size_t send_sz);

static int krrp_conn_post_create(krrp_conn_t *conn, krrp_error_t *error);
static int krrp_conn_connect(krrp_conn_t *conn, const char *host,
    int port, int timeout, krrp_error_t *error);
static int krrp_conn_connect_with_timeout(ksocket_t ks,
    struct sockaddr *servaddr, int timeout, krrp_error_t *error);
void krrp_conn_connect_cb(ksocket_t ks,
    ksocket_callback_event_t ev, void *arg, uintptr_t info);
static int krrp_conn_post_configure(krrp_conn_t *conn, krrp_error_t *error);

static void krrp_conn_tx_handler(void *void_conn);
static void krrp_conn_rx_handler(void *void_conn);

static void krrp_conn_process_received_pdu(krrp_conn_t *conn,
    krrp_pdu_t *pdu);

static int krrp_conn_tx_pdu(krrp_conn_t *conn, krrp_pdu_t *pdu,
    krrp_error_t *error);
static int krrp_conn_tx(ksocket_t ks, void *buff, size_t buff_sz,
    krrp_error_t *error);
static int krrp_conn_tx_mblk(ksocket_t ks, mblk_t *mp, krrp_error_t *error);
static int krrp_conn_tx_ctrl_pdu_dblk(krrp_conn_t *conn, krrp_dblk_t *dblk,
    krrp_error_t *error);
static int krrp_conn_tx_data_pdu_dblk(krrp_conn_t *conn, krrp_dblk_t **dblk,
    krrp_error_t *error);
static void krrp_conn_dblk_to_mblk(krrp_dblk_t *dblk, mblk_t **result_mp,
    size_t wroff, size_t tail_len);

static int krrp_conn_rx_header(krrp_conn_t *, krrp_hdr_t **, krrp_error_t *);
static int krrp_conn_rx_pdu(krrp_conn_t *, krrp_pdu_t *, krrp_error_t *);
static int krrp_conn_rx(ksocket_t ks, void *, size_t, krrp_error_t *);

int
krrp_conn_create_from_scratch(krrp_conn_t **result_conn,
    const char *address, int port, int timeout, krrp_error_t *error)
{
	krrp_conn_t *conn = NULL;

	VERIFY(result_conn != NULL && *result_conn == NULL);
	VERIFY(address != NULL);
	VERIFY(port > 0 && port < 65535);

	conn = kmem_zalloc(sizeof (krrp_conn_t), KM_SLEEP);

	if (krrp_conn_connect(conn, address, port, timeout, error) != 0)
		goto fail;

	if (krrp_conn_post_create(conn, error) != 0)
		goto fail;

	*result_conn = conn;
	return (0);

fail:
	if (conn->ks != NULL)
		(void) ksocket_close(conn->ks, CRED());

	kmem_free(conn, sizeof (krrp_conn_t));
	return (-1);
}

/* ARGSUSED */
int
krrp_conn_create_from_ksocket(krrp_conn_t **result_conn,
    ksocket_t ks, krrp_error_t *error)
{
	krrp_conn_t *conn = NULL;

	VERIFY(result_conn != NULL && *result_conn == NULL);

	conn = kmem_zalloc(sizeof (krrp_conn_t), KM_SLEEP);

	conn->ks = ks;

	if (krrp_conn_post_create(conn, error) != 0) {
		kmem_free(conn, sizeof (krrp_conn_t));
		return (-1);
	}

	*result_conn = conn;

	return (0);
}

void
krrp_conn_destroy(krrp_conn_t *conn)
{
	mutex_enter(&conn->mtx);

	conn->state = KRRP_CS_DISCONNECTING;
	conn->tx_running = B_FALSE;
	conn->rx_running = B_FALSE;
	mutex_exit(&conn->mtx);

	krrp_conn_throttle_disable(&conn->throttle);

	if (conn->ks != NULL)
		(void) ksocket_close(conn->ks, CRED());

	if (conn->tx_t_did != 0)
		thread_join(conn->tx_t_did);

	if (conn->rx_t_did)
		thread_join(conn->rx_t_did);

	mutex_enter(&conn->mtx);
	conn->state = KRRP_CS_DISCONNECTED;
	mutex_exit(&conn->mtx);

	krrp_conn_throttle_fini(&conn->throttle);

	cv_destroy(&conn->cv);

	mutex_destroy(&conn->mtx);

	kmem_free(conn, sizeof (krrp_conn_t));
}

void
krrp_conn_register_callback(krrp_conn_t *conn,
    krrp_conn_cb_t *ev_cb, void *cb_arg)
{
	VERIFY(ev_cb != NULL);

	mutex_enter(&conn->mtx);
	VERIFY(conn->state == KRRP_CS_CONNECTED);

	conn->state = KRRP_CS_READY_TO_RUN;
	conn->callback = ev_cb;
	conn->callback_arg = cb_arg;

	mutex_exit(&conn->mtx);
}

void
krrp_conn_run(krrp_conn_t *conn, krrp_queue_t *ctrl_tx_queue,
    krrp_pdu_engine_t *data_pdu_engine,
    krrp_get_data_pdu_cb_t *get_data_pdu_cb, void *cb_arg)
{
	VERIFY(ctrl_tx_queue != NULL);
	VERIFY(data_pdu_engine != NULL);
	VERIFY(data_pdu_engine->type == KRRP_PET_DATA);

	mutex_enter(&conn->mtx);
	VERIFY(conn->state == KRRP_CS_READY_TO_RUN);

	conn->data_pdu_engine = data_pdu_engine;
	conn->ctrl_tx_queue = ctrl_tx_queue;
	conn->get_data_pdu_cb = get_data_pdu_cb;
	conn->get_data_pdu_cb_arg = cb_arg;

	conn->state = KRRP_CS_ACTIVE;

	conn->tx_running = B_TRUE;
	conn->rx_running = B_TRUE;

	krrp_conn_throttle_enable(&conn->throttle);

	/* thread_create never fails */
	(void) thread_create(NULL, 0, &krrp_conn_tx_handler,
		(void *) conn, 0, &p0, TS_RUN, minclsyspri);

	/* thread_create never fails */
	(void) thread_create(NULL, 0, &krrp_conn_rx_handler,
	    (void *) conn, 0, &p0, TS_RUN, minclsyspri);

	mutex_exit(&conn->mtx);
}

void
krrp_conn_stop(krrp_conn_t *conn)
{
	mutex_enter(&conn->mtx);
	VERIFY3U(conn->state, ==, KRRP_CS_ACTIVE);
	conn->state = KRRP_CS_STOPPED;
	conn->tx_running = B_FALSE;
	conn->rx_running = B_FALSE;
	mutex_exit(&conn->mtx);
}

int
krrp_conn_send_ctrl_data(krrp_conn_t *conn, krrp_opcode_t opcode,
    nvlist_t *nvl, krrp_error_t *error)
{
	krrp_pdu_ctrl_t *pdu = NULL;
	int rc = -1;

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu != NULL) {
		pdu->hdr->opcode = (uint16_t) opcode;

		if (nvl != NULL) {
			size_t packed_size = 0;

			/*
			 * fnvlist_size cannot be used, because it uses
			 * hardcoded encode-type == NV_ENCODE_NATIVE
			 */
			VERIFY3U(nvlist_size(nvl, &packed_size,
				NV_ENCODE_XDR), ==, 0);

			VERIFY3U(packed_size, <, pdu->dblk->max_data_sz);

			/*
			 * fnvlist_pack cannot be used,
			 * because cannot work with preallocated buffers,
			 * so just reimplement it here
			 */
			VERIFY3U(nvlist_pack(nvl, (char **) &pdu->dblk->data,
			    &packed_size, NV_ENCODE_XDR, KM_SLEEP), ==, 0);

			pdu->dblk->cur_data_sz = packed_size;
			pdu->hdr->payload_sz = (uint32_t) packed_size;
		}

		rc = krrp_conn_tx_ctrl_pdu(conn, pdu, error);
		krrp_pdu_rele((krrp_pdu_t *) pdu);
	} else
		krrp_error_set(error, KRRP_ERRNO_NOMEM, 0);

	return (rc);
}

int
krrp_conn_rx_ctrl_pdu(krrp_conn_t *conn, krrp_pdu_ctrl_t **result_pdu,
    krrp_error_t *error)
{
	krrp_pdu_ctrl_t *pdu = NULL;

	VERIFY(conn != NULL);
	VERIFY(result_pdu != NULL && *result_pdu == NULL);

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		krrp_error_set(error, KRRP_ERRNO_NOMEM, 0);
		return (-1);
	}

	if (krrp_conn_rx_header(conn, (krrp_hdr_t **) &pdu->hdr, error) != 0)
		goto err;

	if (krrp_conn_rx_pdu(conn, (krrp_pdu_t *) pdu, error) != 0)
		goto err;

	*result_pdu = pdu;

	return (0);

err:
	krrp_pdu_rele((krrp_pdu_t *) pdu);
	return (-1);
}

int
krrp_conn_tx_ctrl_pdu(krrp_conn_t *conn, krrp_pdu_ctrl_t *pdu,
    krrp_error_t *error)
{
	int rc;

	VERIFY(conn != NULL);
	VERIFY(pdu != NULL);

	rc = krrp_conn_tx(conn->ks, (void *) pdu->hdr,
	    sizeof (krrp_hdr_t), error);
	if (rc != 0)
		return (rc);

	conn->bytes_tx += sizeof (krrp_hdr_t);
	rc = krrp_conn_tx_ctrl_pdu_dblk(conn, pdu->dblk, error);
	if (rc == 0)
		conn->bytes_tx += sizeof (krrp_hdr_t);

	return (rc);
}

static int
krrp_conn_post_create(krrp_conn_t *conn, krrp_error_t *error)
{
	if (krrp_conn_post_configure(conn, error) != 0)
		return (-1);

	krrp_conn_throttle_init(&conn->throttle);

	mutex_init(&conn->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&conn->cv, NULL, CV_DEFAULT, NULL);

	conn->state = KRRP_CS_CONNECTED;
	return (0);
}

static void
krrp_conn_throttle_init(krrp_throttle_t *throttle)
{
	mutex_init(&throttle->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&throttle->cv, NULL, CV_DEFAULT, NULL);
}

static void
krrp_conn_throttle_fini(krrp_throttle_t *throttle)
{
	cv_destroy(&throttle->cv);
	mutex_destroy(&throttle->mtx);
}

static void
krrp_conn_throttle_enable(krrp_throttle_t *throttle)
{
	mutex_enter(&throttle->mtx);

	if (throttle->limit != 0)
		throttle->timer = timeout(&krrp_conn_throttle_cb,
			(void *) throttle,
		    drv_usectohz(KRRP_THROTTLE_INTERVAL_US));

	mutex_exit(&throttle->mtx);
}

static void
krrp_conn_throttle_disable(krrp_throttle_t *throttle)
{
	timeout_id_t saved_timer;

	mutex_enter(&throttle->mtx);
	saved_timer = throttle->timer;
	throttle->timer = NULL;
	throttle->limit = 0;
	cv_signal(&throttle->cv);
	mutex_exit(&throttle->mtx);

	if (saved_timer != NULL)
		(void) untimeout(saved_timer);
}

static void
krrp_conn_throttle_cb(void *void_throttle)
{
	krrp_throttle_t *throttle = (krrp_throttle_t *) void_throttle;

	mutex_enter(&throttle->mtx);
	if (throttle->limit == 0)
		throttle->remains = SIZE_MAX;
	else
		throttle->remains = throttle->limit;

	if (throttle->timer != NULL)
		throttle->timer = timeout(&krrp_conn_throttle_cb,
			(void *) throttle,
		    drv_usectohz(KRRP_THROTTLE_INTERVAL_US));

	cv_signal(&throttle->cv);
	mutex_exit(&throttle->mtx);
}

static void
krrp_conn_throttle(krrp_throttle_t *throttle, size_t send_sz)
{
	if (throttle->limit == 0)
		return;

	mutex_enter(&throttle->mtx);

	while (throttle->remains == 0 && throttle->limit != 0)
		cv_wait(&throttle->cv, &throttle->mtx);

	if (throttle->remains > send_sz)
		throttle->remains -= send_sz;
	else
		throttle->remains = 0;

	mutex_exit(&throttle->mtx);
}

void
krrp_conn_throttle_set(krrp_conn_t *conn, size_t new_limit)
{
	boolean_t require_enable = B_FALSE;
	krrp_throttle_t *throttle = &conn->throttle;

	/*
	 * We update "remains" each 10ms, so need to
	 * calculate limit according to this logic
	 */

	new_limit /= 100;

	if (new_limit == 0)
		krrp_conn_throttle_disable(throttle);
	else {
		mutex_enter(&throttle->mtx);
		if (throttle->limit == 0)
			require_enable = B_TRUE;

		throttle->limit = new_limit;
		mutex_exit(&throttle->mtx);

		if (require_enable)
			krrp_conn_throttle_enable(throttle);
	}
}

static int
krrp_conn_connect(krrp_conn_t *conn, const char *host,
    int port, int timeout, krrp_error_t *error)
{
	int rc;
	struct sockaddr_in servaddr;

	VERIFY(host != NULL);
	VERIFY(port > 0 && port < 65535);
	VERIFY(timeout >= 5 && timeout <= 120);

	(void) memset(&servaddr, 0, sizeof (servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_port = htons(port);
	if (inet_pton(AF_INET, (char *) host, &servaddr.sin_addr) != 1) {
		krrp_error_set(error, KRRP_ERRNO_ADDR, EINVAL);
		return (-1);
	}

	rc = ksocket_socket(&conn->ks, AF_INET, SOCK_STREAM, 0,
	    KSOCKET_SLEEP, CRED());
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_CREATEFAIL, rc);
		return (-1);
	}

	rc = krrp_conn_connect_with_timeout(conn->ks,
	    (struct sockaddr *) &servaddr,
	    timeout, error);
	if (rc != 0) {
		(void) ksocket_close(conn->ks, CRED());
		conn->ks = NULL;
	}

	return (rc);
}

static int
krrp_conn_connect_with_timeout(ksocket_t ks, struct sockaddr *servaddr,
    int timeout, krrp_error_t *error)
{
	int rc, nonblocking, rval = 0;
	ksocket_callbacks_t	ks_cb;
	krrp_conn_connect_timeout_t ct;

	nonblocking = 1;
	rc = ksocket_ioctl(ks, FIONBIO, (intptr_t) &nonblocking,
	    &rval, CRED());
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SETSOCKOPTFAIL, rc);
		goto out;
	}

	ks_cb.ksock_cb_flags = KSOCKET_CB_CONNECTED |
	    KSOCKET_CB_CONNECTFAILED | KSOCKET_CB_DISCONNECTED;
	ks_cb.ksock_cb_connected = &krrp_conn_connect_cb;
	ks_cb.ksock_cb_connectfailed = &krrp_conn_connect_cb;
	ks_cb.ksock_cb_disconnected = &krrp_conn_connect_cb;

	rc = ksocket_setcallbacks(ks, &ks_cb, &ct, CRED());
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SETSOCKOPTFAIL, rc);
		goto out;
	}

	mutex_init(&ct.mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&ct.cv, NULL, CV_DEFAULT, NULL);
	ct.cb_done = B_FALSE;
	ct.rc = 0;

	rc = ksocket_connect(ks, servaddr, sizeof (*servaddr), CRED());
	if (rc == 0 || rc == EISCONN) {
		rc = 0;
		goto cleanup;
	}

	if (rc != EINPROGRESS && rc != EALREADY) {
		krrp_error_set(error, KRRP_ERRNO_CONNFAIL, rc);
		goto cleanup;
	}

	mutex_enter(&ct.mtx);
	if (!ct.cb_done)
		(void) cv_reltimedwait_sig(&ct.cv, &ct.mtx,
			SEC_TO_TICK(timeout), TR_CLOCK_TICK);

	rc = ct.cb_done ? ct.rc : ETIMEDOUT;

	if (rc != 0)
		krrp_error_set(error, KRRP_ERRNO_CONNFAIL, rc);

	mutex_exit(&ct.mtx);

cleanup:
	nonblocking = 0;
	(void) ksocket_ioctl(ks, FIONBIO, (intptr_t)&nonblocking,
	    &rval, CRED());

	(void) ksocket_setcallbacks(ks, NULL, NULL, CRED());

	cv_destroy(&ct.cv);
	mutex_destroy(&ct.mtx);

out:
	return (rc);
}

/* ARGSUSED */
void
krrp_conn_connect_cb(ksocket_t ks,
    ksocket_callback_event_t ev, void *arg, uintptr_t info)
{
	krrp_conn_connect_timeout_t *ct = arg;

	VERIFY(ct != NULL);
	VERIFY(ev == KSOCKET_EV_CONNECTED ||
	    ev == KSOCKET_EV_CONNECTFAILED ||
	    ev == KSOCKET_EV_DISCONNECTED);

	mutex_enter(&ct->mtx);
	ct->cb_done = B_TRUE;
	if (ev == KSOCKET_EV_CONNECTED)
		ct->rc = 0;
	else
		ct->rc = info == 0 ? ECONNRESET : (int) info;

	cv_signal(&ct->cv);
	mutex_exit(&ct->mtx);
}

static int
krrp_conn_post_configure(krrp_conn_t *conn, krrp_error_t *error)
{
	struct sonode *so;
	uint32_t value;
	int rc;

	value = 1024 * 1024;
	rc = ksocket_setsockopt(conn->ks, SOL_SOCKET, SO_SNDBUF,
	    (const void *) &value, sizeof (value), CRED());
	if (rc != 0)
		goto err;

	value = 1024 * 1024;
	rc = ksocket_setsockopt(conn->ks, SOL_SOCKET, SO_RCVBUF,
	    (const void *) &value, sizeof (value), CRED());
	if (rc != 0)
		goto err;

	value = 1;
	rc = ksocket_setsockopt(conn->ks, IPPROTO_TCP, TCP_NODELAY,
	    (const void *) &value, sizeof (value), CRED());
	if (rc != 0)
		goto err;

	value = 60000;
	rc = ksocket_setsockopt(conn->ks, IPPROTO_TCP, TCP_ABORT_THRESHOLD,
	    (const void *) &value, sizeof (value), CRED());
	if (rc != 0)
		goto err;

	if (get_udatamodel() == DATAMODEL_NONE ||
	    get_udatamodel() == DATAMODEL_NATIVE) {
		struct timeval tl;

		tl.tv_sec = KRRP_RX_TIMEOUT;
		tl.tv_usec = 0;

		rc = ksocket_setsockopt(conn->ks, SOL_SOCKET, SO_RCVTIMEO,
			&tl, sizeof (struct timeval), CRED());
	} else {
		struct timeval32 tl;

		tl.tv_sec = KRRP_RX_TIMEOUT;
		tl.tv_usec = 0;

		rc = ksocket_setsockopt(conn->ks, SOL_SOCKET, SO_RCVTIMEO,
			&tl, sizeof (struct timeval32), CRED());
	}

	if (rc != 0)
		goto err;


	so = (struct sonode *)(conn->ks);

	conn->mblk_wroff = (size_t) so->so_proto_props.sopp_wroff;
	conn->mblk_tail_len = (size_t) so->so_proto_props.sopp_tail;

	conn->max_blk_sz = so->so_proto_props.sopp_maxpsz;

	if (so->so_proto_props.sopp_maxblk == INFPSZ) {
		/* LSO is enabled */
		conn->blk_sz = so->so_proto_props.sopp_maxpsz;

		/*
		 * kmem_alloc for allocations that are less 128k
		 * uses kmem_cache, otherwise some slow-path,
		 * so to exclude performance problems if LSO allows
		 * very big buffer the maximum block size is 128k
		 */
		if (conn->blk_sz > 128 * 1024)
			conn->blk_sz = 128 * 1024;
	} else {
		conn->blk_sz = so->so_proto_props.sopp_maxblk;
	}

	return (0);

err:
	krrp_error_set(error, KRRP_ERRNO_SETSOCKOPTFAIL, rc);
	return (-1);
}

static void
krrp_conn_tx_handler(void *void_conn)
{
	krrp_conn_t *conn = (krrp_conn_t *) void_conn;
	krrp_pdu_t *pdu;
	krrp_error_t error;
	int rc = 0;

	krrp_error_init(&error);

	mutex_enter(&conn->mtx);
	conn->tx_t_did = curthread->t_did;
	ksocket_hold(conn->ks);

	while (conn->tx_running) {
		mutex_exit(&conn->mtx);

		/*
		 * At the sender side TX path sends CTRL and DATA PDUs
		 */
		if (conn->get_data_pdu_cb != NULL) {
			pdu = krrp_queue_get_no_wait(conn->ctrl_tx_queue);

			if (pdu == NULL) {
				conn->get_data_pdu_cb(conn->get_data_pdu_cb_arg,
				    &pdu);
				if (pdu == NULL) {
					mutex_enter(&conn->mtx);
					continue;
				}

				conn->cur_txg = ((krrp_pdu_data_t *) pdu)->txg;
			}
		} else {
			pdu = krrp_queue_get(conn->ctrl_tx_queue);
			if (pdu == NULL) {
				mutex_enter(&conn->mtx);
				continue;
			}
		}

		rc = krrp_conn_tx_pdu(conn, pdu, &error);
		krrp_pdu_rele(pdu);
		mutex_enter(&conn->mtx);
		if (rc != 0)
			break;

		conn->cur_txg = 0;
	}

	if (conn->state == KRRP_CS_DISCONNECTING)
		(void) memset(&error, 0, sizeof (error));

	mutex_exit(&conn->mtx);

	ksocket_rele(conn->ks);

	if (error.krrp_errno != 0)
		krrp_conn_callback(conn, KRRP_CONN_ERROR, &error);
}

static int
krrp_conn_tx_pdu(krrp_conn_t *conn, krrp_pdu_t *pdu, krrp_error_t *error)
{
	int rc;

#ifdef KRRP_CONN_DEBUG
	cmn_err(CE_NOTE, "TX PDU-[%s], payload:[%u][%lu]",
	    (pdu->type == KRRP_PT_DATA ? "DATA" : "CTRL"),
	    pdu->hdr->payload_sz, pdu->cur_data_sz);
#endif

	rc = krrp_conn_tx(conn->ks, (void *) pdu->hdr,
	    sizeof (krrp_hdr_t), error);
	if (rc != 0)
		return (rc);

	switch (pdu->type) {
	case KRRP_PT_DATA:
		conn->bytes_tx += sizeof (krrp_hdr_t);
		rc = krrp_conn_tx_data_pdu_dblk(conn, &pdu->dblk, error);
		break;
	case KRRP_PT_CTRL:
		conn->bytes_tx += sizeof (krrp_hdr_t);
		rc = krrp_conn_tx_ctrl_pdu_dblk(conn, pdu->dblk, error);
		break;
	}

	return (rc);
}

static int
krrp_conn_tx(ksocket_t ks, void *buff, size_t buff_sz, krrp_error_t *error)
{
	int rc = 0;
	size_t sent = 0, remains, offset = 0;

	remains = buff_sz;
	while (remains > 0) {
		rc = ksocket_send(ks, (void *) (((uintptr_t) buff) + offset),
		    remains, 0, &sent, CRED());
		if (rc != 0) {
			krrp_error_set(error, KRRP_ERRNO_SENDFAIL, rc);
			break;
		}

		remains -= sent;
		offset += sent;
		sent = 0;
	}

	return (rc);
}

static int
krrp_conn_tx_mblk(ksocket_t ks, mblk_t *mp, krrp_error_t *error)
{
	int rc;
	struct nmsghdr msghdr;

	msghdr.msg_name = NULL;
	msghdr.msg_namelen = 0;
	msghdr.msg_control = NULL;
	msghdr.msg_controllen = 0;
	msghdr.msg_flags = MSG_EOR;

	rc = ksocket_sendmblk(ks, &msghdr, 0, &mp, CRED());
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SENDMBLKFAIL, rc);
		if (mp != NULL)
			freeb(mp);
	}

	return (rc);
}

static int
krrp_conn_tx_ctrl_pdu_dblk(krrp_conn_t *conn, krrp_dblk_t *dblk,
    krrp_error_t *error)
{
	while (dblk != NULL) {
		int rc;

		rc = krrp_conn_tx(conn->ks, dblk->data,
		    dblk->cur_data_sz, error);
		if (rc != 0)
			return (rc);

		conn->bytes_tx += dblk->cur_data_sz;
		dblk = dblk->next;
	}

	return (0);
}

static int
krrp_conn_tx_data_pdu_dblk(krrp_conn_t *conn, krrp_dblk_t **dblk,
    krrp_error_t *error)
{
	krrp_dblk_t *dblk_cur;

	dblk_cur = *dblk;
	while (dblk_cur != NULL && dblk_cur->cur_data_sz != 0) {
		mblk_t *mp = NULL;
		int rc;

		*dblk = dblk_cur->next;
		dblk_cur->next = NULL;

		krrp_conn_dblk_to_mblk(dblk_cur, &mp,
		    conn->mblk_wroff, 0);

		krrp_conn_throttle(&conn->throttle, dblk_cur->cur_data_sz);

		conn->bytes_tx += dblk_cur->cur_data_sz;
		rc = krrp_conn_tx_mblk(conn->ks, mp, error);
		if (rc != 0) {
			return (rc);
		}

		dblk_cur = *dblk;
	}

	return (0);
}

/* ARGSUSED */
static void
krrp_conn_dblk_to_mblk(krrp_dblk_t *dblk, mblk_t **result_mp,
    size_t wroff, size_t tail_len)
{
	mblk_t *mp;

	mp = desballoc(dblk->head, dblk->total_sz, 0, &dblk->free_rtns);

	mp->b_rptr += wroff;
	mp->b_wptr = mp->b_rptr + dblk->cur_data_sz;

	*result_mp = mp;
}

static void
krrp_conn_rx_handler(void *void_conn)
{
	krrp_conn_t *conn = (krrp_conn_t *) void_conn;

	int rc;
	krrp_pdu_t *pdu = NULL;
	krrp_hdr_t *hdr = NULL;
	krrp_error_t error;

	krrp_error_init(&error);

	mutex_enter(&conn->mtx);
	conn->rx_t_did = curthread->t_did;
	ksocket_hold(conn->ks);

	while (conn->rx_running) {
		mutex_exit(&conn->mtx);

		if (hdr == NULL) {
			if (krrp_conn_rx_header(conn, &hdr, &error) != 0) {
				mutex_enter(&conn->mtx);
				conn->rx_running = B_FALSE;
				continue;
			}
		}

#ifdef KRRP_CONN_DEBUG
		cmn_err(CE_NOTE, "HDR: opcode:[%u]; flags:[%u]; payload_sz:[%u]",
		    hdr->opcode, hdr->flags, hdr->payload_sz);
#endif

		if (hdr->opcode & KRRP_CTRL_OPCODE_MASK)
			krrp_pdu_ctrl_alloc((krrp_pdu_ctrl_t **) &pdu,
			    KRRP_PDU_WITHOUT_HDR);
		else if (conn->data_pdu_engine != NULL) {
			krrp_pdu_alloc(conn->data_pdu_engine, &pdu,
			    KRRP_PDU_WITHOUT_HDR);
			conn->cur_txg = ((krrp_hdr_data_t *) hdr)->txg;
		} else {
			/*
			 * This thread is not used at initial stage,
			 * so at the running stage DataPDUEngine must be defined
			 */
			cmn_err(CE_PANIC, "Data PDU Engined is not defined");
		}

		if (pdu == NULL) {
			mutex_enter(&conn->mtx);
			continue;
		}

		pdu->hdr = hdr;
		hdr = NULL;

		rc = krrp_conn_rx_pdu(conn, pdu, &error);
		if (rc == 0) {
			krrp_conn_process_received_pdu(conn, pdu);
			pdu = NULL;
			conn->cur_txg = 0;
		}

		mutex_enter(&conn->mtx);
		if (rc != 0)
			break;
	}

	if (conn->state == KRRP_CS_DISCONNECTING)
		(void) memset(&error, 0, sizeof (error));

	mutex_exit(&conn->mtx);

	if (hdr != NULL)
		kmem_free(hdr, sizeof (krrp_hdr_t));

	if (pdu != NULL)
		krrp_pdu_rele(pdu);

	if (error.krrp_errno != 0)
		krrp_conn_callback(conn, KRRP_CONN_ERROR, &error);

	ksocket_rele(conn->ks);
}

static int
krrp_conn_rx_header(krrp_conn_t *conn, krrp_hdr_t **result_hdr,
    krrp_error_t *error)
{
	krrp_hdr_t *hdr;
	int rc;

	hdr = kmem_zalloc(sizeof (krrp_hdr_t), KM_SLEEP);
	rc = krrp_conn_rx(conn->ks, (void *) hdr, sizeof (krrp_hdr_t), error);
	if (rc == 0) {
		conn->bytes_rx += sizeof (krrp_hdr_t);
		*result_hdr = hdr;
		return (0);
	}

	kmem_free(hdr, sizeof (krrp_hdr_t));
	return (rc);
}

static int
krrp_conn_rx_pdu(krrp_conn_t *conn, krrp_pdu_t *pdu, krrp_error_t *error)
{
	krrp_dblk_t *dblk;
	size_t remaining_sz;
	size_t cnt = 0;

	if (pdu->hdr->payload_sz > pdu->max_data_sz) {
		krrp_error_set(error, KRRP_ERRNO_BIGPAYLOAD, 0);
		return (-1);
	}

	remaining_sz = pdu->hdr->payload_sz;
	dblk = pdu->dblk;
	while (remaining_sz != 0) {
		int rc;
		size_t need_to_recv;

		/* Something wrong in our PDU Engine */
		ASSERT(dblk != NULL);

		if (remaining_sz > dblk->max_data_sz)
			need_to_recv = dblk->max_data_sz;
		else
			need_to_recv = remaining_sz;

#ifdef KRRP_CONN_DEBUG
		cmn_err(CE_NOTE, "RX dblk #[%lu] [%lu]",
		    cnt, remaining_sz);
#endif

		rc = krrp_conn_rx(conn->ks, dblk->data, need_to_recv, error);
		if (rc != 0)
			return (rc);

		conn->bytes_rx += need_to_recv;
		dblk->cur_data_sz = need_to_recv;
		remaining_sz -= need_to_recv;
		dblk = dblk->next;
		cnt++;
	}

	pdu->cur_data_sz = pdu->hdr->payload_sz;

	return (0);
}

static int
krrp_conn_rx(ksocket_t ks, void *buff, size_t buff_sz, krrp_error_t *error)
{
	int rc;
	size_t received = 0;

	rc = ksocket_recv(ks, buff, buff_sz, MSG_WAITALL,
	    &received, CRED());

	if ((rc != 0) || (received != buff_sz)) {
		if (rc == 0) {
			if (received == 0)
				krrp_error_set(error, KRRP_ERRNO_UNEXPCLOSE, 0);
			else
				krrp_error_set(error, KRRP_ERRNO_UNEXPEND, 0);
		} else {
			if (rc == EAGAIN)
				rc = ETIMEDOUT;

			krrp_error_set(error, KRRP_ERRNO_RECVFAIL, rc);
		}

		rc = -1;
	}

	return (rc);
}

static void
krrp_conn_process_received_pdu(krrp_conn_t *conn, krrp_pdu_t *pdu)
{
	krrp_conn_cb_ev_t ev;

	if (krrp_pdu_type(pdu) == KRRP_PT_DATA)
		ev = KRRP_CONN_DATA_PDU;
	else
		ev = KRRP_CONN_CTRL_PDU;

	krrp_conn_callback(conn, ev, pdu);
}
