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

#ifndef _KRRP_AUTOSNAP_H
#define	_KRRP_AUTOSNAP_H

#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/atomic.h>
#include <sys/stream.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <sys/autosnap.h>

#include <krrp_error.h>

#include "krrp_queue.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	krrp_autosnap_lock(a)			mutex_enter(&(a)->mtx)
#define	krrp_autosnap_unlock(a)			mutex_exit(&(a)->mtx)
#define	krrp_autosnap_cv_wait(a)		cv_wait(&(a)->cv, &(a)->mtx)
#define	krrp_autosnap_cv_signal(a)		cv_signal(&(a)->cv)
#define	krrp_autosnap_cv_broadcast(a)	cv_broadcast(&(a)->cv)

typedef void krrp_autosnap_restore_cb_t(void *, const char *, uint64_t);

typedef enum {
	KRRP_AUTOSNAP_STATE_UNREGISTERED = 0,
	KRRP_AUTOSNAP_STATE_REGISTERED,
	KRRP_AUTOSNAP_STATE_ACTIVE
} krrp_autosnap_state_t;

typedef struct krrp_autonap_s {
	kmutex_t				mtx;
	kcondvar_t				cv;
	krrp_autosnap_state_t	state;
	size_t					ref_cnt;
	void					*zfs_ctx;
	krrp_queue_t			*txg_to_rele;
	size_t					keep_snaps;
} krrp_autosnap_t;

int krrp_autosnap_rside_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset, boolean_t recursive,
    uint64_t incr_snap_txg, krrp_autosnap_restore_cb_t *restore_cb,
    autosnap_confirm_cb confirm_cb,
    autosnap_notify_created_cb notify_cb, autosnap_error_cb error_cb,
    void *cb_arg, krrp_error_t *error);
int krrp_autosnap_wside_create(krrp_autosnap_t **result_autosnap,
    size_t keep_snaps, const char *dataset, uint64_t incr_snap_txg,
    autosnap_notify_created_cb notify_cb, void *cb_arg, krrp_error_t *error);
void krrp_autosnap_destroy(krrp_autosnap_t *autosnap);

boolean_t krrp_autosnap_try_hold_to_confirm(krrp_autosnap_t *autosnap);
boolean_t krrp_autosnap_try_hold_to_snap_rele(krrp_autosnap_t *autosnap);
boolean_t krrp_autosnap_try_hold_to_snap_create(krrp_autosnap_t *autosnap);
void krrp_autosnap_unhold(krrp_autosnap_t *autosnap);

void krrp_autosnap_deactivate(krrp_autosnap_t *autosnap);

void krrp_autosnap_create_snapshot(krrp_autosnap_t *autosnap);

void krrp_autosnap_txg_rele(krrp_autosnap_t *, uint64_t, uint64_t);
void krrp_autosnap_txg_rele_one(krrp_autosnap_t *, uint64_t);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_AUTOSNAP_H */
