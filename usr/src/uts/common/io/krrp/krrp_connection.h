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

#ifndef _KRRP_CONNECTION_H
#define	_KRRP_CONNECTION_H

#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/stream.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/proc.h>
#include <sys/class.h>
#include <inet/ip.h>
#include <sys/ksocket.h>
#include <sys/cmn_err.h>

#include <krrp_error.h>

#include "krrp_pdu.h"
#include "krrp_protocol.h"
#include "krrp_queue.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	KRRP_RX_TIMEOUT 60 /* In seconds */

typedef struct krrp_conn_s krrp_conn_t;

typedef enum {
	KRRP_CONN_DATA_PDU,
	KRRP_CONN_CTRL_PDU,
	KRRP_CONN_ERROR,
} krrp_conn_cb_ev_t;

typedef void (krrp_conn_cb_t)(void *void_conn,
    krrp_conn_cb_ev_t ev, uintptr_t ev_arg, void *cb_arg);

typedef void (krrp_get_data_pdu_cb_t)(void *cb_arg, krrp_pdu_t **result_pdu);

typedef enum {
	KRRP_CS_CONNECTED,
	KRRP_CS_READY_TO_RUN,
	KRRP_CS_ACTIVE,
	KRRP_CS_STOPPED,
	KRRP_CS_DISCONNECTING,
	KRRP_CS_DISCONNECTED
} krrp_conn_state_t;

typedef struct krrp_throttle_s {
	kmutex_t		mtx;
	kcondvar_t		cv;
	timeout_id_t	timer;
	size_t			remains;
	size_t			limit;
} krrp_throttle_t;

struct krrp_conn_s {
	krrp_conn_state_t		state;

	boolean_t				tx_running;
	boolean_t				rx_running;

	krrp_queue_t			*ctrl_tx_queue;

	krrp_get_data_pdu_cb_t	*get_data_pdu_cb;
	void					*get_data_pdu_cb_arg;

	krrp_conn_cb_t			*callback;
	void					*callback_arg;

	kmutex_t				mtx;
	kcondvar_t				cv;
	ksocket_t				ks;

	krrp_throttle_t			throttle;

	size_t					mblk_wroff;
	size_t					mblk_tail_len;
	size_t					blk_sz;

	uint64_t				bytes_tx;
	uint64_t				bytes_rx;

	uint64_t				cur_txg;

	krrp_pdu_engine_t		*data_pdu_engine;

	timeout_id_t			action_timeout;
};

int krrp_conn_create_from_scratch(krrp_conn_t **result_conn,
    const char *address, int port, int timeout, krrp_error_t *error);
int krrp_conn_create_from_ksocket(krrp_conn_t **result_conn,
    ksocket_t ks, krrp_error_t *error);
void krrp_conn_destroy(krrp_conn_t *conn);

void krrp_conn_register_callback(krrp_conn_t *conn,
    krrp_conn_cb_t *ev_cb, void *cb_arg);

void krrp_conn_throttle_set(krrp_conn_t *conn, size_t new_limit,
    boolean_t only_set);

void krrp_conn_run(krrp_conn_t *conn, krrp_queue_t *ctrl_tx_queue,
    krrp_pdu_engine_t *data_pdu_engine,
    krrp_get_data_pdu_cb_t *get_data_pdu_cb, void *cb_arg);
void krrp_conn_stop(krrp_conn_t *conn);

int krrp_conn_send_ctrl_data(krrp_conn_t *conn, krrp_opcode_t opcode,
    nvlist_t *nvl, krrp_error_t *error);
int krrp_conn_tx_ctrl_pdu(krrp_conn_t *conn, krrp_pdu_ctrl_t *pdu,
    krrp_error_t *error);
int krrp_conn_rx_ctrl_pdu(krrp_conn_t *conn, krrp_pdu_ctrl_t **result_pdu,
    krrp_error_t *error);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_CONNECTION_H */
