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
 * Copyright 2015 Nexenta Systems, Inc. All rights reserved.
 */

#include <umem.h>
#include <libintl.h>
#include <unistd.h>
#include <string.h>
#include <sys/debug.h>
#include <stdarg.h>

#include <sys/sysevent/krrp.h>
#include <sys/krrp.h>
#include "libkrrp.h"
#include "libkrrp_impl.h"
#include "libkrrp_error.h"

/* Make lint happy */
#pragma error_messages(off, E_UNDEFINED_SYMBOL, E_YACC_ERROR, \
    E_FUNC_VAR_UNUSED, E_BLOCK_DECL_UNUSED, E_RET_INT_IMPLICITLY)

static struct {
	char *subclass;
	libkrrp_ev_type_t ev_type;
} krrp_escs[] = {
#define	LIBKRRP_ESC_EV_TYPE_EXPAND(enum_name) \
	{ESC_KRRP_##enum_name, LIBKRRP_EV_TYPE_##enum_name},
	LIBKRRP_EV_TYPE_MAP(LIBKRRP_ESC_EV_TYPE_EXPAND)
#undef	LIBKRRP_ESC_EV_TYPE_EXPAND
};

#define	LIBKRRP_EV_CB_RETRY_COUNT 5
#define	LIBKRRP_EV_CB_RETRY_PAUSE 300000

static size_t krrp_escs_sz = sizeof (krrp_escs) / sizeof (krrp_escs[0]);

static libkrrp_ev_type_t
subclass_to_libkrrp_ev_type(const char *subclass)
{
	int i;

	ASSERT(subclass != NULL);

	for (i = 0; i < krrp_escs_sz; i++) {
		if (strcmp(subclass, krrp_escs[i].subclass) == 0)
			return (krrp_escs[i].ev_type);
	}

	return (LIBKRRP_EV_TYPE_UNKNOWN);
}

static int
libkrrp_sess_id_parse(libkrrp_event_t *ev, char *sess_id_str,
    uuid_t sess_id)
{
	ASSERT(sess_id != NULL);

	if ((sess_id_str == NULL) ||
	    (uuid_parse(sess_id_str, sess_id) != 0)) {
		libkrrp_error_set(&ev->libkrrp_error, LIBKRRP_ERRNO_SESSID,
		    EINVAL, 0);

		return (-1);
	}

	return (0);
}

static void
libkrrp_ev_unpack_sess_send_done(libkrrp_event_t *ev, nvlist_t *attr)
{
	char *sess_id_str = NULL;

	ASSERT(ev != NULL);
	ASSERT(attr != NULL);

	if (krrp_param_get(KRRP_PARAM_SESS_ID, attr, &sess_id_str) != 0) {
		libkrrp_error_set(&ev->libkrrp_error, LIBKRRP_ERRNO_SESSID,
		    ENOENT, 0);
		return;
	}

	(void) libkrrp_sess_id_parse(ev, sess_id_str,
	    ev->ev_data.sess_send_done.sess_id);
}

static void
libkrrp_ev_unpack_sess_error(libkrrp_event_t *ev, nvlist_t *attr)
{
	char *sess_id_str = NULL;

	ASSERT(ev != NULL);
	ASSERT(attr != NULL);

	if (krrp_param_get(KRRP_PARAM_SESS_ID, attr, &sess_id_str) != 0) {
		libkrrp_error_set(&ev->libkrrp_error, LIBKRRP_ERRNO_SESSID,
		    ENOENT, 0);
		return;
	}

	if (libkrrp_sess_id_parse(ev, sess_id_str,
	    ev->ev_data.sess_error.sess_id) != 0)
		return;

	if (libkrrp_error_from_nvl(attr,
	    &ev->ev_data.sess_error.libkrrp_error) != 0) {
		libkrrp_error_set(&ev->libkrrp_error, LIBKRRP_ERRNO_SESSERR,
		    EINVAL, 0);
	}
}

static void
libkrrp_ev_unpack_server_error(libkrrp_event_t *ev, nvlist_t *attr)
{
	ASSERT(ev != NULL);
	ASSERT(attr != NULL);

	if (libkrrp_error_from_nvl(attr, &ev->ev_data.server_error) != 0) {
		libkrrp_error_set(&ev->libkrrp_error, LIBKRRP_ERRNO_SESSERR,
		    EINVAL, 0);
	}
}

static int
libkrrp_evc_callback(sysevent_t *ev, void *cookie)
{
	libkrrp_evc_handle_t *hdl = cookie;
	libkrrp_event_t libkrrp_ev;
	nvlist_t *attr = NULL;
	int rc;

	ASSERT(ev != NULL);
	ASSERT(hdl != NULL);

	libkrrp_error_init(&libkrrp_ev.libkrrp_error);
	libkrrp_ev.ev_type = subclass_to_libkrrp_ev_type(
	    sysevent_get_subclass_name(ev));

	rc = sysevent_get_attr_list(ev, &attr);
	if (rc == ENOMEM) {
		if (hdl->ev_failure_count++ < LIBKRRP_EV_CB_RETRY_COUNT) {
			(void) usleep(LIBKRRP_EV_CB_RETRY_PAUSE);
			return (EAGAIN);
		}
	}

	hdl->ev_failure_count = 0;

	if (rc != 0) {
		libkrrp_error_set(&libkrrp_ev.libkrrp_error,
		    LIBKRRP_ERRNO_EVREADFAIL, rc, 0);
		goto callback;
	}

	switch (libkrrp_ev.ev_type) {
	case LIBKRRP_EV_TYPE_SESS_SEND_DONE:
		libkrrp_ev_unpack_sess_send_done(&libkrrp_ev, attr);
		break;
	case LIBKRRP_EV_TYPE_SESS_ERROR:
		libkrrp_ev_unpack_sess_error(&libkrrp_ev, attr);
		break;
	case LIBKRRP_EV_TYPE_SERVER_ERROR:
		libkrrp_ev_unpack_server_error(&libkrrp_ev, attr);
		break;
	default:
		ASSERT(0);
	}

callback:
	fnvlist_free(attr);
	rc = hdl->callback(&libkrrp_ev, hdl->cookie);
	return (rc);
}

void
libkrrp_evc_unsubscribe(libkrrp_evc_handle_t *hdl)
{
	VERIFY(hdl != NULL);

	if (hdl->evchan)
		(void) sysevent_evc_unbind(hdl->evchan);

	umem_free(hdl, sizeof (libkrrp_evc_handle_t));
}

int
libkrrp_evc_subscribe(libkrrp_evc_handle_t **res_hdl,
    int(*callback)(libkrrp_event_t *, void *), void *cookie)
{
	int rc;
	char sid[13];
	libkrrp_evc_handle_t *hdl;

	hdl = umem_zalloc(sizeof (libkrrp_evc_handle_t), UMEM_DEFAULT);
	*res_hdl = hdl;

	if (hdl == NULL)
		return (-1);

	rc = sysevent_evc_bind(KRRP_EVENT_CHANNEL, &hdl->evchan, EVCH_CREAT);

	if (rc != 0) {
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_EVBINDFAIL, rc, 0);
		libkrrp_evc_unsubscribe(hdl);
		return (-1);
	}

	hdl->callback = callback;
	hdl->cookie = cookie;

	(void) sprintf(sid, "libkrrp%d", (int)getpid());
	rc = sysevent_evc_subscribe(hdl->evchan, sid, EC_KRRP,
	    libkrrp_evc_callback, hdl, 0);

	if (rc != 0) {
		libkrrp_error_set(&hdl->libkrrp_error,
		    LIBKRRP_ERRNO_EVSUBSRIBEFAIL, rc, 0);
		libkrrp_evc_unsubscribe(hdl);
		return (-1);
	}

	return (0);
}

libkrrp_error_t *
libkrrp_evc_error(libkrrp_evc_handle_t *hdl)
{
	VERIFY(hdl != NULL);
	return (&hdl->libkrrp_error);
}

const char *
libkrrp_evc_error_description(libkrrp_evc_handle_t *hdl)
{
	/* LINTED: E_FUNC_SET_NOT_USED */
	libkrrp_errno_t libkrrp_errno;
	/* LINTED: E_FUNC_SET_NOT_USED */
	int unix_errno;
	/* LINTED: E_FUNC_SET_NOT_USED */
	int flags = 0;
	char *descr;

	VERIFY(hdl != NULL);

	descr = hdl->libkrrp_error_descr;
	descr[0] = '\0';
	libkrrp_errno = hdl->libkrrp_error.libkrrp_errno;
	unix_errno = hdl->libkrrp_error.unix_errno;

	SET_ERROR_DESCR(LIBKRRP_ERRDESCR_MAP);

	if (descr[0] == '\0') {
		(void) snprintf(descr, sizeof (libkrrp_error_descr_t) - 1,
		    dgettext(TEXT_DOMAIN, LIBKRRP_EMSG_UNKNOWN));
	}

	return (descr);
}

libkrrp_ev_type_t
libkrrp_ev_type(libkrrp_event_t *ev)
{
	VERIFY(ev != NULL);
	return (ev->ev_type);
}

libkrrp_ev_data_t *
libkrrp_ev_data(libkrrp_event_t *ev)
{
	VERIFY(ev != NULL);
	return (&ev->ev_data);
}

libkrrp_error_t *
libkrrp_ev_error(libkrrp_event_t *ev)
{
	VERIFY(ev != NULL);
	return (&ev->libkrrp_error);
}

const char *
libkrrp_ev_error_description(libkrrp_event_t *ev)
{
	/* LINTED: E_FUNC_SET_NOT_USED */
	libkrrp_errno_t libkrrp_errno;
	/* LINTED: E_FUNC_SET_NOT_USED */
	int unix_errno;
	/* LINTED: E_FUNC_SET_NOT_USED */
	int flags = 0;
	char *descr;

	VERIFY(ev != NULL);

	descr = ev->libkrrp_error_descr;
	descr[0] = '\0';
	libkrrp_errno = ev->libkrrp_error.libkrrp_errno;
	unix_errno = ev->libkrrp_error.unix_errno;

	SET_ERROR_DESCR(LIBKRRP_ERRDESCR_MAP);

	if (descr[0] == '\0') {
		(void) snprintf(descr, sizeof (libkrrp_error_descr_t) - 1,
		    dgettext(TEXT_DOMAIN, LIBKRRP_EMSG_UNKNOWN));
	}

	return (descr);
}

void
libkrrp_ev_data_error_description(libkrrp_ev_type_t ev_type,
    libkrrp_error_t *error, libkrrp_error_descr_t descr)
{
	switch (ev_type) {
	case LIBKRRP_EV_TYPE_SERVER_ERROR:
		libkrrp_common_error_description(LIBKRRP_SRV_ERROR, error,
		    descr);
		break;
	case LIBKRRP_EV_TYPE_SESS_ERROR:
		libkrrp_common_error_description(LIBKRRP_SESS_ERROR, error,
		    descr);
		break;
	default:
		break;
	}
}

libkrrp_event_t *
libkrrp_ev_dup(libkrrp_event_t *ev)
{
	libkrrp_event_t *copy;

	VERIFY(ev != NULL);

	copy = umem_zalloc(sizeof (libkrrp_event_t), UMEM_DEFAULT);

	if (copy == NULL)
		return (NULL);

	(void) memcpy(copy, ev, sizeof (libkrrp_event_t));
	return (copy);
}

void
libkrrp_ev_free(libkrrp_event_t *ev)
{
	VERIFY(ev != NULL);
	umem_free(ev, sizeof (libkrrp_event_t));
}
