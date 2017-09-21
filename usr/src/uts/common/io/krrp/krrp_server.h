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
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef	_KRRP_SERVER_H
#define	_KRRP_SERVER_H

#include <sys/ksocket.h>
#include <inet/ip.h>

#include <krrp_error.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef INET_ADDRSTRLEN
#define	INET_ADDRSTRLEN	16
#endif

typedef enum {
	KRRP_SRVS_RECONFIGURE = 1,
	KRRP_SRVS_ACTIVE,
	KRRP_SRVS_IN_ERROR,
} krrp_server_state_t;

typedef void (krrp_new_ks_cb_t)(ksocket_t);
typedef void (krrp_svr_error_cb_t)(krrp_error_t *);

typedef struct krrp_server_s {
	krrp_server_state_t	state;
	kt_did_t			t_did;
	boolean_t			running;
	boolean_t			without_event;
	kmutex_t			mtx;
	kcondvar_t			cv;
	ksocket_t			listening_ks;
	char				listening_addr[INET_ADDRSTRLEN];
	int					listening_port;
	krrp_new_ks_cb_t	*new_ks_cb;
	krrp_svr_error_cb_t	*on_error_cb;
	krrp_error_t		error;
} krrp_server_t;

void krrp_server_create(krrp_server_t **result_server,
    krrp_new_ks_cb_t *new_ks_cb, krrp_svr_error_cb_t *on_error_cb);
void krrp_server_destroy(krrp_server_t *server);
int krrp_server_set_config(krrp_server_t *server, nvlist_t *params,
    krrp_error_t *error);
int krrp_server_get_config(krrp_server_t *server, nvlist_t *result,
    krrp_error_t *error);
boolean_t krrp_server_is_running(krrp_server_t *server);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_SERVER_H */
