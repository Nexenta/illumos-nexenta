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

#include <sys/types.h>
#include <sys/conf.h>
#include <sys/sysmacros.h>
#include <sys/cmn_err.h>
#include <sys/stat.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sdt.h>
#include <sys/avl.h>
#include <sys/debug.h>
#include <sys/sysevent.h>
#include <sys/sysevent_impl.h>

#include "krrp_protocol.h"
#include "krrp_connection.h"
#include "krrp_params.h"
#include "krrp_svc.h"

static krrp_sess_t *krrp_svc_lookup_session_no_lock(const char *sess_id);
static void krrp_svc_unregister_all_sessions(void);
static void krrp_svc_unregister_session_common(krrp_sess_t *s);
static void krrp_svc_on_new_ks_cb(ksocket_t new_ks);
static void krrp_svc_on_server_error_cb(krrp_error_t *error);
static void krrp_svc_new_conn_handler(void *void_conn);

static void krrp_svc_ref_cnt_wait(void);
static void krrp_svc_send_error(krrp_conn_t *conn, krrp_error_t *error);

int krrp_ping_period = 5000;

krrp_svc_t krrp_svc;
int krrp_svc_created = 0;

krrp_svc_t *
krrp_svc_get_instance(void)
{
	if (!krrp_svc_created) {
		(void) memset(&krrp_svc, 0, sizeof (krrp_svc_t));
		krrp_svc.state = KRRP_SVCS_CREATED;
		krrp_svc_created = 1;
	}

	return (&krrp_svc);
}

void
krrp_svc_init(void)
{
	VERIFY3U(krrp_svc.state, ==, KRRP_SVCS_CREATED);

	mutex_init(&krrp_svc.mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&krrp_svc.cv, NULL, CV_DEFAULT, NULL);

	avl_create(&krrp_svc.sessions, &krrp_sess_compare_id,
	    sizeof (krrp_sess_t), offsetof(krrp_sess_t, node));

	krrp_svc.ev_chan = NULL;
	krrp_svc.state = KRRP_SVCS_DETACHED;
}

void
krrp_svc_fini(void)
{
	mutex_enter(&krrp_svc.mtx);

	avl_destroy(&krrp_svc.sessions);
	cv_destroy(&krrp_svc.cv);

	if (krrp_svc.ev_chan)
		(void) sysevent_evc_unbind(krrp_svc.ev_chan);

	mutex_exit(&krrp_svc.mtx);
	mutex_destroy(&krrp_svc.mtx);

	(void) memset(&krrp_svc, 0, sizeof (krrp_svc_t));

	krrp_svc.state = KRRP_SVCS_CREATED;
}

boolean_t
krrp_svc_is_enabled(void)
{
	boolean_t res;

	krrp_svc_lock(&krrp_svc);
	res = krrp_svc.state == KRRP_SVCS_ENABLED ? B_TRUE : B_FALSE;
	krrp_svc_unlock(&krrp_svc);

	return (res);
}

void
krrp_svc_attach(dev_info_t *dip)
{
	krrp_svc_lock(&krrp_svc);
	VERIFY3U(krrp_svc.state, ==, KRRP_SVCS_DETACHED);
	krrp_svc.state = KRRP_SVCS_DISABLED;
	krrp_svc.dip = dip;
	krrp_svc_unlock(&krrp_svc);
}

int
krrp_svc_detach(void)
{
	krrp_svc_lock(&krrp_svc);
	if (krrp_svc.state != KRRP_SVCS_DISABLED) {
		krrp_svc_unlock(&krrp_svc);
		return (-1);
	}

	krrp_svc.state = KRRP_SVCS_DETACHED;
	krrp_svc.dip = NULL;
	krrp_svc_unlock(&krrp_svc);

	return (0);
}

int
krrp_svc_enable(krrp_error_t *error)
{
	int rc = 0;

	krrp_svc_lock(&krrp_svc);

	switch (krrp_svc.state) {
	case KRRP_SVCS_DISABLED:
		krrp_svc.state = KRRP_SVCS_ENABLING;
		break;
	case KRRP_SVCS_ENABLING:
	case KRRP_SVCS_DISABLING:
		krrp_error_set(error, KRRP_ERRNO_BUSY, 0);
		rc = -1;
		break;
	default:
		VERIFY(0);
	}

	krrp_svc_unlock(&krrp_svc);

	if (rc != 0)
		return (rc);

	/*
	 * This taskq will process the following tasks:
	 * - PDU rele
	 * - DBLK engine destroy
	 * - processing of new incoming connections
	 */
	krrp_svc.aux_taskq = taskq_create("krrp_aux_taskq", 10,
	    minclsyspri, 128, 16384, TASKQ_DYNAMIC);

	if (krrp_pdu_engine_global_init() != 0)
		goto err;

	krrp_server_create(&krrp_svc.server, &krrp_svc_on_new_ks_cb,
	    &krrp_svc_on_server_error_cb);

	krrp_svc_lock(&krrp_svc);
	krrp_svc.state = KRRP_SVCS_ENABLED;
	krrp_svc_unlock(&krrp_svc);

	return (0);

err:
	if (krrp_svc.aux_taskq != NULL) {
		taskq_destroy(krrp_svc.aux_taskq);
		krrp_svc.aux_taskq = NULL;
	}

	krrp_svc_lock(&krrp_svc);
	krrp_svc.state = KRRP_SVCS_DISABLED;
	krrp_svc_unlock(&krrp_svc);

	return (-1);
}

int
krrp_svc_disable(krrp_error_t *error)
{
	int rc = 0;

	krrp_svc_lock(&krrp_svc);

	switch (krrp_svc.state) {
	case KRRP_SVCS_ENABLED:
		krrp_svc.state = KRRP_SVCS_DISABLING;
		break;
	case KRRP_SVCS_ENABLING:
	case KRRP_SVCS_DISABLING:
		krrp_error_set(error, KRRP_ERRNO_BUSY, 0);
		rc = -1;
		break;
	default:
		VERIFY(0);
	}

	krrp_svc_unlock(&krrp_svc);

	if (rc != 0)
		return (rc);

	krrp_server_destroy(krrp_svc.server);
	krrp_svc.server = NULL;

	/* Wait until all our clients finished */
	krrp_svc_ref_cnt_wait();

	krrp_svc_unregister_all_sessions();

	krrp_pdu_engine_global_fini();

	taskq_destroy(krrp_svc.aux_taskq);

	krrp_svc_lock(&krrp_svc);
	krrp_svc.state = KRRP_SVCS_DISABLED;
	krrp_svc_unlock(&krrp_svc);

	return (0);
}

int
krrp_svc_config(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error)
{
	int rc;
	krrp_cfg_type_t cfg_type;

	rc = krrp_param_get(KRRP_PARAM_CFG_TYPE, params,
	    (void *) &cfg_type);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_CFGTYPE, ENOENT);
		goto out;
	}

	switch (cfg_type) {
	case KRRP_SVC_CFG_TYPE_SERVER:
		if (result == NULL) {
			rc = krrp_server_set_config(krrp_svc.server,
			    params, error);
		} else {
			rc = krrp_server_get_config(krrp_svc.server,
			    result, error);
		}

		break;
	default:
		krrp_error_set(error, KRRP_ERRNO_CFGTYPE, EINVAL);
		rc = -1;
	}

out:
	return (rc);
}

void
krrp_svc_state(nvlist_t *out_nvl)
{
	boolean_t svc_enabled, srv_running = B_FALSE;

	svc_enabled = krrp_svc_is_enabled();
	if (svc_enabled)
		srv_running = krrp_server_is_running(krrp_svc.server);

	VERIFY3U(krrp_param_put(KRRP_PARAM_SVC_ENABLED,
	    out_nvl, &svc_enabled), ==, 0);

	VERIFY3U(krrp_param_put(KRRP_PARAM_SRV_RUNNING,
	    out_nvl, &srv_running), ==, 0);
}

int
krrp_svc_register_session(krrp_sess_t *sess, krrp_error_t *error)
{
	krrp_svc_lock(&krrp_svc);

	if (krrp_svc_lookup_session_no_lock(sess->id) != NULL) {
		krrp_svc_unlock(&krrp_svc);
		krrp_error_set(error, KRRP_ERRNO_SESS, EALREADY);
		return (-1);
	}

	avl_add(&krrp_svc.sessions, sess);

	cmn_err(CE_NOTE, "A new session has been registered (id:[%s])",
	    sess->id);

	krrp_svc_unlock(&krrp_svc);

	return (0);
}

int
krrp_svc_unregister_session(krrp_sess_t *sess, krrp_error_t *error)
{
	krrp_svc_lock(&krrp_svc);

	if (krrp_svc_lookup_session_no_lock(sess->id) == NULL) {
		krrp_svc_unlock(&krrp_svc);
		krrp_error_set(error, KRRP_ERRNO_SESS, ENOENT);
		return (-1);
	}

	krrp_svc_unregister_session_common(sess);

	krrp_svc_unlock(&krrp_svc);

	return (0);
}

void
krrp_svc_post_uevent(const char *subclass, nvlist_t *attr_list)
{
	int rc;

	if (krrp_svc.ev_chan == NULL) {
		if (sysevent_evc_bind(KRRP_EVENT_CHANNEL, &krrp_svc.ev_chan,
		    EVCH_HOLD_PEND | EVCH_CREAT) != 0) {
			cmn_err(CE_WARN, "Failed to bind to krrp event "
			    "channel");
			return;
		}
	}

	cmn_err(CE_NOTE, "Publishing KRRP event %s %s", EC_KRRP, subclass);

	rc = sysevent_evc_publish(krrp_svc.ev_chan, EC_KRRP, subclass,
	    KRRP_EVENT_VENDOR, KRRP_EVENT_PUBLISHER, attr_list, EVCH_NOSLEEP);

	if (rc != 0)
		cmn_err(CE_WARN, "Failed to publish KRRP event (%d)", rc);
}

void
krrp_svc_dispatch_task(task_func_t func, void *arg)
{
	VERIFY(taskq_dispatch(krrp_svc.aux_taskq,
	    func, arg, TQ_SLEEP) != 0);
}

static void
krrp_svc_unregister_all_sessions()
{
	krrp_sess_t *s, *s_next;

	krrp_svc_lock(&krrp_svc);

	s = avl_first(&krrp_svc.sessions);
	while (s != NULL) {
		s_next = AVL_NEXT(&krrp_svc.sessions, s);
		krrp_svc_unregister_session_common(s);

		krrp_sess_destroy(s);

		s = s_next;
	}

	krrp_svc_unlock(&krrp_svc);
}

static void
krrp_svc_unregister_session_common(krrp_sess_t *s)
{
	avl_remove(&krrp_svc.sessions, s);
	cmn_err(CE_NOTE, "A session has been unregistered (id:[%s])", s->id);
}

void
krrp_svc_list_sessions(nvlist_t *out_nvl)
{
	struct krrp_nvlist_list {
		nvlist_t				*sess_nvl;
		struct krrp_nvlist_list *next;
	} *nvls_head = NULL, *nvls_cur, **s_nvl_cur;
	s_nvl_cur = &nvls_head;
	krrp_param_array_t param_array;
	size_t nvl_cnt = 0, i;
	krrp_sess_t *sess;


	krrp_svc_lock(&krrp_svc);

	sess = avl_first(&krrp_svc.sessions);
	while (sess != NULL) {
		boolean_t sess_started;
		boolean_t sess_running;

		sess_started = krrp_sess_is_started(sess);
		sess_running = krrp_sess_is_running(sess);
		nvls_cur = kmem_zalloc(sizeof (struct krrp_nvlist_list),
		    KM_SLEEP);

		nvls_cur->sess_nvl = fnvlist_alloc();

		VERIFY3U(krrp_param_put(KRRP_PARAM_SESS_ID,
		    nvls_cur->sess_nvl, (void *)sess->id), ==, 0);
		VERIFY3U(krrp_param_put(KRRP_PARAM_SESS_KSTAT_ID,
		    nvls_cur->sess_nvl, (void *)sess->kstat.id), ==, 0);
		VERIFY3U(krrp_param_put(KRRP_PARAM_SESS_STARTED,
		    nvls_cur->sess_nvl, (void *)&sess_started), ==, 0);
		VERIFY3U(krrp_param_put(KRRP_PARAM_SESS_RUNNING,
		    nvls_cur->sess_nvl, (void *)&sess_running), ==, 0);

		sess = AVL_NEXT(&krrp_svc.sessions, sess);
		nvl_cnt++;

		*s_nvl_cur = nvls_cur;
		s_nvl_cur = &(nvls_cur->next);
	}

	krrp_svc_unlock(&krrp_svc);

	if (nvl_cnt != 0) {
		param_array.array =
		    kmem_zalloc(sizeof (nvlist_t *) * nvl_cnt, KM_SLEEP);
		param_array.nelem = (uint_t)nvl_cnt;

		for (i = 0; i < nvl_cnt; i++) {
			nvls_cur = nvls_head;
			nvls_head = nvls_head->next;

			param_array.array[i] = nvls_cur->sess_nvl;

			kmem_free(nvls_cur, sizeof (struct krrp_nvlist_list));
		}

		VERIFY3U(krrp_param_put(KRRP_PARAM_SESSIONS,
		    out_nvl, (void *)&param_array), ==, 0);

		/*
		 * Need to free the nvls that have
		 * been added to the output nvl
		 */
		for (i = 0; i < nvl_cnt; i++)
			fnvlist_free(param_array.array[i]);

		kmem_free(param_array.array, sizeof (nvlist_t *) * nvl_cnt);
	}
}

krrp_sess_t *
krrp_svc_lookup_session(const char *sess_id)
{
	krrp_sess_t *res;

	krrp_svc_lock(&krrp_svc);
	res = krrp_svc_lookup_session_no_lock(sess_id);
	krrp_svc_unlock(&krrp_svc);

	return (res);
}

static krrp_sess_t *
krrp_svc_lookup_session_no_lock(const char *sess_id)
{
	krrp_error_t error;
	krrp_sess_t srch_sess, *s;

	if (krrp_sess_set_id(&srch_sess, sess_id, &error) != 0)
		return (NULL);

	s = avl_find(&krrp_svc.sessions,
	    (const void *)&srch_sess, NULL);

	return (s);
}

static void
krrp_svc_on_new_ks_cb(ksocket_t new_ks)
{
	krrp_error_t error;
	krrp_conn_t *conn = NULL;

	if (krrp_svc_ref_cnt_try_hold() != 0) {
		(void) ksocket_close(new_ks, CRED());
		return;
	}

	if (krrp_conn_create_from_ksocket(&conn, new_ks, &error) != 0) {
		(void) ksocket_close(new_ks, CRED());
		return;
	}

	krrp_svc_dispatch_task(krrp_svc_new_conn_handler, conn);
}

static void
krrp_svc_on_server_error_cb(krrp_error_t *error)
{
	nvlist_t *attrs = fnvlist_alloc();

	krrp_error_to_nvl(error, &attrs);

	krrp_svc_post_uevent(ESC_KRRP_SERVER_ERROR, attrs);

	fnvlist_free(attrs);
}

/*
 * In this stage we are doing Phase I of Session establishment:
 *
 * The remote hosts must send to us ctrl-pdu with KRRP_OPCODE_ATTACH_SESS
 * opcode and the payload must contain packed NVL that contains
 * KRRP_PARAM_SESS_ID param. After extracting of KRRP_PARAM_SESS_ID
 * we are trying to lookup a session with the extracted sess_id.
 * If the session exists we attach the connection to the session,
 * otherwise send the error to the remote side
 */
static void
krrp_svc_new_conn_handler(void *void_conn)
{
	int rc = -1;
	nvlist_t *params = NULL;
	krrp_conn_t *conn = void_conn;
	krrp_sess_t *sess;
	const char *sess_id = NULL;
	krrp_pdu_ctrl_t *pdu = NULL;
	krrp_error_t error;

	krrp_error_init(&error);
	if (krrp_conn_rx_ctrl_pdu(conn, &pdu, &error) != 0)
		goto out;

	if (krrp_pdu_opcode(pdu) != KRRP_OPCODE_ATTACH_SESS) {
		cmn_err(CE_WARN, "Received an unexpected opcode [%d]",
		    krrp_pdu_opcode(pdu));
		krrp_error_set(&error, KRRP_ERRNO_PROTO, EINVAL);
		goto send_error;
	}

	if (pdu->cur_data_sz == 0) {
		krrp_error_set(&error, KRRP_ERRNO_PROTO, ENODATA);
		goto send_error;
	}

	rc = nvlist_unpack((char *)pdu->dblk->data,
	    pdu->cur_data_sz, &params, KM_SLEEP);
	if (rc != 0) {
		krrp_error_set(&error, KRRP_ERRNO_PROTO, EBADMSG);
		goto send_error;
	}

	rc = krrp_param_get(KRRP_PARAM_SESS_ID, params,
	    (void *) &sess_id);
	if (rc != 0) {
		krrp_error_set(&error, KRRP_ERRNO_SESSID, ENOENT);
		goto send_error;
	}

	rc = -1;
	sess = krrp_svc_lookup_session(sess_id);
	if (sess == NULL) {
		krrp_error_set(&error, KRRP_ERRNO_SESS, ENOENT);
		goto send_error;
	}

	rc = krrp_sess_target_attach_conn(sess, conn, params, &error);
	if (rc != 0 && error.krrp_errno == KRRP_ERRNO_SENDFAIL)
		goto out;

send_error:
	if (rc != 0)
		krrp_svc_send_error(conn, &error);

out:
	if (pdu != NULL)
		krrp_pdu_rele((krrp_pdu_t *)pdu);

	if (rc != 0) {
		if (error.krrp_errno != 0) {
			cmn_err(CE_WARN, "Session estabishment error: %s [%d]",
			    krrp_error_errno_to_str(error.krrp_errno),
			    error.unix_errno);
		}

		krrp_conn_destroy(conn);
	}

	if (params != NULL)
		fnvlist_free(params);

	krrp_svc_ref_cnt_rele();
}

/*
 * At now this function is used only by ksvc_disable logic
 * Before process an ioctl we incement ref_cnt,
 * ksvc_disable logic also works under ref_cnt,
 * so here we wait for all exclude the the ksvc_disable itself
 */
static void
krrp_svc_ref_cnt_wait()
{
	krrp_svc_lock(&krrp_svc);
	while (krrp_svc.ref_cnt > 1)
		cv_wait(&krrp_svc.cv, &krrp_svc.mtx);
	krrp_svc_unlock(&krrp_svc);
}

int
krrp_svc_ref_cnt_try_hold()
{
	krrp_svc_lock(&krrp_svc);
	if (krrp_svc.state != KRRP_SVCS_ENABLED) {
		krrp_svc_unlock(&krrp_svc);
		return (-1);
	}

	krrp_svc.ref_cnt++;
	krrp_svc_unlock(&krrp_svc);
	return (0);
}

void
krrp_svc_ref_cnt_rele()
{
	krrp_svc_lock(&krrp_svc);
	VERIFY(krrp_svc.ref_cnt > 0);
	krrp_svc.ref_cnt--;
	cv_signal(&krrp_svc.cv);
	krrp_svc_unlock(&krrp_svc);
}

static void
krrp_svc_send_error(krrp_conn_t *conn, krrp_error_t *error)
{
	nvlist_t *err_nvl = NULL;
	krrp_error_t err;
	int rc;

	krrp_error_to_nvl(error, &err_nvl);

	rc = krrp_conn_send_ctrl_data(conn,
	    KRRP_OPCODE_ERROR, err_nvl, &err);
	if (rc != 0)
		cmn_err(CE_WARN, "Failed to send Error to "
		    "the remote host: %s [%d]",
		    krrp_error_errno_to_str(err.krrp_errno),
		    err.unix_errno);

	fnvlist_free(err_nvl);
}
