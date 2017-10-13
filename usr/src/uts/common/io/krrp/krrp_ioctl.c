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

#include <sys/sdt.h>

#include <krrp_params.h>

#include "krrp_svc.h"
#include "krrp_session.h"
#include "krrp_ioctl.h"

static boolean_t krrp_is_input_data_required(krrp_ioctl_cmd_t cmd);

static int krrp_ioctl_sess_set_private_data(nvlist_t *params,
	krrp_error_t *error);
static int krrp_ioctl_sess_get_private_data(nvlist_t *params,
    nvlist_t *result, krrp_error_t *error);

static int krrp_ioctl_sess_status(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error);
static int krrp_ioctl_sess_create(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_destroy(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_run(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_send_stop(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_create_conn(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_create_pdu_engine(nvlist_t *params,
    krrp_error_t *error);

static int krrp_ioctl_sess_create_stream(nvlist_t *params,
    boolean_t read_stream, krrp_error_t *error);
static int krrp_ioctl_sess_create_fake_stream(krrp_stream_t **result_stream,
    boolean_t sender, nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_create_read_stream(krrp_stream_t **result_stream,
    nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_create_write_stream(krrp_stream_t **result_stream,
    nvlist_t *params, krrp_error_t *error);

static int krrp_ioctl_sess_conn_throttle(nvlist_t *params, krrp_error_t *error);
static int krrp_ioctl_sess_conn_get_info(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error);

static krrp_sess_t *krrp_ioctl_sess_action_common(nvlist_t *params,
    krrp_error_t *error);

static krrp_stream_read_flag_t krrp_fill_read_stream_flags(nvlist_t *params);
static krrp_stream_write_flag_t krrp_fill_write_stream_flags(nvlist_t *params);

int
krrp_ioctl_validate_cmd(krrp_ioctl_cmd_t cmd)
{
	if (cmd <= KRRP_IOCTL_FIRST || cmd >= KRRP_IOCTL_LAST)
		return (-1);

	return (0);
}

int krrp_ioctl_process(krrp_ioctl_cmd_t cmd, nvlist_t *input,
    nvlist_t *output, krrp_error_t *error)
{
	int rc = 0;

	if (input == NULL && krrp_is_input_data_required(cmd)) {
		krrp_error_set(error, KRRP_ERRNO_INVAL, ENODATA);
		rc = -1;
		goto out;
	}

	switch (cmd) {
	case KRRP_IOCTL_SVC_ENABLE:
		rc = krrp_svc_enable(error);
		break;
	case KRRP_IOCTL_SVC_DISABLE:
		rc = krrp_svc_disable(error);
		break;
	case KRRP_IOCTL_SVC_STATE:
		krrp_svc_state(output);
		break;
	case KRRP_IOCTL_SVC_SET_CONFIG:
		rc = krrp_svc_config(input, NULL, error);
		break;
	case KRRP_IOCTL_SVC_GET_CONFIG:
		rc = krrp_svc_config(input, output, error);
		break;
	case KRRP_IOCTL_SESS_SET_PRIVATE_DATA:
		rc = krrp_ioctl_sess_set_private_data(input, error);
		break;
	case KRRP_IOCTL_SESS_GET_PRIVATE_DATA:
		rc = krrp_ioctl_sess_get_private_data(input, output, error);
		break;
	case KRRP_IOCTL_SESS_LIST:
		krrp_svc_list_sessions(output);
		break;
	case KRRP_IOCTL_SESS_STATUS:
		rc = krrp_ioctl_sess_status(input, output, error);
		break;
	case KRRP_IOCTL_SESS_CREATE:
		rc = krrp_ioctl_sess_create(input, error);
		break;
	case KRRP_IOCTL_SESS_DESTROY:
		rc = krrp_ioctl_sess_destroy(input, error);
		break;
	case KRRP_IOCTL_SESS_RUN:
		rc = krrp_ioctl_sess_run(input, error);
		break;
	case KRRP_IOCTL_SESS_SEND_STOP:
		rc = krrp_ioctl_sess_send_stop(input, error);
		break;
	case KRRP_IOCTL_SESS_CREATE_CONN:
		rc = krrp_ioctl_sess_create_conn(input, error);
		break;
	case KRRP_IOCTL_SESS_CREATE_PDU_ENGINE:
		rc = krrp_ioctl_sess_create_pdu_engine(input, error);
		break;
	case KRRP_IOCTL_SESS_CREATE_READ_STREAM:
		rc = krrp_ioctl_sess_create_stream(input, B_TRUE, error);
		break;
	case KRRP_IOCTL_SESS_CREATE_WRITE_STREAM:
		rc = krrp_ioctl_sess_create_stream(input, B_FALSE, error);
		break;
	case KRRP_IOCTL_SESS_CONN_THROTTLE:
		rc = krrp_ioctl_sess_conn_throttle(input, error);
		break;
	case KRRP_IOCTL_SESS_GET_CONN_INFO:
		rc = krrp_ioctl_sess_conn_get_info(input, output, error);
		break;
	default:
		cmn_err(CE_WARN, "Unknown ioctl cmd [%d]", cmd);
		krrp_error_set(error, KRRP_ERRNO_INVAL, ENOTSUP);
		rc = -1;
#ifdef DEBUG
		panic("Unknown ioctl cmd");
#endif
	}

out:
	return (rc);
}

static boolean_t
krrp_is_input_data_required(krrp_ioctl_cmd_t cmd)
{
	boolean_t result;

	/*
	 * If an ioctl requires input data do not forget
	 * to add it to this switch
	 */
	switch (cmd) {
	case KRRP_IOCTL_SVC_SET_CONFIG:
	case KRRP_IOCTL_SVC_GET_CONFIG:
	case KRRP_IOCTL_SESS_SET_PRIVATE_DATA:
	case KRRP_IOCTL_SESS_GET_PRIVATE_DATA:
	case KRRP_IOCTL_SESS_STATUS:
	case KRRP_IOCTL_SESS_CREATE:
	case KRRP_IOCTL_SESS_DESTROY:
	case KRRP_IOCTL_SESS_RUN:
	case KRRP_IOCTL_SESS_SEND_STOP:
	case KRRP_IOCTL_SESS_CREATE_CONN:
	case KRRP_IOCTL_SESS_CREATE_PDU_ENGINE:
	case KRRP_IOCTL_SESS_CREATE_READ_STREAM:
	case KRRP_IOCTL_SESS_CREATE_WRITE_STREAM:
		result = B_TRUE;
		break;
	default:
		result = B_FALSE;
	}

	return (result);
}

static int
krrp_ioctl_sess_set_private_data(nvlist_t *params,
    krrp_error_t *error)
{
	krrp_sess_t *sess = NULL;
	int rc;
	nvlist_t *private_data = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	rc = krrp_param_get(KRRP_PARAM_SESS_PRIVATE_DATA,
	    params, &private_data);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SESS, ENODATA);
		goto out;
	}

	if (sess->private_data != NULL)
		fnvlist_free(sess->private_data);

	sess->private_data = fnvlist_dup(private_data);

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_get_private_data(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error)
{
	krrp_sess_t *sess = NULL;
	int rc = -1;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	if (sess->private_data == NULL) {
		krrp_error_set(error, KRRP_ERRNO_SESS, ENODATA);
		goto out;
	}

	(void) krrp_param_put(KRRP_PARAM_SESS_PRIVATE_DATA,
	    result, sess->private_data);
	rc = 0;

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_status(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error)
{
	krrp_sess_t *sess = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	krrp_sess_get_status(sess, result);

	krrp_sess_rele(sess);
	return (0);
}

static int
krrp_ioctl_sess_create(nvlist_t *params, krrp_error_t *error)
{
	int rc;
	const char *sess_id = NULL, *sess_kstat_id = NULL,
	    *auth_digest = NULL;
	krrp_sess_t *sess = NULL;
	boolean_t sender = B_FALSE;
	boolean_t fake_mode = B_FALSE;
	boolean_t compound = B_FALSE;

	rc = krrp_param_get(KRRP_PARAM_SESS_ID, params,
	    (void *) &sess_id);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SESSID, ENOENT);
		return (-1);
	}

	rc = krrp_param_get(KRRP_PARAM_SESS_KSTAT_ID, params,
	    (void *) &sess_kstat_id);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_KSTATID, ENOENT);
		return (-1);
	}

	(void) krrp_param_get(KRRP_PARAM_AUTH_DATA,
	    params, (void *)&auth_digest);
	(void) krrp_param_get(KRRP_PARAM_FAKE_MODE,
	    params, (void *)&fake_mode);
	(void) krrp_param_get(KRRP_PARAM_SESS_SENDER,
	    params, (void *)&sender);
	(void) krrp_param_get(KRRP_PARAM_SESS_COMPOUND,
	    params, (void *)&compound);

	if (krrp_sess_create(&sess, sess_id, sess_kstat_id,
	    auth_digest, sender, fake_mode, compound, error) != 0)
		return (-1);

	if (krrp_svc_register_session(sess, error) != 0) {
		krrp_sess_destroy(sess);
		return (-1);
	}

	return (0);
}

static int
krrp_ioctl_sess_destroy(nvlist_t *params, krrp_error_t *error)
{
	krrp_sess_t *sess = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	if (krrp_svc_unregister_session(sess, error) != 0)
		return (-1);

	krrp_sess_destroy(sess);

	return (0);
}

static int
krrp_ioctl_sess_create_conn(nvlist_t *params, krrp_error_t *error)
{
	int rc, remote_port = 0, timeout = 10;
	const char *remote_addr = NULL;
	krrp_sess_t *sess = NULL;
	krrp_conn_t *conn = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	rc = krrp_param_get(KRRP_PARAM_CONN_TIMEOUT,
	    params, (void *) &timeout);
	if (rc == 0 && (timeout < KRRP_MIN_CONN_TIMEOUT ||
	    timeout > KRRP_MAX_CONN_TIMEOUT)) {
		rc = -1;
		krrp_error_set(error, KRRP_ERRNO_CONNTIMEOUT, EINVAL);
		goto out;
	}

	rc = krrp_param_get(KRRP_PARAM_REMOTE_HOST,
	    params, (void *) &remote_addr);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_ADDR, ENOENT);
		goto out;
	}

	/* Remote address will be valiated by inet_pton() */

	rc = krrp_param_get(KRRP_PARAM_PORT,
	    params, (void *) &remote_port);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_PORT, ENOENT);
		goto out;
	}

	if (remote_port < KRRP_MIN_PORT || remote_port > KRRP_MAX_PORT) {
		rc = -1;
		krrp_error_set(error, KRRP_ERRNO_PORT, EINVAL);
		goto out;
	}

	rc = krrp_conn_create_from_scratch(&conn,
	    remote_addr, remote_port, timeout, error);
	if (rc != 0)
		goto out;

	rc = krrp_sess_initiator_attach_conn(sess, conn, error);
	if (rc != 0)
		krrp_conn_destroy(conn);

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_create_pdu_engine(nvlist_t *params, krrp_error_t *error)
{
	int rc = -1;
	krrp_sess_t *sess = NULL;
	krrp_pdu_engine_t *pdu_engine = NULL;
	boolean_t use_prealloc = B_FALSE;
	size_t dblk_data_sz = 0, dblk_head_sz = 0, max_memory = 0;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	/*
	 * dblk at sender side (since the sender uses ksocket_sendmblk)
	 * must have some space before data space, because the space is used
	 * by TCP/IP stack. The size of the space is equal to mblk_wroff,
	 * that is extracted from sonode_t.
	 * So to create pdu_engine in this case we need to be sure that
	 * a connection already established.
	 */
	if (sess->type == KRRP_SESS_SENDER) {
		if (sess->conn == NULL) {
			krrp_error_set(error, KRRP_ERRNO_CONN, ENOENT);
			goto out;
		}

		dblk_head_sz = sess->conn->mblk_wroff;
	}

	rc = krrp_param_get(KRRP_PARAM_DBLK_DATA_SIZE, params,
	    (void *) &dblk_data_sz);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_DBLKSZ, ENOENT);
		goto out;
	}

	/*
	 * kmem-allocator works very slowly for mem-blocks >128 KB,
	 * so the upper limit is 128 KB
	 *
	 * the lower limit is just an optimal value
	 */
	if (dblk_data_sz < KRRP_MIN_SESS_PDU_DBLK_DATA_SZ ||
	    dblk_data_sz > KRRP_MAX_SESS_PDU_DBLK_DATA_SZ) {
		rc = -1;
		krrp_error_set(error, KRRP_ERRNO_DBLKSZ, EINVAL);
		goto out;
	}

	rc = krrp_param_get(KRRP_PARAM_MAX_MEMORY, params,
	    (void *) &max_memory);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_MAXMEMSZ, ENOENT);
		goto out;
	}

	if (max_memory < KRRP_MIN_MAXMEM) {
		rc = -1;
		krrp_error_set(error, KRRP_ERRNO_MAXMEMSZ, EINVAL);
		goto out;
	}

	(void) krrp_param_get(KRRP_PARAM_USE_PREALLOCATION, params,
	    (void *) &use_prealloc);

	rc = krrp_pdu_engine_create(&pdu_engine, B_FALSE,
	    use_prealloc, max_memory, 0, dblk_head_sz,
	    dblk_data_sz, error);
	if (rc != 0)
		goto out;

	rc = krrp_sess_attach_pdu_engine(sess, pdu_engine, error);
	if (rc != 0)
		krrp_pdu_engine_destroy(pdu_engine);

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_create_stream(nvlist_t *params, boolean_t read_stream,
    krrp_error_t *error)
{
	int rc = -1;
	krrp_sess_t *sess = NULL;
	krrp_stream_t *stream = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	switch (sess->type) {
	case KRRP_SESS_SENDER:
		if (!read_stream) {
			krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
			goto out;
		}

		if (sess->fake_mode)
			rc = krrp_ioctl_sess_create_fake_stream(&stream,
			    B_TRUE, params, error);
		else
			rc = krrp_ioctl_sess_create_read_stream(&stream,
			    params, error);

		break;
	case KRRP_SESS_RECEIVER:
		if (read_stream) {
			krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
			goto out;
		}

		if (sess->fake_mode)
			rc = krrp_ioctl_sess_create_fake_stream(&stream,
			    B_FALSE, params, error);
		else
			rc = krrp_ioctl_sess_create_write_stream(&stream,
			    params, error);

		break;
	case KRRP_SESS_COMPOUND:
		if (sess->fake_mode && read_stream) {
			krrp_error_set(error, KRRP_ERRNO_SESS, EINVAL);
			goto out;
		}

		if (read_stream)
			rc = krrp_ioctl_sess_create_read_stream(&stream,
			    params, error);
		else if (sess->fake_mode)
			rc = krrp_ioctl_sess_create_fake_stream(&stream,
			    B_FALSE, params, error);
		else
			rc = krrp_ioctl_sess_create_write_stream(&stream,
			    params, error);

		break;
	}

	if (rc != 0)
		goto out;

	if (read_stream)
		rc = krrp_sess_attach_read_stream(sess, stream, error);
	else
		rc = krrp_sess_attach_write_stream(sess, stream, error);

	if (rc != 0)
		krrp_stream_destroy(stream);

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_create_fake_stream(krrp_stream_t **result_stream,
    boolean_t sender, nvlist_t *params, krrp_error_t *error)
{
	if (sender) {
		int rc;
		uint64_t fake_data_ds = 0;

		rc = krrp_param_get(KRRP_PARAM_FAKE_DATA_SIZE,
		    params, (void *) &fake_data_ds);
		if (rc != 0) {
			krrp_error_set(error, KRRP_ERRNO_FAKEDSZ, ENOENT);
			return (-1);
		}

		return (krrp_stream_fake_read_create(result_stream,
		    fake_data_ds, error));
	} else
		return (krrp_stream_fake_write_create(result_stream, error));

}

static int
krrp_ioctl_sess_create_read_stream(krrp_stream_t **result_stream,
    nvlist_t *params, krrp_error_t *error)
{
	int rc;
	const char *dataset = NULL, *base_snap_name = NULL,
	    *common_snap_name = NULL, *resume_token = NULL,
	    *skip_snaps_mask = NULL;
	uint32_t keep_snaps;
	krrp_stream_read_flag_t flags;

	rc = krrp_param_get(KRRP_PARAM_SRC_DATASET,
	    params, (void *) &dataset);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SRCDS, ENOENT);
		return (-1);
	}

	(void) krrp_param_get(KRRP_PARAM_RESUME_TOKEN,
	    params, (void *) &resume_token);

	(void) krrp_param_get(KRRP_PARAM_COMMON_SNAPSHOT,
	    params, (void *) &common_snap_name);
	(void) krrp_param_get(KRRP_PARAM_SRC_SNAPSHOT,
	    params, (void *) &base_snap_name);

	(void) krrp_param_get(KRRP_PARAM_SKIP_SNAPS_MASK,
	    params, (void *) &skip_snaps_mask);

	rc = krrp_param_get(KRRP_PARAM_STREAM_KEEP_SNAPS,
	    params, (void *) &keep_snaps);
	if (rc != 0) {
		/* KRRP_PARAM_STREAM_KEEP_SNAPS not defined, so use the MIN */
		keep_snaps = KRRP_MIN_KEEP_SNAPS;
	} else if (keep_snaps < KRRP_MIN_KEEP_SNAPS ||
	    keep_snaps > KRRP_MAX_KEEP_SNAPS) {
		krrp_error_set(error, KRRP_ERRNO_KEEPSNAPS, EINVAL);
		return (-1);
	}

	flags = krrp_fill_read_stream_flags(params);

	return (krrp_stream_read_create(result_stream, keep_snaps, dataset,
	    base_snap_name, common_snap_name, resume_token, flags,
	    skip_snaps_mask, error));
}

static int
krrp_ioctl_sess_create_write_stream(krrp_stream_t **result_stream,
    nvlist_t *params, krrp_error_t *error)
{
	int rc;
	const char *dataset = NULL, *common_snap_name = NULL,
	    *resume_token = NULL;
	nvlist_t *ignore_props_list = NULL, *replace_props_list = NULL;
	uint32_t keep_snaps;
	krrp_stream_write_flag_t flags;

	rc = krrp_param_get(KRRP_PARAM_DST_DATASET,
	    params, (void *) &dataset);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_DSTDS, ENOENT);
		return (-1);
	}

	(void) krrp_param_get(KRRP_PARAM_RESUME_TOKEN,
	    params, (void *) &resume_token);

	(void) krrp_param_get(KRRP_PARAM_IGNORE_PROPS_LIST,
	    params, (void *) &ignore_props_list);
	(void) krrp_param_get(KRRP_PARAM_REPLACE_PROPS_LIST,
	    params, (void *) &replace_props_list);

	(void) krrp_param_get(KRRP_PARAM_COMMON_SNAPSHOT,
	    params, (void *) &common_snap_name);

	rc = krrp_param_get(KRRP_PARAM_STREAM_KEEP_SNAPS,
	    params, (void *) &keep_snaps);
	if (rc != 0) {
		/* KRRP_PARAM_STREAM_KEEP_SNAPS not defined, so use the MIN */
		keep_snaps = KRRP_MIN_KEEP_SNAPS;
	} else if (keep_snaps < KRRP_MIN_KEEP_SNAPS ||
	    keep_snaps > KRRP_MAX_KEEP_SNAPS) {
		krrp_error_set(error, KRRP_ERRNO_KEEPSNAPS, EINVAL);
		return (-1);
	}

	flags = krrp_fill_write_stream_flags(params);

	return (krrp_stream_write_create(result_stream, keep_snaps,
	    dataset, common_snap_name, resume_token, flags,
	    ignore_props_list, replace_props_list, error));
}

static int
krrp_ioctl_sess_run(nvlist_t *params, krrp_error_t *error)
{
	krrp_sess_t *sess = NULL;
	boolean_t only_once = B_FALSE;
	int rc;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	(void) krrp_param_get(KRRP_PARAM_ONLY_ONCE, params,
	    (void *) &only_once);

	rc = krrp_sess_run(sess, only_once, error);

	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_send_stop(nvlist_t *params, krrp_error_t *error)
{
	int rc;
	krrp_sess_t *sess = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	rc = krrp_sess_send_stop(sess, error);

	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_conn_throttle(nvlist_t *params, krrp_error_t *error)
{
	int rc;
	krrp_sess_t *sess = NULL;
	size_t limit = 0;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	rc = krrp_param_get(KRRP_PARAM_THROTTLE,
	    params, (void *) &limit);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_THROTTLE, ENOENT);
		goto out;
	}

	if (limit < KRRP_MIN_CONN_THROTTLE && limit != 0) {
		krrp_error_set(error, KRRP_ERRNO_THROTTLE, EINVAL);
		rc = -1;
		goto out;
	}

	rc = krrp_sess_throttle_conn(sess, limit, error);

out:
	krrp_sess_rele(sess);
	return (rc);
}

static int
krrp_ioctl_sess_conn_get_info(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error)
{
	int rc;
	krrp_sess_t *sess = NULL;

	sess = krrp_ioctl_sess_action_common(params, error);
	if (sess == NULL)
		return (-1);

	rc = krrp_sess_get_conn_info(sess, result, error);

	krrp_sess_rele(sess);
	return (rc);
}

static krrp_sess_t *
krrp_ioctl_sess_action_common(nvlist_t *params, krrp_error_t *error)
{
	int rc;
	krrp_sess_t *sess = NULL;
	const char *sess_id = NULL;

	rc = krrp_param_get(KRRP_PARAM_SESS_ID, params,
	    (void *) &sess_id);
	if (rc != 0) {
		krrp_error_set(error, KRRP_ERRNO_SESSID, ENOENT);
		goto out;
	}

	sess = krrp_svc_lookup_session(sess_id);
	if (sess == NULL) {
		krrp_error_set(error, KRRP_ERRNO_SESS, ENOENT);
		goto out;
	}

	if (krrp_sess_try_hold(sess) != 0) {
		krrp_error_set(error, KRRP_ERRNO_SESS, EBUSY);
		sess = NULL;
	}

out:
	return (sess);
}

static krrp_stream_read_flag_t
krrp_fill_read_stream_flags(nvlist_t *params)
{
	boolean_t value = B_FALSE;
	krrp_stream_read_flag_t flags = 0;

	if (krrp_param_get(KRRP_PARAM_SEND_RECURSIVE,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_RECURSIVE);

	if (krrp_param_get(KRRP_PARAM_SEND_PROPERTIES,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_SEND_PROPS);

	if (krrp_param_get(KRRP_PARAM_INCLUDE_ALL_SNAPSHOTS,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_SEND_ALL_SNAPS);

	if (krrp_param_get(KRRP_PARAM_ENABLE_STREAM_CHKSUM,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_ENABLE_CHKSUM);

	if (krrp_param_get(KRRP_PARAM_STREAM_EMBEDDED_BLOCKS,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_EMBEDDED);

	if (krrp_param_get(KRRP_PARAM_STREAM_COMPRESSED_BLOCKS,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_COMPRESSED);

	if (krrp_param_get(KRRP_PARAM_STREAM_LARGE_BLOCKS,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_read_flag(&flags, KRRP_STRMRF_LARGE_BLOCKS);

	return (flags);
}

static krrp_stream_write_flag_t
krrp_fill_write_stream_flags(nvlist_t *params)
{
	boolean_t value = B_FALSE;
	krrp_stream_write_flag_t flags = 0;

	if (krrp_param_get(KRRP_PARAM_FORCE_RECEIVE,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_write_flag(&flags, KRRP_STRMWF_FORCE_RECV);

	if (krrp_param_get(KRRP_PARAM_ENABLE_STREAM_CHKSUM,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_write_flag(&flags, KRRP_STRMWF_ENABLE_CHKSUM);

	if (krrp_param_get(KRRP_PARAM_STREAM_DISCARD_HEAD,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_write_flag(&flags, KRRP_STRMWF_DISCARD_HEAD);

	if (krrp_param_get(KRRP_PARAM_STREAM_LEAVE_TAIL,
	    params, (void *) &value) == 0 && value)
		krrp_stream_set_write_flag(&flags, KRRP_STRMWF_LEAVE_TAIL);

	return (flags);
}
