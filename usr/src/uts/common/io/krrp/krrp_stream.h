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

#ifndef _KRRP_STREAM_H
#define	_KRRP_STREAM_H

#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/atomic.h>
#include <sys/stream.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <krrp_error.h>
#include "krrp_queue.h"
#include "krrp_pdu.h"

#include "krrp_autosnap.h"
#include "krrp_stream_task.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	krrp_stream_lock(a) mutex_enter(&(a)->mtx)
#define	krrp_stream_unlock(a) mutex_exit(&(a)->mtx)
#define	krrp_stream_cv_wait(a) cv_wait(&(a)->cv, &(a)->mtx)
#define	krrp_stream_cv_signal(a) cv_signal(&(a)->cv)
#define	krrp_stream_cv_broadcast(a) cv_broadcast(&(a)->cv)

typedef enum {
	KRRP_STRMS_CREATED = 1,
	KRRP_STRMS_READY_TO_RUN,
	KRRP_STRMS_ACTIVE,
	KRRP_STRMS_IN_ERROR,
	KRRP_STRMS_STOPPED
} krrp_stream_state_t;

typedef enum {
	KRRP_STRMM_READ = 1,
	KRRP_STRMM_WRITE,
} krrp_stream_mode_t;

typedef struct krrp_stream_s krrp_stream_t;

typedef enum {
	KRRP_STREAM_DATA_PDU = 1,
	KRRP_STREAM_TXG_RECV_DONE,
	KRRP_STREAM_SEND_DONE,
	KRRP_STREAM_ERROR,
} krrp_stream_cb_ev_t;

typedef void (krrp_stream_cb_t)(krrp_stream_cb_ev_t ev,
    uintptr_t ev_arg, void *cb_arg);

typedef struct krrp_txg_rpo_t {
	uint64_t				value;
	uint64_t				buf[10];
	size_t					cnt;
} krrp_txg_rpo_t;

struct krrp_stream_s {
	kthread_t				*work_thread;

	krrp_stream_cb_t		*callback;
	void					*callback_arg;

	krrp_pdu_engine_t		*data_pdu_engine;

	krrp_stream_state_t		state;
	boolean_t				do_ctrl_snap;
	kmutex_t				mtx;
	kcondvar_t				cv;

	boolean_t				wait_for_snap;

	boolean_t				non_continuous;
	boolean_t				fake_mode;
	boolean_t				recursive;
	char					dataset[MAXNAMELEN];
	char					base_snap_name[MAXNAMELEN];
	char					incr_snap_name[MAXNAMELEN];
	nvlist_t				*resume_info;
	uint64_t				notify_txg;
	uint64_t				last_send_txg;
	uint64_t				cur_send_txg;
	uint64_t				cur_recv_txg;
	uint64_t				last_ack_txg;
	uint64_t				last_full_ack_txg;

	uint64_t				bytes_processed;

	size_t					keep_snaps;

	krrp_txg_rpo_t			avg_total_rpo;
	krrp_txg_rpo_t			avg_rpo;

	uint64_t				fake_data_sz;
	krrp_queue_t			*write_data_queue;
	krrp_stream_mode_t		mode;
	krrp_stream_te_t		*task_engine;
	krrp_autosnap_t			*autosnap;

	krrp_pdu_data_t			*cur_pdu;
	krrp_stream_task_t		*cur_task;
	krrp_queue_t			*debug_pdu_queue;
	krrp_queue_t			*debug_tasks_queue;
};

int krrp_stream_read_create(krrp_stream_t **result_stream,
    size_t keep_snaps, const char *dataset, const char *base_snap_name,
    const char *incr_snap_name, const char *resume_token,
	krrp_stream_read_flag_t flags, const char *skip_snaps_mask,
    krrp_error_t *error);
int krrp_stream_write_create(krrp_stream_t **result_stream,
    size_t keep_snaps, const char *dataset, const char *incr_snap_name,
    const char *resume_token, krrp_stream_write_flag_t flags,
    nvlist_t *ignore_props_list, nvlist_t *replace_props_list,
    krrp_error_t *error);
int krrp_stream_fake_read_create(krrp_stream_t **result_stream,
    uint64_t fake_data_sz, krrp_error_t *error);
int krrp_stream_fake_write_create(krrp_stream_t **result_stream,
    krrp_error_t *error);
void krrp_stream_destroy(krrp_stream_t *stream);

void krrp_stream_register_callback(krrp_stream_t *stream,
    krrp_stream_cb_t *ev_cb, void *ev_cb_arg);

int krrp_stream_run(krrp_stream_t *stream, krrp_queue_t *write_data_queue,
    krrp_pdu_engine_t *data_pdu_engine, krrp_error_t *error);

void krrp_stream_txg_confirmed(krrp_stream_t *, uint64_t, boolean_t);

void krrp_stream_stop(krrp_stream_t *stream);
int krrp_stream_send_stop(krrp_stream_t *stream);

boolean_t krrp_stream_is_write_flag_set(krrp_stream_write_flag_t flags,
    krrp_stream_write_flag_t flag);
void krrp_stream_set_write_flag(krrp_stream_write_flag_t *flags,
    krrp_stream_write_flag_t flag);
boolean_t krrp_stream_is_read_flag_set(krrp_stream_read_flag_t flags,
    krrp_stream_read_flag_t flag);
void krrp_stream_set_read_flag(krrp_stream_read_flag_t *flags,
    krrp_stream_read_flag_t flag);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_STREAM_H */
