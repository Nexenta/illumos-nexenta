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

#ifndef	_LIBKRRP_IMPL_H
#define	_LIBKRRP_IMPL_H

#include <libsysevent.h>
#include <sys/uuid.h>

#include "krrp_params.h"
#include "krrp_ioctl_common.h"
#include "libkrrp_error.h"

#ifdef	__cplusplus
extern "C" {
#endif

typedef char krrp_sess_id_str_t[UUID_PRINTABLE_STRING_LENGTH];

struct libkrrp_handle_s {
	libkrrp_error_t libkrrp_error;
	krrp_ioctl_cmd_t libkrrp_last_cmd;
	int libkrrp_fd;
	libkrrp_error_descr_t libkrrp_error_descr;
};

struct libkrrp_evc_handle_s {
	libkrrp_error_t libkrrp_error;
	int (*callback)(libkrrp_event_t *, void *);
	evchan_t *evchan;
	void *cookie;
	int ev_failure_count;
	libkrrp_error_descr_t libkrrp_error_descr;
};

struct libkrrp_event_s {
	libkrrp_error_t libkrrp_error;
	libkrrp_ev_type_t ev_type;
	libkrrp_ev_data_t ev_data;
	libkrrp_error_descr_t libkrrp_error_descr;
};

int krrp_ioctl_perform(libkrrp_handle_t *, krrp_ioctl_cmd_t, nvlist_t *,
    nvlist_t **);
void libkrrp_reset(libkrrp_handle_t *);

#ifdef	__cplusplus
}
#endif

#endif	/* _LIBKRRP_IMPL_H */
