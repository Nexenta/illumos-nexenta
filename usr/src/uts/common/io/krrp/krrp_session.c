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
 * Session establishment AUTH Schema:
 *
 * 1. The userspace over the secured Ctrl-Path negotiate
 * about an secured value
 *
 * 2. The manager and agent pass digest of the secured value to
 * kernel as part of params for 'sess_create' IOCTL
 *
 * 3. During connection establishment phase the manager's session sends
 * the digest to remote side.
 *
 * 4. The agent's session compares the received digest to available digest
 *
 * 5. If the agent's session does not have digest, then the received digest
 * will be ignored.
 *
 * 6. If the agent's session has a digest and this digest is not equal to
 * the received digest, or the received params do not a digest then
 * the correspoinding session establishment request will be rejected.
 */

#include <sys/types.h>
#include <sys/conf.h>
#include <sys/sysmacros.h>
#include <sys/cmn_err.h>
#include <sys/stat.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sdt.h>

#include <krrp_params.h>

#include "krrp_protocol.h"
#include "krrp_svc.h"
#include "krrp_session.h"

/* #define KRRP_SESS_DEBUG 1 */

static int krrp_sess_common_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error);

static void krrp_sess_start_ping(krrp_sess_t *sess);
static void krrp_sess_stop_ping(krrp_sess_t *sess);
static void krrp_sess_ping_cb(void *void_sess);
static void krrp_sess_ping_request(krrp_sess_t *sess);

static void krrp_sess_lr_stream_cb(krrp_stream_cb_ev_t ev, uintptr_t ev_arg,
    void *void_sess);
static void krrp_sess_ll_stream_cb(krrp_stream_cb_ev_t ev, uintptr_t ev_arg,
    void *void_sess);
static void krrp_sess_stream_error(krrp_sess_t *sess, krrp_error_t *error);
static void krrp_sess_txg_recv_done(krrp_sess_t *sess, uint64_t txg,
    boolean_t complete);

static void krrp_sess_post_error_uevent(krrp_sess_t *sess,
    krrp_error_t *error);
static void krrp_sess_post_send_done_uevent(krrp_sess_t *sess);

static void krrp_sess_lr_data_pdu_from_stream(krrp_sess_t *sess,
    krrp_pdu_data_t *pdu);
static void krrp_sess_ll_data_pdu_from_stream(krrp_sess_t *sess,
    krrp_pdu_data_t *pdu);
static void krrp_sess_lr_txg_recv_done(krrp_sess_t *sess, uint64_t txg);
static void krrp_sess_ll_txg_recv_done(krrp_sess_t *sess, uint64_t txg);
static void krrp_sess_lr_send_done(krrp_sess_t *sess);
static void krrp_sess_ll_send_done(krrp_sess_t *sess);

static void krrp_sess_pdu_engine_cb(void *void_sess, size_t released_pdus);
static void krrp_sess_conn_cb(void *void_conn, krrp_conn_cb_ev_t ev,
    uintptr_t ev_arg, void *void_sess);

static void krrp_sess_kstat_init(krrp_sess_t *sess);
static int krrp_sess_kstat_update(kstat_t *ks, int rw);
static void krrp_sess_sender_kstat_update(krrp_sess_t *sess, kstat_t *ks);
static void krrp_sess_receiver_kstat_update(krrp_sess_t *sess, kstat_t *ks);
static void krrp_sess_compound_kstat_update(krrp_sess_t *sess, kstat_t *ks);

static void krrp_sess_conn_error(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error);
static void krrp_sess_ctrl_pdu_from_network(krrp_sess_t *sess,
    krrp_pdu_ctrl_t *pdu);
static void krrp_sess_data_pdu_from_network(krrp_sess_t *sess,
    krrp_pdu_data_t *pdu);

static int krrp_sess_fl_ctrl_validate(krrp_sess_t *sess,
    krrp_hdr_data_t *hdr);
static void krrp_sess_fl_ctrl_calc_cwnd_window(krrp_fl_ctrl_t *fl_ctrl,
    uint64_t new_recv_window);
static void krrp_sess_fl_ctrl_update_tx(krrp_fl_ctrl_t *fl_ctrl,
    uint64_t max_pdu_seq_num);
static uint64_t krrp_sess_fl_ctrl_update_rx(krrp_fl_ctrl_t *fl_ctrl,
    size_t window_offset);
static void krrp_sess_get_data_pdu_to_tx(void *void_sess,
    krrp_pdu_t **result_pdu);

static int krrp_sess_set_kstat_id(krrp_sess_t *sess,
    const char *kstat_id_str, krrp_error_t *error);

static int krrp_sess_set_auth_digest(krrp_sess_t *sess,
    const char *auth_digest, krrp_error_t *error);

static void krrp_sess_nomem_error(krrp_sess_t *sess);
static void krrp_sess_error(krrp_sess_t *sess, krrp_error_t *error);

static int krrp_sess_inc_ref_cnt(krrp_sess_t *sess);
static void krrp_sess_dec_ref_cnt(krrp_sess_t *sess);

static void krrp_sess_send_shutdown(krrp_sess_t *sess);


#define	XX(name, dtype, def_value) {#name, dtype, def_value},
static const krrp_sess_sender_kstat_t sess_sender_stats_templ = {
	KRRP_SESS_SENDER_STAT_NAME_MAP(XX)
};

static const krrp_sess_receiver_kstat_t sess_receiver_stats_templ = {
	KRRP_SESS_RECEIVER_STAT_NAME_MAP(XX)
};

static const krrp_sess_receiver_kstat_t sess_compound_stats_templ = {
	KRRP_SESS_COMPOUND_STAT_NAME_MAP(XX)
};
#undef XX

/*
 * 0 - disable re-calculation
 * 1 - use algorithm1
 * 2 - use algorithm2
 */
int krrp_sess_cwnd_state = 2;

/*
 * 0 - pass all PDUs to stream (default)
 * any other - do not pass received PDUs to stream
 */
int krrp_sess_recv_without_stream = 0;

int
krrp_sess_create(krrp_sess_t **result_sess, const char *id,
    const char *kstat_id, const char *auth_digest,
    boolean_t sender, boolean_t fake_mode,
    boolean_t compound, krrp_error_t *error)
{
	krrp_sess_t *sess;

	VERIFY(result_sess != NULL && *result_sess == NULL);

	if (compound && (sender || auth_digest != NULL)) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
		return (-1);
	}

	sess = kmem_zalloc(sizeof (krrp_sess_t), KM_SLEEP);

	if (krrp_sess_set_id(sess, id, error) != 0)
		goto err;

	if (krrp_sess_set_kstat_id(sess, kstat_id, error) != 0)
		goto err;

	if (krrp_sess_set_auth_digest(sess, auth_digest, error) != 0)
		goto err;

	mutex_init(&sess->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&sess->cv, NULL, CV_DEFAULT, NULL);

	mutex_init(&sess->fl_ctrl.mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&sess->fl_ctrl.cv, NULL, CV_DEFAULT, NULL);

	krrp_queue_init(&sess->data_write_queue, sizeof (krrp_pdu_t),
	    offsetof(krrp_pdu_t, node));
	krrp_queue_init(&sess->data_tx_queue, sizeof (krrp_pdu_t),
	    offsetof(krrp_pdu_t, node));
	krrp_queue_init(&sess->ctrl_tx_queue, sizeof (krrp_pdu_t),
	    offsetof(krrp_pdu_t, node));

	if (compound)
		sess->type = KRRP_SESS_COMPOUND;
	else if (sender)
		sess->type = KRRP_SESS_SENDER;
	else
		sess->type = KRRP_SESS_RECEIVER;

	sess->fake_mode = fake_mode;

	*result_sess = sess;

	return (0);

err:
	kmem_free(sess, sizeof (krrp_sess_t));
	return (-1);
}

void
krrp_sess_destroy(krrp_sess_t *sess)
{
	krrp_pdu_t *pdu;

	krrp_sess_stop_ping(sess);

	mutex_enter(&sess->mtx);

	if (!sess->shutdown && sess->conn != NULL) {
		sess->shutdown = B_TRUE;
		krrp_sess_send_shutdown(sess);

		(void) cv_reltimedwait(&sess->cv, &sess->mtx,
		    SEC_TO_TICK(2), TR_CLOCK_TICK);
	}

	sess->destroying = B_TRUE;
	while (sess->ref_cnt > 0)
		cv_wait(&sess->cv, &sess->mtx);

	mutex_exit(&sess->mtx);

	if (sess->kstat.ctx != NULL)
		kstat_delete(sess->kstat.ctx);

	if (sess->conn != NULL)
		krrp_conn_destroy(sess->conn);

	if (sess->stream_read != NULL)
		krrp_stream_destroy(sess->stream_read);

	if (sess->stream_write != NULL)
		krrp_stream_destroy(sess->stream_write);

	while ((pdu = krrp_queue_get_no_wait(sess->data_write_queue)) != NULL)
		krrp_pdu_rele(pdu);

	while ((pdu = krrp_queue_get_no_wait(sess->data_tx_queue)) != NULL)
		krrp_pdu_rele(pdu);

	while ((pdu = krrp_queue_get_no_wait(sess->ctrl_tx_queue)) != NULL)
		krrp_pdu_rele(pdu);

	krrp_queue_fini(sess->data_write_queue);
	krrp_queue_fini(sess->data_tx_queue);
	krrp_queue_fini(sess->ctrl_tx_queue);

	if (sess->data_pdu_engine != NULL)
		krrp_pdu_engine_destroy(sess->data_pdu_engine);

	if (sess->private_data != NULL)
		fnvlist_free(sess->private_data);

	cv_destroy(&sess->fl_ctrl.cv);
	mutex_destroy(&sess->fl_ctrl.mtx);

	cv_destroy(&sess->cv);
	mutex_destroy(&sess->mtx);

	kmem_free(sess, sizeof (krrp_sess_t));
}

int
krrp_sess_run(krrp_sess_t *sess, boolean_t only_once, krrp_error_t *error)
{
	int rc = -1;
	boolean_t fatal_error = B_FALSE;
	boolean_t stream_is_not_defined = B_FALSE;

	mutex_enter(&sess->mtx);

	if (sess->error.krrp_errno != 0) {
		(void) memcpy(error, &sess->error, sizeof (krrp_error_t));
		goto out;
	}

	if (sess->type == KRRP_SESS_RECEIVER && only_once) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
		goto out;
	}

	if (sess->started) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
		goto out;
	}

	switch (sess->type) {
	case KRRP_SESS_COMPOUND:
		stream_is_not_defined = (sess->stream_read == NULL ||
		    sess->stream_write == NULL);
		break;
	case KRRP_SESS_SENDER:
		stream_is_not_defined = (sess->stream_read == NULL);
		break;
	case KRRP_SESS_RECEIVER:
		stream_is_not_defined = (sess->stream_write == NULL);
		break;
	}

	if (stream_is_not_defined) {
		krrp_error_set(error, KRRP_ERRNO_STREAM, ENOENT);
		goto out;
	}

	if (sess->type != KRRP_SESS_COMPOUND && sess->conn == NULL) {
		krrp_error_set(error, KRRP_ERRNO_CONN, ENOENT);
		goto out;
	}

	if (sess->data_pdu_engine == NULL) {
		krrp_error_set(error, KRRP_ERRNO_PDUENGINE, ENOENT);
		goto out;
	}

	if (sess->type != KRRP_SESS_RECEIVER && only_once &&
	    sess->stream_read->non_continuous) {
		krrp_error_set(error, KRRP_ERRNO_STREAM, EINVAL);
		goto out;
	}

	/*
	 * Need to store error to session, to be able to
	 * return it again, because an error that might
	 * occur bellow cannot be fixed without
	 * recreation of session.
	 */
	fatal_error = B_TRUE;

	if (sess->type == KRRP_SESS_COMPOUND) {
		rc = krrp_stream_run(sess->stream_write,
		    sess->data_write_queue,
		    sess->data_pdu_engine, error);
		if (rc != 0)
			goto out;

		rc = krrp_stream_run(sess->stream_read,
		    sess->data_write_queue,
		    sess->data_pdu_engine, error);
		if (rc != 0) {
			krrp_stream_stop(sess->stream_write);
			goto out;
		}
	} else {
		krrp_stream_t *stream;

		stream = sess->type == KRRP_SESS_SENDER ?
		    sess->stream_read : sess->stream_write;

		rc = krrp_stream_run(stream, sess->data_write_queue,
		    sess->data_pdu_engine, error);
		if (rc != 0)
			goto out;

		if (sess->type == KRRP_SESS_SENDER)
			krrp_conn_run(sess->conn, sess->ctrl_tx_queue,
			    sess->data_pdu_engine,
			    &krrp_sess_get_data_pdu_to_tx, sess);
		else
			krrp_conn_run(sess->conn, sess->ctrl_tx_queue,
			    sess->data_pdu_engine, NULL, NULL);

		krrp_sess_start_ping(sess);
	}

	krrp_sess_kstat_init(sess);

	sess->started = B_TRUE;
	sess->running = B_TRUE;

out:
	if (rc != 0 && fatal_error) {
		ASSERT(error->krrp_errno != 0);

		sess->error.krrp_errno = error->krrp_errno;
		sess->error.unix_errno = error->unix_errno;
	}
	mutex_exit(&sess->mtx);

	if (rc == 0 && sess->type == KRRP_SESS_RECEIVER)
		krrp_pdu_engine_force_notify(sess->data_pdu_engine, B_TRUE);

	/*
	 * Only once means that after successfully start
	 * we immediately do gracefull shutdown
	 *
	 * There is no reason to implement a complex logic that will handle
	 * processing of only one snapshot
	 */
	if (rc == 0 && sess->type != KRRP_SESS_RECEIVER && only_once)
		(void) krrp_stream_send_stop(sess->stream_read);

	return (rc);
}

void
krrp_sess_get_status(krrp_sess_t *sess, nvlist_t *result)
{
	boolean_t true_value = B_TRUE;

	mutex_enter(&sess->mtx);

	switch (sess->type) {
	case KRRP_SESS_SENDER:
		VERIFY0(krrp_param_put(KRRP_PARAM_SESS_SENDER,
		    result, &true_value));
		break;
	case KRRP_SESS_RECEIVER:
		break;
	case KRRP_SESS_COMPOUND:
		VERIFY0(krrp_param_put(KRRP_PARAM_SESS_COMPOUND,
		    result, &true_value));
		break;
	}

	VERIFY0(krrp_param_put(KRRP_PARAM_SESS_ID,
	    result, sess->id));
	VERIFY0(krrp_param_put(KRRP_PARAM_SESS_KSTAT_ID,
	    result, sess->kstat.id));
	VERIFY0(krrp_param_put(KRRP_PARAM_SESS_STARTED,
	    result, &sess->started));
	VERIFY0(krrp_param_put(KRRP_PARAM_SESS_RUNNING,
	    result, &sess->running));

	if (sess->error.krrp_errno != 0)
		krrp_error_to_nvl(&sess->error, &result);

	mutex_exit(&sess->mtx);
}

/*
 * Retrieve information about existing connection
 * and place it to result NVL.
 */
int
krrp_sess_get_conn_info(krrp_sess_t *sess, nvlist_t *result,
    krrp_error_t *error)
{
	if (sess->type == KRRP_SESS_COMPOUND) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
		return (-1);
	}

	if (sess->conn == NULL) {
		krrp_error_set(error, KRRP_ERRNO_CONN, ENOENT);
		return (-1);
	}

	VERIFY0(krrp_param_put(KRRP_PARAM_DBLK_DATA_SIZE,
	    result, (void *)&sess->conn->blk_sz));

	return (0);
}

/*
 * 'Started' means 'sess_run' IOCTL was successfully processed
 */
boolean_t
krrp_sess_is_started(krrp_sess_t *sess)
{
	boolean_t result;

	mutex_enter(&sess->mtx);
	result = sess->started;
	mutex_exit(&sess->mtx);

	return (result);
}

/*
 * 'Running' means 'sess_run' IOCTL was successfully processed
 * and now session does replication.
 *
 * It is possible to have: started == B_TRUE && running == B_FALSE.
 * This means an error occured and now session waits for control action
 * from userspace
 */
boolean_t
krrp_sess_is_running(krrp_sess_t *sess)
{
	boolean_t result;

	mutex_enter(&sess->mtx);
	result = sess->running;
	mutex_exit(&sess->mtx);

	return (result);
}

int
krrp_sess_throttle_conn(krrp_sess_t *sess, size_t limit,
    krrp_error_t *error)
{
	int rc = -1;

	if (sess->type != KRRP_SESS_SENDER) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
		goto out;
	}

	if (sess->conn == NULL) {
		krrp_error_set(error, KRRP_ERRNO_CONN, ENOENT);
		goto out;
	}

	krrp_conn_throttle_set(sess->conn, limit,
	    !krrp_sess_is_running(sess));
	rc = 0;

out:
	return (rc);
}

static void
krrp_sess_start_ping(krrp_sess_t *sess)
{
	sess->ping_timer = timeout(krrp_sess_ping_cb, sess,
	    drv_usectohz(5 * 1000000));
}

static void
krrp_sess_stop_ping(krrp_sess_t *sess)
{
	timeout_id_t saved_timer;

	mutex_enter(&sess->mtx);
	saved_timer = sess->ping_timer;
	sess->ping_timer = NULL;
	mutex_exit(&sess->mtx);

	if (saved_timer != NULL)
		(void) untimeout(saved_timer);
}

static void
krrp_sess_ping_cb(void *void_sess)
{
	krrp_pdu_ctrl_t *pdu = NULL;
	krrp_sess_t *sess = void_sess;

	if (sess->ping_wait_for_response) {
		krrp_error_t error;

		krrp_error_init(&error);
		krrp_error_set(&error, KRRP_ERRNO_PINGTIMEOUT, 0);
		krrp_sess_post_error_uevent(sess, &error);
		goto out;
	}

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "No memory to send PING request");
		return;
	}

	pdu->hdr->opcode = KRRP_OPCODE_PING;
	krrp_queue_put(sess->ctrl_tx_queue, pdu);
	sess->ping_wait_for_response = B_TRUE;

out:
	mutex_enter(&sess->mtx);

	if (sess->ping_timer != NULL && !sess->destroying)
		krrp_sess_start_ping(sess);

	mutex_exit(&sess->mtx);
}

int
krrp_sess_send_stop(krrp_sess_t *sess, krrp_error_t *error)
{
	int rc = -1;

	if (!krrp_sess_is_running(sess)) {
		krrp_error_set(error, KRRP_ERRNO_SESS, ENOTACTIVE);
	} else {
		if (sess->type == KRRP_SESS_RECEIVER)
			krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
		else if (sess->stream_read->non_continuous)
			krrp_error_set(error, KRRP_ERRNO_STREAM, EINVAL);
		else if (krrp_stream_send_stop(sess->stream_read) != 0)
			krrp_error_set(error, KRRP_ERRNO_STREAM, EALREADY);
		else
			rc = 0;
	}

	return (rc);
}

int
krrp_sess_attach_pdu_engine(krrp_sess_t *sess,
    krrp_pdu_engine_t *pdu_engine, krrp_error_t *error)
{
	int rc = -1;

	mutex_enter(&sess->mtx);

	if (sess->data_pdu_engine != NULL) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
		goto out;
	}

	VERIFY(pdu_engine->type == KRRP_PET_DATA);
	VERIFY(sess->data_pdu_engine == NULL);

	sess->data_pdu_engine = pdu_engine;

	/*
	 * The receiver uses notifications from PDU engine to
	 * update RX Window and send the info to the sender
	 */
	if (sess->type == KRRP_SESS_RECEIVER)
		krrp_pdu_engine_register_callback(pdu_engine,
		    &krrp_sess_pdu_engine_cb, sess);

	rc = 0;
out:
	mutex_exit(&sess->mtx);
	return (rc);
}

int
krrp_sess_attach_read_stream(krrp_sess_t *sess,
    krrp_stream_t *stream, krrp_error_t *error)
{
	int rc = -1;

	VERIFY(stream != NULL);
	VERIFY(sess->type != KRRP_SESS_RECEIVER);

	mutex_enter(&sess->mtx);

	if (sess->stream_read != NULL) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
		goto out;
	}

	sess->stream_read = stream;

	if (sess->type == KRRP_SESS_COMPOUND)
		krrp_stream_register_callback(stream,
		    &krrp_sess_ll_stream_cb, sess);
	else
		krrp_stream_register_callback(stream,
		    &krrp_sess_lr_stream_cb, sess);

	rc = 0;

out:
	mutex_exit(&sess->mtx);

	return (rc);
}

int
krrp_sess_attach_write_stream(krrp_sess_t *sess,
    krrp_stream_t *stream, krrp_error_t *error)
{
	int rc = -1;

	VERIFY(stream != NULL);
	VERIFY(sess->type != KRRP_SESS_SENDER);

	mutex_enter(&sess->mtx);

	if (sess->stream_write != NULL) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
		goto out;
	}

	sess->stream_write = stream;

	if (sess->type == KRRP_SESS_COMPOUND)
		krrp_stream_register_callback(stream,
		    &krrp_sess_ll_stream_cb, sess);
	else
		krrp_stream_register_callback(stream,
		    &krrp_sess_lr_stream_cb, sess);

	rc = 0;

out:
	mutex_exit(&sess->mtx);

	return (rc);
}

int
krrp_sess_target_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    nvlist_t *params, krrp_error_t *error)
{
	int rc;
	boolean_t fake_mode;

	if (krrp_sess_common_attach_conn(sess, conn, error) != 0)
		return (-1);

	fake_mode = krrp_param_exists(KRRP_PARAM_FAKE_MODE, params);

	if (fake_mode && sess->type == KRRP_SESS_RECEIVER && !sess->fake_mode) {
		cmn_err(CE_WARN, "It is impossible to use real receiver "
		    "together with fake sender");
		krrp_error_set(error, KRRP_ERRNO_PROTO, EFAULT);
		goto err;
	}

	if (sess->auth_digest[0] != '\0') {
		const char *auth_data = NULL;

		rc = krrp_param_get(KRRP_PARAM_AUTH_DATA,
		    params, (void *)&auth_data);
		if (rc != 0) {
			krrp_error_set(error, KRRP_ERRNO_AUTH, ENOENT);
			goto err;
		}

		if (strcmp(sess->auth_digest, auth_data) != 0) {
			krrp_error_set(error, KRRP_ERRNO_AUTH, EINVAL);
			goto err;
		}
	}

	rc = krrp_conn_send_ctrl_data(conn,
	    KRRP_OPCODE_ATTACH_SESS, NULL, error);
	if (rc != 0)
		goto err;

	krrp_conn_register_callback(sess->conn,
	    &krrp_sess_conn_cb, sess);

	return (0);

err:
	mutex_enter(&sess->mtx);
	sess->conn = NULL;
	mutex_exit(&sess->mtx);
	return (-1);
}

int
krrp_sess_initiator_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error)
{
	int rc;
	nvlist_t *params;
	krrp_pdu_ctrl_t *pdu = NULL;

	if (krrp_sess_common_attach_conn(sess, conn, error) != 0)
		return (-1);

	params = fnvlist_alloc();

	if (sess->auth_digest[0] != '\0') {
		(void) krrp_param_put(KRRP_PARAM_AUTH_DATA,
		    params, sess->auth_digest);
	}

	if (sess->type == KRRP_SESS_SENDER && sess->fake_mode)
		(void) krrp_param_put(KRRP_PARAM_FAKE_MODE, params, NULL);

	(void) krrp_param_put(KRRP_PARAM_SESS_ID,
	    params, sess->id);

	rc = krrp_conn_send_ctrl_data(conn,
	    KRRP_OPCODE_ATTACH_SESS, params, error);
	fnvlist_free(params);
	if (rc != 0)
		goto err;

	rc = krrp_conn_rx_ctrl_pdu(conn, &pdu, error);
	if (rc != 0)
		goto err;

	if (krrp_pdu_opcode(pdu) != KRRP_OPCODE_ATTACH_SESS) {
		if (krrp_pdu_opcode(pdu) == KRRP_OPCODE_ERROR) {
			nvlist_t *error_nvl = NULL;

			cmn_err(CE_WARN, "Remote side returned an error");

			rc = krrp_pdu_get_nvl_from_payload(pdu, &error_nvl);
			if (rc == 0) {
				rc = krrp_error_from_nvl(error, error_nvl);
				if (rc == 0) {
					if (error->krrp_errno == 0) {
						/*
						 * Something wrong, so we will return
						 * KRRP_ERRNO_BADRESP
						 */
						rc = -1;
					} else {
						krrp_error_set_flag(error,
						    KRRP_ERRF_REMOTE);
					}
				}

				fnvlist_free(error_nvl);
			}
		}

		if (rc != 0)
			krrp_error_set(error, KRRP_ERRNO_BADRESP, 0);
		else
			rc = -1;
	}

	krrp_pdu_rele((krrp_pdu_t *)pdu);

	if (rc != 0)
		goto err;

	krrp_conn_register_callback(sess->conn,
	    &krrp_sess_conn_cb, sess);

	return (0);

err:
	mutex_enter(&sess->mtx);
	sess->conn = NULL;
	mutex_exit(&sess->mtx);
	return (-1);
}

/*
 * Here we check that:
 * - the session does not have attached connection
 * - the session is not compound (local 2 local replication)
 */
static int
krrp_sess_common_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error)
{
	int rc = -1;

	mutex_enter(&sess->mtx);

	if (sess->conn != NULL)
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
	else if (sess->type == KRRP_SESS_COMPOUND)
		krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
	else {
		sess->conn = conn;
		rc = 0;
	}

	mutex_exit(&sess->mtx);

	return (rc);
}

/* This function is used by logic that adds session to the sessions AVL */
int
krrp_sess_compare_id(const void *opaque_sess1, const void *opaque_sess2)
{
	size_t i;
	const krrp_sess_t *sess1, *sess2;

	sess1 = opaque_sess1;
	sess2 = opaque_sess2;

	for (i = 0; i < UUID_PRINTABLE_STRING_LENGTH - 1; i++) {
		if (sess1->id[i] > sess2->id[i])
			return (1);

		if (sess1->id[i] < sess2->id[i])
			return (-1);
	}

	return (0);
}

int
krrp_sess_set_id(krrp_sess_t *sess, const char *sess_id,
    krrp_error_t *error)
{
	int rc = -1;

	VERIFY(sess_id != NULL);

	if (strlen(sess_id) != (UUID_PRINTABLE_STRING_LENGTH - 1)) {
		krrp_error_set(error, KRRP_ERRNO_SESSID, EINVAL);
		goto out;
	}

	(void) strlcpy(sess->id, sess_id, UUID_PRINTABLE_STRING_LENGTH);
	rc = 0;

out:
	return (rc);
}

static int
krrp_sess_set_kstat_id(krrp_sess_t *sess, const char *kstat_id,
    krrp_error_t *error)
{
	int rc = -1;

	VERIFY(kstat_id != NULL);

	if (strlen(kstat_id) != (KRRP_KSTAT_ID_STRING_LENGTH - 1)) {
		krrp_error_set(error, KRRP_ERRNO_KSTATID, EINVAL);
		goto out;
	}

	(void) strlcpy(sess->kstat.id, kstat_id, KRRP_KSTAT_ID_STRING_LENGTH);
	rc = 0;

out:
	return (rc);
}

static int
krrp_sess_set_auth_digest(krrp_sess_t *sess, const char *auth_digest,
    krrp_error_t *error)
{
	if (auth_digest != NULL) {
		if (strlcpy(sess->auth_digest, auth_digest,
		    KRRP_AUTH_DIGEST_MAX_LEN) >= KRRP_AUTH_DIGEST_MAX_LEN) {
			krrp_error_set(error, KRRP_ERRNO_AUTH, EINVAL);
			return (-1);
		}
	}

	return (0);
}

static void
krrp_sess_kstat_init(krrp_sess_t *sess)
{
	sess->kstat.ctx = kstat_create("krrp_session", 0,
	    sess->kstat.id, "misc", KSTAT_TYPE_NAMED,
	    0, KSTAT_FLAG_VIRTUAL);

	if (sess->kstat.ctx == NULL) {
		cmn_err(CE_WARN, "Failed to create kstat with id %s"
		    "for session %s", sess->kstat.id, sess->id);
		return;
	}

	sess->kstat.ctx->ks_private = sess;

	switch (sess->type) {
	case KRRP_SESS_SENDER:
		sess->kstat.ctx->ks_data =
		    &sess->kstat.data.sender;
		sess->kstat.ctx->ks_data_size =
		    sizeof (sess->kstat.data.sender);
		sess->kstat.ctx->ks_ndata =
		    NUM_OF_FIELDS(sess->kstat.data.sender);
		(void) memcpy(sess->kstat.ctx->ks_data,
		    &sess_sender_stats_templ,
		    sizeof (krrp_sess_sender_kstat_t));
		break;
	case KRRP_SESS_RECEIVER:
		sess->kstat.ctx->ks_data =
		    &sess->kstat.data.receiver;
		sess->kstat.ctx->ks_data_size =
		    sizeof (sess->kstat.data.receiver);
		sess->kstat.ctx->ks_ndata =
		    NUM_OF_FIELDS(sess->kstat.data.receiver);
		(void) memcpy(sess->kstat.ctx->ks_data,
		    &sess_receiver_stats_templ,
		    sizeof (krrp_sess_receiver_kstat_t));
		break;
	case KRRP_SESS_COMPOUND:
		sess->kstat.ctx->ks_data =
		    &sess->kstat.data.compound;
		sess->kstat.ctx->ks_data_size =
		    sizeof (sess->kstat.data.compound);
		sess->kstat.ctx->ks_ndata =
		    NUM_OF_FIELDS(sess->kstat.data.compound);
		(void) memcpy(sess->kstat.ctx->ks_data,
		    &sess_compound_stats_templ,
		    sizeof (krrp_sess_compound_kstat_t));
		break;
	}

	sess->kstat.ctx->ks_update = &krrp_sess_kstat_update;
	kstat_install(sess->kstat.ctx);
}

static int
krrp_sess_kstat_update(kstat_t *ks, int rw)
{
	int rc = EACCES;
	krrp_sess_t *sess = ks->ks_private;

	if (rw == KSTAT_WRITE)
		goto out;

	if (krrp_sess_inc_ref_cnt(sess) != 0) {
		rc = EIO;
		goto out;
	}

	switch (sess->type) {
	case KRRP_SESS_SENDER:
		krrp_sess_sender_kstat_update(sess, ks);
		break;
	case KRRP_SESS_RECEIVER:
		krrp_sess_receiver_kstat_update(sess, ks);
		break;
	case KRRP_SESS_COMPOUND:
		krrp_sess_compound_kstat_update(sess, ks);
		break;
	}

	rc = 0;
	krrp_sess_dec_ref_cnt(sess);

out:
	return (rc);
}

/*
 * To extend stats need to add new field to KRRP_SESS_STAT_NAME_MAP
 * in krrp_session.h and write corresponding update-code
 * in the following function
 */
static void
krrp_sess_sender_kstat_update(krrp_sess_t *sess, kstat_t *ks)
{
	krrp_sess_sender_kstat_t *stats = &sess->kstat.data.sender;

	/* The RPO-time between snap create and total recv by the remote ZFS */
	stats->avg_rpo.value.ui64 =
	    sess->stream_read->avg_total_rpo.value;

	/* The RPO-time between snap create and total recv by the remote KRRP */
	stats->avg_network_rpo.value.ui64 = sess->stream_read->avg_rpo.value;

	stats->bytes_tx.value.ui64 = sess->conn->bytes_tx;
	stats->bytes_rx.value.ui64 = sess->conn->bytes_rx;

	/* The TXG that is now read by ZFS */
	stats->cur_send_stream_txg.value.ui64 = sess->stream_read->cur_send_txg;

	/* The TXG that is now sent over Network */
	stats->cur_send_network_txg.value.ui64 = sess->conn->cur_txg;

	/* The last TXG that was complettly received by the remote ZFS */
	stats->last_stream_ack_txg.value.ui64 =
	    sess->stream_read->last_full_ack_txg;

	/* The last TXG that was complettly received by the remote KRRP */
	stats->last_network_ack_txg.value.ui64 =
	    sess->stream_read->last_ack_txg;

	stats->max_pdu_seq_num.value.ui64 =
	    sess->fl_ctrl.max_pdu_seq_num_orig;
	stats->max_pdu_seq_num_adjusted.value.ui64 =
	    sess->fl_ctrl.max_pdu_seq_num;
	stats->cur_pdu_seq_num.value.ui64 = sess->fl_ctrl.cur_pdu_seq_num;
	stats->fl_ctrl_window_size.value.ui64 = sess->fl_ctrl.cwnd;

	stats->rbytes.value.ui64 = sess->stream_read->bytes_processed;

	stats->mem_used.value.ui64 =
	    krrp_pdu_engine_get_used_mem(sess->data_pdu_engine);

	stats->uptime.value.ui64 =
	    (gethrtime() - ks->ks_crtime) / 1000 / 1000;
}

static void
krrp_sess_receiver_kstat_update(krrp_sess_t *sess, kstat_t *ks)
{
	krrp_sess_receiver_kstat_t *stats =
	    &sess->kstat.data.receiver;

	stats->bytes_tx.value.ui64 = sess->conn->bytes_tx;
	stats->bytes_rx.value.ui64 = sess->conn->bytes_rx;

	/* The TXG that is now wrote by ZFS */
	stats->cur_recv_stream_txg.value.ui64 =
	    sess->stream_write->cur_recv_txg;

	/* The TXG that is now received from Network */
	stats->cur_recv_network_txg.value.ui64 = sess->conn->cur_txg;

	stats->max_pdu_seq_num.value.ui64 = sess->fl_ctrl.max_pdu_seq_num;
	stats->cur_pdu_seq_num.value.ui64 = sess->fl_ctrl.cur_pdu_seq_num;

	stats->wbytes.value.ui64 = sess->stream_write->bytes_processed;

	stats->mem_used.value.ui64 =
	    krrp_pdu_engine_get_used_mem(sess->data_pdu_engine);

	stats->uptime.value.ui64 =
	    (gethrtime() - ks->ks_crtime) / 1000 / 1000;
}

static void
krrp_sess_compound_kstat_update(krrp_sess_t *sess, kstat_t *ks)
{
	krrp_sess_compound_kstat_t *stats =
	    &sess->kstat.data.compound;

	/* The RPO-time between snap create and total recv by the ZFS */
	stats->avg_rpo.value.ui64 =
	    sess->stream_read->avg_total_rpo.value;

	/* The TXG that is now read by ZFS */
	stats->cur_send_stream_txg.value.ui64 =
	    sess->stream_read->cur_send_txg;

	/* The TXG that is now wrote by ZFS */
	stats->cur_recv_stream_txg.value.ui64 =
	    sess->stream_write->cur_recv_txg;

	stats->rbytes.value.ui64 = sess->stream_read->bytes_processed;
	stats->wbytes.value.ui64 = sess->stream_write->bytes_processed;

	stats->mem_used.value.ui64 =
	    krrp_pdu_engine_get_used_mem(sess->data_pdu_engine);

	stats->uptime.value.ui64 =
	    (gethrtime() - ks->ks_crtime) / 1000 / 1000;
}

static void
krrp_sess_lr_stream_cb(krrp_stream_cb_ev_t ev, uintptr_t ev_arg,
    void *void_sess)
{
	krrp_sess_t *sess = void_sess;

	if (krrp_sess_inc_ref_cnt(sess) != 0) {
		if (ev == KRRP_STREAM_DATA_PDU)
			krrp_pdu_rele((krrp_pdu_t *)ev_arg);

		return;
	}

	switch (ev) {
	case KRRP_STREAM_DATA_PDU:
		krrp_sess_lr_data_pdu_from_stream(sess,
		    (krrp_pdu_data_t *)ev_arg);
		break;
	case KRRP_STREAM_TXG_RECV_DONE:
		krrp_sess_lr_txg_recv_done(sess, (uint64_t)ev_arg);
		break;
	case KRRP_STREAM_SEND_DONE:
		krrp_sess_lr_send_done(sess);
		break;
	case KRRP_STREAM_ERROR:
		krrp_sess_stream_error(sess, (krrp_error_t *)ev_arg);
		break;
	default:
		break;
	}

	krrp_sess_dec_ref_cnt(sess);
}

static void
krrp_sess_ll_stream_cb(krrp_stream_cb_ev_t ev, uintptr_t ev_arg,
    void *void_sess)
{
	krrp_sess_t *sess = void_sess;

	if (krrp_sess_inc_ref_cnt(sess) != 0) {
		if (ev == KRRP_STREAM_DATA_PDU)
			krrp_pdu_rele((krrp_pdu_t *)ev_arg);

		return;
	}

	switch (ev) {
	case KRRP_STREAM_DATA_PDU:
		krrp_sess_ll_data_pdu_from_stream(sess,
		    (krrp_pdu_data_t *)ev_arg);
		break;
	case KRRP_STREAM_TXG_RECV_DONE:
		krrp_sess_ll_txg_recv_done(sess, (uint64_t)ev_arg);
		break;
	case KRRP_STREAM_SEND_DONE:
		krrp_sess_ll_send_done(sess);
		break;
	case KRRP_STREAM_ERROR:
		krrp_sess_stream_error(sess, (krrp_error_t *)ev_arg);
		break;
	default:
		break;
	}

	krrp_sess_dec_ref_cnt(sess);
}

static void
krrp_sess_stream_error(krrp_sess_t *sess, krrp_error_t *error)
{
	cmn_err(CE_WARN, "An stream error has occured: %s (%d)",
	    krrp_error_errno_to_str(error->krrp_errno),
	    error->unix_errno);

	switch (sess->type) {
	case KRRP_SESS_SENDER:
		krrp_stream_stop(sess->stream_read);
		break;
	case KRRP_SESS_RECEIVER:
		krrp_stream_stop(sess->stream_write);
		break;
	case KRRP_SESS_COMPOUND:
		krrp_stream_stop(sess->stream_read);
		krrp_stream_stop(sess->stream_write);
		break;
	}

	krrp_sess_error(sess, error);
}

static void
krrp_sess_txg_recv_done(krrp_sess_t *sess, uint64_t txg, boolean_t complete)
{
	krrp_pdu_ctrl_t *pdu = NULL;

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "Failed to allocate Ctrl PDU "
		    "to send KRRP_OPCODE_TXG_ACK/KRRP_OPCODE_TXG_ACK2");
		krrp_sess_nomem_error(sess);
		return;
	}

	if (complete)
		pdu->hdr->opcode = KRRP_OPCODE_TXG_ACK2;
	else
		pdu->hdr->opcode = KRRP_OPCODE_TXG_ACK;

	*((uint64_t *)(pdu->hdr->data)) = htonll(txg);

	krrp_queue_put(sess->ctrl_tx_queue, pdu);
}

static void
krrp_sess_post_send_done_uevent(krrp_sess_t *sess)
{
	nvlist_t *attrs = fnvlist_alloc();

	mutex_enter(&sess->mtx);
	sess->running = B_FALSE;
	mutex_exit(&sess->mtx);

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, attrs, sess->id);
	krrp_svc_post_uevent(ESC_KRRP_SESS_SEND_DONE, attrs);
	fnvlist_free(attrs);
}

static void
krrp_sess_post_error_uevent(krrp_sess_t *sess, krrp_error_t *error)
{
	nvlist_t *attrs = fnvlist_alloc();

	krrp_error_to_nvl(error, &attrs);

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, attrs, sess->id);
	krrp_svc_post_uevent(ESC_KRRP_SESS_ERROR, attrs);

	fnvlist_free(attrs);
}

static void
krrp_sess_pdu_engine_cb(void *void_sess, size_t released_pdus)
{
	krrp_pdu_ctrl_t *pdu = NULL;
	krrp_sess_t *sess = void_sess;
	uint64_t max_pdu_seq_num;

	ASSERT(sess->type == KRRP_SESS_RECEIVER);

	if (krrp_sess_inc_ref_cnt(sess) != 0)
		return;

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "Failed to allocate Ctrl PDU "
		    "to send KRRP_OPCODE_FL_CTRL_UPDATE");
		krrp_sess_nomem_error(sess);
		goto out;
	}

	pdu->hdr->opcode = KRRP_OPCODE_FL_CTRL_UPDATE;

	max_pdu_seq_num = krrp_sess_fl_ctrl_update_rx(&sess->fl_ctrl,
	    released_pdus);
	*((uint64_t *)(pdu->hdr->data)) = htonll(max_pdu_seq_num);

	krrp_queue_put(sess->ctrl_tx_queue, pdu);

out:
	krrp_sess_dec_ref_cnt(sess);
}

static void
krrp_sess_conn_cb(void *void_conn, krrp_conn_cb_ev_t ev, uintptr_t ev_arg,
    void *void_sess)
{
	krrp_sess_t *sess = void_sess;
	krrp_conn_t *conn = void_conn;

	if (krrp_sess_inc_ref_cnt(sess) != 0) {
		if (ev == KRRP_CONN_DATA_PDU || ev == KRRP_CONN_CTRL_PDU)
			krrp_pdu_rele((krrp_pdu_t *)ev_arg);

		return;
	}

	switch (ev) {
	case KRRP_CONN_DATA_PDU:
		/* Data-PDU flow: Sender >>> Receiver */
		if (sess->type == KRRP_SESS_SENDER) {
			krrp_error_t error;

			krrp_error_set(&error, KRRP_ERRNO_PROTO, EBADMSG);
			krrp_sess_error(sess, &error);
			break;
		}

		krrp_sess_data_pdu_from_network(sess,
		    (krrp_pdu_data_t *)ev_arg);
		break;
	case KRRP_CONN_CTRL_PDU:
		krrp_sess_ctrl_pdu_from_network(sess,
		    (krrp_pdu_ctrl_t *)ev_arg);
		break;
	case KRRP_CONN_ERROR:
		krrp_sess_conn_error(sess, conn,
		    (krrp_error_t *)ev_arg);
		break;
	default:
		cmn_err(CE_PANIC, "Unknown conn cb-event");
	}

	krrp_sess_dec_ref_cnt(sess);
}

/* ARGSUSED */
static void
krrp_sess_conn_error(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error)
{
	boolean_t error_case;
	krrp_sess_stop_ping(sess);

	mutex_enter(&sess->mtx);
	error_case = !sess->shutdown;
	mutex_exit(&sess->mtx);

	if (error_case) {
		cmn_err(CE_WARN, "An connection error has occured: %s (%d)",
		    krrp_error_errno_to_str(error->krrp_errno),
		    error->unix_errno);

		krrp_sess_error(sess, error);
	}
}

static void
krrp_sess_ctrl_pdu_from_network(krrp_sess_t *sess, krrp_pdu_ctrl_t *pdu)
{
	krrp_opcode_t opcode;
	krrp_hdr_ctrl_t *hdr;

	hdr = krrp_pdu_hdr(pdu);
	opcode = krrp_pdu_opcode(pdu);

	switch (opcode) {
	case KRRP_OPCODE_TXG_ACK:
	case KRRP_OPCODE_TXG_ACK2:
		{
			uint64_t txg;

			txg = ntohll(*((uint64_t *)(hdr->data)));
			if (opcode == KRRP_OPCODE_TXG_ACK2)
				krrp_stream_txg_confirmed(sess->stream_read,
				    txg, B_TRUE);
			else
				krrp_stream_txg_confirmed(sess->stream_read,
				    txg, B_FALSE);
		}
		break;
	case KRRP_OPCODE_FL_CTRL_UPDATE:
		krrp_sess_fl_ctrl_update_tx(&sess->fl_ctrl,
		    ntohll(*((uint64_t *)(hdr->data))));
		break;
	case KRRP_OPCODE_SEND_DONE:
		krrp_sess_post_send_done_uevent(sess);
		break;
	case KRRP_OPCODE_PING:
		krrp_sess_ping_request(sess);
		break;
	case KRRP_OPCODE_PONG:
		sess->ping_wait_for_response = B_FALSE;
		break;
	case KRRP_OPCODE_ERROR:
		break;
	case KRRP_OPCODE_SHUTDOWN:
		mutex_enter(&sess->mtx);

		if (sess->shutdown) {
			cv_signal(&sess->cv);
		} else {
			sess->shutdown = B_TRUE;
			krrp_sess_send_shutdown(sess);
		}

		mutex_exit(&sess->mtx);
		break;
	default:
		break;
	}

	krrp_pdu_rele((krrp_pdu_t *)pdu);
}

static void
krrp_sess_ping_request(krrp_sess_t *sess)
{
	krrp_pdu_ctrl_t *pdu = NULL;

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "No memory to send PING response");
		return;
	}

	pdu->hdr->opcode = KRRP_OPCODE_PONG;

	krrp_queue_put(sess->ctrl_tx_queue, pdu);
}

static uint64_t
krrp_sess_fl_ctrl_update_rx(krrp_fl_ctrl_t *fl_ctrl,
    size_t window_offset)
{
	uint64_t max_pdu_seq_num;

	mutex_enter(&fl_ctrl->mtx);
	fl_ctrl->max_pdu_seq_num += window_offset;
	max_pdu_seq_num = fl_ctrl->max_pdu_seq_num;
	mutex_exit(&fl_ctrl->mtx);

	return (max_pdu_seq_num);
}

static void
krrp_sess_fl_ctrl_update_tx(krrp_fl_ctrl_t *fl_ctrl, uint64_t max_pdu_seq_num)
{
	uint64_t cur_window, cur_pdu_seq_num;

	mutex_enter(&fl_ctrl->mtx);

	cur_pdu_seq_num = fl_ctrl->cur_pdu_seq_num;

	cur_window = max_pdu_seq_num - cur_pdu_seq_num;
	krrp_sess_fl_ctrl_calc_cwnd_window(fl_ctrl, cur_window);

	DTRACE_PROBE1(krrp_fl_ctrl_cwnd, uint64_t, fl_ctrl->cwnd);

	fl_ctrl->max_pdu_seq_num_orig = max_pdu_seq_num;
	fl_ctrl->max_pdu_seq_num = cur_pdu_seq_num + fl_ctrl->cwnd;

	cv_signal(&fl_ctrl->cv);
	mutex_exit(&fl_ctrl->mtx);
}

static void
krrp_sess_fl_ctrl_calc_cwnd_window(krrp_fl_ctrl_t *fl_ctrl,
    uint64_t new_recv_window)
{
	switch (krrp_sess_cwnd_state) {
	default:
	case 0:
		fl_ctrl->cwnd = new_recv_window;
		break;
	case 1:
		if (fl_ctrl->cwnd == 0)
			fl_ctrl->cwnd = new_recv_window / 2;
		else if (new_recv_window >
		    (fl_ctrl->cwnd + (fl_ctrl->cwnd >> 3)))
			fl_ctrl->cwnd = (fl_ctrl->cwnd + new_recv_window) >> 1;
		else if (new_recv_window < fl_ctrl->cwnd)
			fl_ctrl->cwnd = new_recv_window >> 1;
		break;
	case 2:
		if (fl_ctrl->cwnd == 0)
			fl_ctrl->cwnd = new_recv_window -
			    (new_recv_window >> 2);
		else if (new_recv_window >
		    (fl_ctrl->cwnd + (fl_ctrl->cwnd >> 3)))
			fl_ctrl->cwnd = (fl_ctrl->cwnd + new_recv_window) >> 1;
		else if (new_recv_window < fl_ctrl->cwnd)
			fl_ctrl->cwnd = new_recv_window -
			    (new_recv_window >> 3);
		break;
	}
}

static int
krrp_sess_fl_ctrl_validate(krrp_sess_t *sess, krrp_hdr_data_t *hdr)
{
	int rc = -1;
	krrp_fl_ctrl_t *fl_ctrl;

	fl_ctrl = &sess->fl_ctrl;

	mutex_enter(&fl_ctrl->mtx);
	if (!fl_ctrl->disabled) {
		if (hdr->pdu_seq_num > fl_ctrl->max_pdu_seq_num) {
			cmn_err(CE_WARN, "Detected violation of "
			    "flow control rules: [%" PRIu64 "] > "
			    "[%" PRIu64 "]", hdr->pdu_seq_num,
			    fl_ctrl->max_pdu_seq_num);
			goto out;
		}
	}

	rc = 0;
	fl_ctrl->cur_pdu_seq_num = hdr->pdu_seq_num;

out:
	mutex_exit(&fl_ctrl->mtx);
	return (rc);
}


static void
krrp_sess_data_pdu_from_network(krrp_sess_t *sess, krrp_pdu_data_t *pdu)
{
	krrp_hdr_data_t *hdr;

	hdr = krrp_pdu_hdr(pdu);

	pdu->txg = hdr->txg;

	if (hdr->flags & KRRP_HDR_FLAG_INIT_PDU) {
		pdu->initial = B_TRUE;

		DTRACE_PROBE1(krrp_network_recv_txg_start,
		    uint64_t, pdu->txg);
	}

	if (hdr->flags & KRRP_HDR_FLAG_FINI_PDU) {
		pdu->final = B_TRUE;

		DTRACE_PROBE1(krrp_network_recv_txg_stop,
		    uint64_t, pdu->txg);

		krrp_sess_txg_recv_done(sess, pdu->txg, B_FALSE);
	}

	/* Now just ignore, later need to do something */
	(void) krrp_sess_fl_ctrl_validate(sess, krrp_pdu_hdr(pdu));

	if (krrp_sess_recv_without_stream) {
		if (hdr->flags & KRRP_HDR_FLAG_FINI_PDU)
			krrp_sess_txg_recv_done(sess, pdu->txg, B_TRUE);

		krrp_pdu_rele((krrp_pdu_t *)pdu);
		return;
	}

	krrp_queue_put(sess->data_write_queue, pdu);
}

/*
 * The function does the following actions:
 * 1. checks FlowControl
 * 2. retrieves next PDU from TX-Queue
 * 3. assigns PDU SeqNum to the retrieved PDU
 */
static void
krrp_sess_get_data_pdu_to_tx(void *void_sess, krrp_pdu_t **result_pdu)
{
	clock_t time_left = 0;
	krrp_sess_t *sess;
	krrp_fl_ctrl_t *fl_ctrl;
	boolean_t win_open;
	boolean_t queue_is_empty;

	sess = (krrp_sess_t *)void_sess;
	fl_ctrl = &sess->fl_ctrl;

	mutex_enter(&fl_ctrl->mtx);

repeat:
	if ((fl_ctrl->cur_pdu_seq_num < fl_ctrl->max_pdu_seq_num) ||
	    fl_ctrl->disabled) {
		krrp_pdu_t *pdu = NULL;

		win_open = B_TRUE;
		mutex_exit(&fl_ctrl->mtx);
		pdu = krrp_queue_get(sess->data_tx_queue);
		mutex_enter(&fl_ctrl->mtx);
		if (pdu != NULL) {
			krrp_hdr_data_t *hdr;

			hdr = (krrp_hdr_data_t *)krrp_pdu_hdr(pdu);
			fl_ctrl->cur_pdu_seq_num++;
			hdr->pdu_seq_num = fl_ctrl->cur_pdu_seq_num;
			*result_pdu = pdu;
			queue_is_empty = B_FALSE;
		} else
			queue_is_empty = B_TRUE;

		time_left = 0;
	} else {
		win_open = B_FALSE;
		if (krrp_queue_length(sess->data_tx_queue) == 0)
			queue_is_empty = B_TRUE;
		else
			queue_is_empty = B_FALSE;

		time_left = cv_reltimedwait(&fl_ctrl->cv, &fl_ctrl->mtx,
		    MSEC_TO_TICK(100), TR_CLOCK_TICK);
	}

	if (time_left > 0)
		goto repeat;

	mutex_exit(&fl_ctrl->mtx);

	DTRACE_PROBE2(krrp_data_path_state, boolean_t, win_open,
	    boolean_t, queue_is_empty);
}

static void
krrp_sess_nomem_error(krrp_sess_t *sess)
{
	krrp_error_t error;

	krrp_error_set(&error, KRRP_ERRNO_NOMEM, 0);
	krrp_sess_error(sess, &error);
}

static void
krrp_sess_error(krrp_sess_t *sess, krrp_error_t *error)
{
	mutex_enter(&sess->mtx);

	if (sess->error.krrp_errno == 0) {
		sess->error.krrp_errno = error->krrp_errno;
		sess->error.unix_errno = error->unix_errno;
		sess->running = B_FALSE;

		krrp_sess_post_error_uevent(sess, &sess->error);
	}

	mutex_exit(&sess->mtx);
}

static int
krrp_sess_inc_ref_cnt(krrp_sess_t *sess)
{
	int rc = -1;

	mutex_enter(&sess->mtx);
	if (sess->destroying)
		goto out;

	rc = 0;
	sess->ref_cnt++;

out:
	mutex_exit(&sess->mtx);

	return (rc);
}

static void
krrp_sess_dec_ref_cnt(krrp_sess_t *sess)
{
	mutex_enter(&sess->mtx);
	ASSERT(sess->ref_cnt > 0);
	sess->ref_cnt--;
	cv_signal(&sess->cv);
	mutex_exit(&sess->mtx);
}

int
krrp_sess_try_hold(krrp_sess_t *sess)
{
	int rc = -1;

	mutex_enter(&sess->mtx);
	if (sess->on_hold)
		goto out;

	rc = 0;
	sess->on_hold = B_TRUE;

out:
	mutex_exit(&sess->mtx);

	return (rc);
}

void
krrp_sess_rele(krrp_sess_t *sess)
{
	mutex_enter(&sess->mtx);
	ASSERT(sess->on_hold);
	sess->on_hold = B_FALSE;
	mutex_exit(&sess->mtx);
}

static void
krrp_sess_lr_data_pdu_from_stream(krrp_sess_t *sess, krrp_pdu_data_t *pdu)
{
	krrp_hdr_data_t *hdr;

	hdr = krrp_pdu_hdr(pdu);

	hdr->opcode = KRRP_OPCODE_DATA_WRITE;
	hdr->txg = pdu->txg;
	hdr->payload_sz = pdu->cur_data_sz;

	if (pdu->initial)
		hdr->flags |= KRRP_HDR_FLAG_INIT_PDU;

	if (pdu->final)
		hdr->flags |= KRRP_HDR_FLAG_FINI_PDU;

	krrp_queue_put(sess->data_tx_queue, pdu);
}

static void
krrp_sess_ll_data_pdu_from_stream(krrp_sess_t *sess, krrp_pdu_data_t *pdu)
{
	if (pdu->final)
		krrp_stream_txg_confirmed(sess->stream_read, pdu->txg, B_FALSE);

	krrp_queue_put(sess->data_write_queue, pdu);
}

static void
krrp_sess_lr_txg_recv_done(krrp_sess_t *sess, uint64_t txg)
{
	krrp_sess_txg_recv_done(sess, txg, B_TRUE);
}

static void
krrp_sess_ll_txg_recv_done(krrp_sess_t *sess, uint64_t txg)
{
	krrp_stream_txg_confirmed(sess->stream_read, txg, B_TRUE);
}

static void
krrp_sess_lr_send_done(krrp_sess_t *sess)
{
	krrp_pdu_ctrl_t *pdu = NULL;

	/* Notify the receiver that send has been done */
	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "Failed to allocate Ctrl PDU "
		    "to send KRRP_OPCODE_SEND_DONE");
		krrp_sess_nomem_error(sess);
		goto out;
	}

	pdu->hdr->opcode = KRRP_OPCODE_SEND_DONE;

	krrp_queue_put(sess->ctrl_tx_queue, pdu);

out:
	/* Notify the userspace that send has been done */
	krrp_sess_post_send_done_uevent(sess);
}

static void
krrp_sess_ll_send_done(krrp_sess_t *sess)
{
	/* Notify the userspace that send has been done */
	krrp_sess_post_send_done_uevent(sess);
}

static void
krrp_sess_send_shutdown(krrp_sess_t *sess)
{
	krrp_pdu_ctrl_t *pdu = NULL;

	krrp_pdu_ctrl_alloc(&pdu, KRRP_PDU_WITH_HDR);
	if (pdu == NULL) {
		cmn_err(CE_WARN, "Failed to allocate Ctrl PDU "
		    "to send KRRP_OPCODE_SHUTDOWN");
		return;
	}

	pdu->hdr->opcode = KRRP_OPCODE_SHUTDOWN;

	krrp_queue_put(sess->ctrl_tx_queue, pdu);
}
