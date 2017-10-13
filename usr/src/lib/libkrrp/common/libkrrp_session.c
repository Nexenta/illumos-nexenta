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
 * Copyright 2017 Nexenta Systems, Inc. All rights reserved.
 */

#include <libintl.h>
#include <sys/uuid.h>
#include <sys/debug.h>
#include <string.h>
#include <inttypes.h>

#include <libzfs.h>
#include <sys/krrp.h>
#include "libkrrp.h"
#include "libkrrp_impl.h"

static int
krrp_sess_create_common(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *sess_kstat_id, const char *auth_digest, boolean_t fake_mode,
    nvlist_t *params)
{
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);
	VERIFY(sess_kstat_id != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	(void) krrp_param_put(KRRP_PARAM_SESS_KSTAT_ID, params,
	    (void *)sess_kstat_id);

	if (auth_digest != NULL) {
		(void) krrp_param_put(KRRP_PARAM_AUTH_DATA, params,
		    (void *)auth_digest);
	}

	if (fake_mode)
		(void) krrp_param_put(KRRP_PARAM_FAKE_MODE, params, NULL);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CREATE, params, NULL);

	return (rc);
}

int
krrp_sess_create_sender(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *sess_kstat_id, const char *auth_digest, boolean_t fake_mode)
{
	nvlist_t *params = NULL;
	int rc;

	params = fnvlist_alloc();

	(void) krrp_param_put(KRRP_PARAM_SESS_SENDER, params, NULL);

	rc = krrp_sess_create_common(hdl, sess_id, sess_kstat_id, auth_digest,
	    fake_mode, params);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_create_receiver(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *sess_kstat_id, const char *auth_digest, boolean_t fake_mode)
{
	nvlist_t *params = NULL;
	int rc;

	params = fnvlist_alloc();

	rc = krrp_sess_create_common(hdl, sess_id, sess_kstat_id, auth_digest,
	    fake_mode, params);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_create_compound(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *sess_kstat_id, boolean_t fake_mode)
{
	nvlist_t *params = NULL;
	int rc;

	params = fnvlist_alloc();

	(void) krrp_param_put(KRRP_PARAM_SESS_COMPOUND, params, NULL);

	rc = krrp_sess_create_common(hdl, sess_id, sess_kstat_id, NULL,
	    fake_mode, params);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_destroy(libkrrp_handle_t *hdl, uuid_t sess_id)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_DESTROY, params, NULL);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_set_private_data(libkrrp_handle_t *hdl, uuid_t sess_id,
    nvlist_t *private_data)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);
	VERIFY(private_data != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);
	(void) krrp_param_put(KRRP_PARAM_SESS_PRIVATE_DATA,
	    params, private_data);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_SET_PRIVATE_DATA,
	    params, NULL);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_get_private_data(libkrrp_handle_t *hdl, uuid_t sess_id,
    nvlist_t **private_data)
{
	nvlist_t *params = NULL, *result = NULL, *tmp = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);
	VERIFY(private_data != NULL && *private_data == NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_GET_PRIVATE_DATA,
	    params, &result);

	if (rc != 0)
		goto fini;

	VERIFY0(krrp_param_get(KRRP_PARAM_SESS_PRIVATE_DATA,
	    result, &tmp));

	*private_data = fnvlist_dup(tmp);
	fnvlist_free(result);

fini:
	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_create_conn(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *address, const uint16_t port, const uint32_t conn_timeout)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);
	VERIFY(address != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);
	(void) krrp_param_put(KRRP_PARAM_REMOTE_HOST, params, (void *)address);
	(void) krrp_param_put(KRRP_PARAM_PORT, params, (void *)&port);

	if (conn_timeout != 0) {
		(void) krrp_param_put(KRRP_PARAM_CONN_TIMEOUT, params,
		    (void *)&conn_timeout);
	}

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CREATE_CONN, params, NULL);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_conn_throttle(libkrrp_handle_t *hdl, uuid_t sess_id,
    const uint32_t limit)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);
	(void) krrp_param_put(KRRP_PARAM_THROTTLE, params, (void *)&limit);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CONN_THROTTLE, params,
	    NULL);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_create_pdu_engine(libkrrp_handle_t *hdl, uuid_t sess_id,
    const int memory_limit, const int dblk_sz, boolean_t use_preallocation)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);
	(void) krrp_param_put(KRRP_PARAM_MAX_MEMORY, params,
	    (void *)&memory_limit);
	(void) krrp_param_put(KRRP_PARAM_DBLK_DATA_SIZE, params,
	    (void *)&dblk_sz);

	if (use_preallocation) {
		(void) krrp_param_put(KRRP_PARAM_USE_PREALLOCATION,
		    params, NULL);
	}

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CREATE_PDU_ENGINE, params,
	    NULL);

	fnvlist_free(params);
	return (rc);
}

static void
krrp_sess_create_stream_common(libkrrp_handle_t *hdl, nvlist_t *params,
    uuid_t sess_id, const char *common_snap,
    krrp_sess_stream_flags_t krrp_sess_stream_flags, const char *resume_token,
    uint32_t keep_snaps)
{
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	/* keep_snaps == UINT32_MAX means "not defined" */
	if (keep_snaps != UINT32_MAX) {
		(void) krrp_param_put(KRRP_PARAM_STREAM_KEEP_SNAPS,
		    params, &keep_snaps);
	}

	if (common_snap != NULL) {
		(void) krrp_param_put(KRRP_PARAM_COMMON_SNAPSHOT,
		    params, (void *)common_snap);
	}

	if (resume_token != NULL) {
		(void) krrp_param_put(KRRP_PARAM_RESUME_TOKEN,
		    params, (void *)resume_token);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_ZFS_EMBEDDED) {
		(void) krrp_param_put(KRRP_PARAM_STREAM_EMBEDDED_BLOCKS,
		    params, NULL);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_ZFS_COMPRESSED) {
		(void) krrp_param_put(KRRP_PARAM_STREAM_COMPRESSED_BLOCKS,
		    params, NULL);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_ZFS_LARGE_BLOCKS) {
		(void) krrp_param_put(KRRP_PARAM_STREAM_LARGE_BLOCKS,
		    params, NULL);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_ZFS_CHKSUM) {
		(void) krrp_param_put(KRRP_PARAM_ENABLE_STREAM_CHKSUM,
		    params, NULL);
	}
}

int
krrp_sess_create_write_stream(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *dataset, const char *common_snap,
    krrp_sess_stream_flags_t krrp_sess_stream_flags, nvlist_t *ignore_props,
    nvlist_t *replace_props, const char *resume_token, uint32_t keep_snaps)
{
	nvlist_t *replace_props_copy = NULL;
	nvlist_t *params = NULL;
	int rc;

	libkrrp_reset(hdl);

	if (replace_props != NULL) {
		libzfs_handle_t *libzfs_hdl;
		char errbuf[1024];

		libzfs_hdl = libzfs_init();
		if (libzfs_hdl == NULL) {
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_PROPS, ENOMEM, 0);
			return (-1);
		}

		replace_props_copy = zfs_valid_proplist(libzfs_hdl,
		    ZFS_TYPE_FILESYSTEM | ZFS_TYPE_VOLUME,
		    replace_props, B_FALSE, NULL, NULL, "");
		if (replace_props_copy == NULL) {
			libkrrp_error_set(&hdl->libkrrp_error,
			    LIBKRRP_ERRNO_PROPS, EINVAL, 0);
			(void) snprintf(errbuf, sizeof (errbuf),
			    dgettext(TEXT_DOMAIN, "Failed to validate "
			    "ZFS properties: %s"),
			    libzfs_error_description(libzfs_hdl));
			libkrrp_set_error_description(hdl, errbuf);
		}

		libzfs_fini(libzfs_hdl);

		if (replace_props_copy == NULL)
			return (-1);
	}

	params = fnvlist_alloc();

	krrp_sess_create_stream_common(hdl, params, sess_id, common_snap,
	    krrp_sess_stream_flags, resume_token, keep_snaps);

	(void) krrp_param_put(KRRP_PARAM_DST_DATASET, params,
	    (void *)dataset);

	if (krrp_sess_stream_flags & KRRP_STREAM_FORCE_RECEIVE)
		(void) krrp_param_put(KRRP_PARAM_FORCE_RECEIVE, params, NULL);

	if (ignore_props != NULL) {
		(void) krrp_param_put(KRRP_PARAM_IGNORE_PROPS_LIST, params,
		    ignore_props);
	}

	if (replace_props_copy != NULL) {
		(void) krrp_param_put(KRRP_PARAM_REPLACE_PROPS_LIST, params,
		    replace_props_copy);
		fnvlist_free(replace_props_copy);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_DISCARD_HEAD) {
		/*
		 * Kernel does not yet support this flag
		 */
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_NOTSUP, 0, 0);
		rc = -1;
		goto out;
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_LEAVE_TAIL) {
		(void) krrp_param_put(KRRP_PARAM_STREAM_LEAVE_TAIL,
		    params, NULL);
	}

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CREATE_WRITE_STREAM,
	    params, NULL);

out:
	fnvlist_free(params);

	return (rc);
}

int
krrp_sess_create_read_stream(libkrrp_handle_t *hdl, uuid_t sess_id,
    const char *dataset, const char *common_snap, const char *src_snap,
    uint64_t fake_data_sz, krrp_sess_stream_flags_t krrp_sess_stream_flags,
    const char *resume_token, uint32_t keep_snaps,
	const char *skip_snaps_mask)
{
	nvlist_t *params = NULL;
	int rc;

	params = fnvlist_alloc();

	krrp_sess_create_stream_common(hdl, params, sess_id, common_snap,
	    krrp_sess_stream_flags, resume_token, keep_snaps);

	(void) krrp_param_put(KRRP_PARAM_SRC_DATASET, params, (void *)dataset);

	if (fake_data_sz != 0) {
		(void) krrp_param_put(KRRP_PARAM_FAKE_DATA_SIZE, params,
		    &fake_data_sz);
	}

	if (src_snap != NULL) {
		(void) krrp_param_put(KRRP_PARAM_SRC_SNAPSHOT, params,
		    (void *)src_snap);
	}

	if (krrp_sess_stream_flags & KRRP_STREAM_SEND_RECURSIVE)
		(void) krrp_param_put(KRRP_PARAM_SEND_RECURSIVE, params, NULL);

	if (krrp_sess_stream_flags & KRRP_STREAM_SEND_PROPERTIES)
		(void) krrp_param_put(KRRP_PARAM_SEND_PROPERTIES, params, NULL);

	if (krrp_sess_stream_flags & KRRP_STREAM_INCLUDE_ALL_SNAPS) {
		(void) krrp_param_put(KRRP_PARAM_INCLUDE_ALL_SNAPSHOTS,
		    params, NULL);
	}

	if (skip_snaps_mask != NULL) {
		(void) krrp_param_put(KRRP_PARAM_SKIP_SNAPS_MASK,
		    params, (void *)skip_snaps_mask);
	}

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_CREATE_READ_STREAM,
	    params, NULL);

	fnvlist_free(params);

	return (rc);
}

int
krrp_sess_run(libkrrp_handle_t *hdl, uuid_t sess_id, boolean_t once)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();

	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	if (once)
		(void) krrp_param_put(KRRP_PARAM_ONLY_ONCE, params, NULL);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_RUN, params, NULL);

	fnvlist_free(params);
	return (rc);
}

int
krrp_sess_send_stop(libkrrp_handle_t *hdl, uuid_t sess_id)
{
	nvlist_t *params = NULL;
	int rc;
	krrp_sess_id_str_t sess_id_str;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_SEND_STOP, params, NULL);

	fnvlist_free(params);
	return (rc);
}

int krrp_sess_status(libkrrp_handle_t *hdl, uuid_t sess_id,
    libkrrp_sess_status_t *sess_status)
{
	nvlist_t *result = NULL;
	nvlist_t *params = NULL;
	char *res_sess_id_str;
	char *res_sess_kstat_id;

	krrp_sess_id_str_t sess_id_str;
	int rc = 0;

	VERIFY(hdl != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_STATUS, params, &result);

	if (rc != 0) {
		rc = -1;
		goto fini;
	}

	VERIFY0(krrp_param_get(KRRP_PARAM_SESS_ID, result,
	    &res_sess_id_str));

	if (uuid_parse(res_sess_id_str, sess_status->sess_id) != 0) {
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_SESSID, EINVAL, 0);
		rc = -1;
		goto fini;
	}

	VERIFY0(krrp_param_get(KRRP_PARAM_SESS_STARTED, result,
	    &sess_status->sess_started));

	VERIFY0(krrp_param_get(KRRP_PARAM_SESS_RUNNING, result,
	    &sess_status->sess_running));

	if (krrp_param_exists(KRRP_PARAM_SESS_SENDER, result))
		sess_status->sess_type = LIBKRRP_SESS_TYPE_SENDER;
	else if (krrp_param_exists(KRRP_PARAM_SESS_COMPOUND, result))
		sess_status->sess_type = LIBKRRP_SESS_TYPE_COMPOUND;
	else
		sess_status->sess_type = LIBKRRP_SESS_TYPE_RECEIVER;

	VERIFY0(krrp_param_get(KRRP_PARAM_SESS_KSTAT_ID, result,
	    &res_sess_kstat_id));

	(void) strlcpy(sess_status->sess_kstat_id, res_sess_kstat_id,
	    KRRP_KSTAT_ID_STRING_LENGTH);

	if (krrp_param_exists(KRRP_PARAM_ERROR_CODE, result)) {
		rc = libkrrp_error_from_nvl(result,
		    &sess_status->libkrrp_error);
		ASSERT0(rc);
	} else {
		sess_status->libkrrp_error.libkrrp_errno = 0;
	}

fini:
	fnvlist_free(params);

	if (result != NULL)
		fnvlist_free(result);

	return (rc);
}

int
krrp_sess_get_conn_info(libkrrp_handle_t *hdl, uuid_t sess_id,
    libkrrp_sess_conn_info_t *sess_conn_info)
{
	nvlist_t *result = NULL;
	nvlist_t *params = NULL;
	krrp_sess_id_str_t sess_id_str;
	int rc = 0;

	VERIFY(hdl != NULL);
	VERIFY(sess_conn_info != NULL);

	libkrrp_reset(hdl);

	uuid_unparse(sess_id, sess_id_str);
	params = fnvlist_alloc();
	(void) krrp_param_put(KRRP_PARAM_SESS_ID, params, sess_id_str);

	rc = krrp_ioctl_perform(hdl, KRRP_IOCTL_SESS_GET_CONN_INFO, params, &result);
	if (rc != 0)
		goto fini;

	VERIFY0(krrp_param_get(KRRP_PARAM_DBLK_DATA_SIZE, result,
	    &sess_conn_info->blk_sz));

fini:
	fnvlist_free(params);

	fnvlist_free(result);

	return (rc);
}
