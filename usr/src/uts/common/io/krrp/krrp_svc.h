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

#ifndef	_KRRP_SVC_H
#define	_KRRP_SVC_H

#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/sunldi.h>
#include <sys/avl.h>
#include <sys/sysevent/krrp.h>

#include <krrp_error.h>

#include "krrp_pdu.h"
#include "krrp_session.h"
#include "krrp_server.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	krrp_svc_lock(a) mutex_enter(&(a)->mtx)
#define	krrp_svc_unlock(a) mutex_exit(&(a)->mtx)

typedef enum {
	KRRP_SVCS_UNKNOWN = 0,
	KRRP_SVCS_CREATED,
	KRRP_SVCS_DETACHED,
	KRRP_SVCS_DISABLED,
	KRRP_SVCS_ENABLING,
	KRRP_SVCS_ENABLED,
	KRRP_SVCS_DISABLING
} krrp_svc_state_t;

typedef struct krrp_svc_s {
	krrp_svc_state_t	state;
	ldi_ident_t			li;
	dev_info_t			*dip;
	kmutex_t			mtx;
	kcondvar_t			cv;
	size_t				ref_cnt;
	avl_tree_t			sessions;
	krrp_server_t		*server;
	krrp_pdu_engine_t	*ctrl_pdu_engine;
	taskq_t				*aux_taskq;
	evchan_t			*ev_chan;
} krrp_svc_t;

krrp_svc_t *krrp_svc_get_instance(void);

boolean_t krrp_svc_is_enabled(void);

void krrp_svc_init(void);
void krrp_svc_fini(void);

void krrp_svc_attach(dev_info_t *dip);
int krrp_svc_detach(void);

int krrp_svc_enable(krrp_error_t *);
int krrp_svc_disable(krrp_error_t *);
void krrp_svc_state(nvlist_t *);
int krrp_svc_config(nvlist_t *params, nvlist_t *result,
    krrp_error_t *error);

int krrp_svc_register_session(krrp_sess_t *sess, krrp_error_t *error);
int krrp_svc_unregister_session(krrp_sess_t *sess, krrp_error_t *error);

void krrp_svc_post_uevent(const char *, nvlist_t *attr_list);

krrp_sess_t *krrp_svc_lookup_session(const char *sess_id);
void krrp_svc_list_sessions(nvlist_t *out_nvl);

int krrp_svc_ref_cnt_try_hold();
void krrp_svc_ref_cnt_rele();

void krrp_svc_dispatch_task(task_func_t func, void *arg);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_SVC_H */
