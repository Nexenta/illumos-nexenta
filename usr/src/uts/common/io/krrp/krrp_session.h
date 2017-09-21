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

#ifndef	_KRRP_SESSION_H
#define	_KRRP_SESSION_H

#include <sys/kstat.h>
#include <sys/avl.h>
#include <sys/uuid.h>

#include <sys/krrp.h>
#include <krrp_error.h>

#include "krrp_stream.h"
#include "krrp_connection.h"
#include "krrp_pdu.h"
#include "krrp_queue.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef char krrp_sess_id_str_t[UUID_PRINTABLE_STRING_LENGTH];

typedef enum {
	KRRP_SESS_SENDER = 1,
	KRRP_SESS_RECEIVER,
	KRRP_SESS_COMPOUND,
} krrp_sess_type_t;

/*
 * To extend stats need to add to the following define new field and
 * write corresponding update-code in krrp_sess_sender_kstat_update()
 */
#define	KRRP_SESS_SENDER_STAT_NAME_MAP(X) \
	X(avg_rpo, KSTAT_DATA_UINT64, 0) \
	X(avg_network_rpo, KSTAT_DATA_UINT64, 0) \
	X(cur_send_stream_txg, KSTAT_DATA_UINT64, 0) \
	X(cur_send_network_txg, KSTAT_DATA_UINT64, 0) \
	X(last_stream_ack_txg, KSTAT_DATA_UINT64, 0) \
	X(last_network_ack_txg, KSTAT_DATA_UINT64, 0) \
	X(max_pdu_seq_num, KSTAT_DATA_UINT64, 0) \
	X(max_pdu_seq_num_adjusted, KSTAT_DATA_UINT64, 0) \
	X(cur_pdu_seq_num, KSTAT_DATA_UINT64, 0) \
	X(fl_ctrl_window_size, KSTAT_DATA_UINT64, 0) \
	X(bytes_tx, KSTAT_DATA_UINT64, 0) \
	X(bytes_rx, KSTAT_DATA_UINT64, 0) \
	X(rbytes, KSTAT_DATA_UINT64, 0) \
	X(mem_used, KSTAT_DATA_UINT64, 0) \
	X(uptime, KSTAT_DATA_UINT64, 0) \

/*
 * To extend stats need to add to the following define new field and
 * write corresponding update-code in krrp_sess_receiver_kstat_update()
 */
#define	KRRP_SESS_RECEIVER_STAT_NAME_MAP(X) \
	X(cur_recv_stream_txg, KSTAT_DATA_UINT64, 0) \
	X(cur_recv_network_txg, KSTAT_DATA_UINT64, 0) \
	X(max_pdu_seq_num, KSTAT_DATA_UINT64, 0) \
	X(cur_pdu_seq_num, KSTAT_DATA_UINT64, 0) \
	X(bytes_tx, KSTAT_DATA_UINT64, 0) \
	X(bytes_rx, KSTAT_DATA_UINT64, 0) \
	X(wbytes, KSTAT_DATA_UINT64, 0) \
	X(mem_used, KSTAT_DATA_UINT64, 0) \
	X(uptime, KSTAT_DATA_UINT64, 0) \

/*
 * To extend stats need to add to the following define new field and
 * write corresponding update-code in krrp_sess_compound_kstat_update()
 */
#define	KRRP_SESS_COMPOUND_STAT_NAME_MAP(X) \
	X(avg_rpo, KSTAT_DATA_UINT64, 0) \
	X(cur_send_stream_txg, KSTAT_DATA_UINT64, 0) \
	X(cur_recv_stream_txg, KSTAT_DATA_UINT64, 0) \
	X(rbytes, KSTAT_DATA_UINT64, 0) \
	X(wbytes, KSTAT_DATA_UINT64, 0) \
	X(mem_used, KSTAT_DATA_UINT64, 0) \
	X(uptime, KSTAT_DATA_UINT64, 0) \

#define	NUM_OF_FIELDS(S) (sizeof (S) / sizeof (kstat_named_t))

#define	KRRP_SESS_STAT_NAME_GEN(name, dtype, def_value) kstat_named_t name;
typedef struct krrp_sess_sender_kstat_s {
	KRRP_SESS_SENDER_STAT_NAME_MAP(KRRP_SESS_STAT_NAME_GEN)
} krrp_sess_sender_kstat_t;

typedef struct krrp_sess_receiver_kstat_s {
	KRRP_SESS_RECEIVER_STAT_NAME_MAP(KRRP_SESS_STAT_NAME_GEN)
} krrp_sess_receiver_kstat_t;

typedef struct krrp_sess_compound_kstat_s {
	KRRP_SESS_COMPOUND_STAT_NAME_MAP(KRRP_SESS_STAT_NAME_GEN)
} krrp_sess_compound_kstat_t;
#undef KRRP_SESS_STAT_NAME_GEN

typedef struct krrp_fl_ctrl_s {
	uint64_t	max_pdu_seq_num_orig;
	uint64_t	max_pdu_seq_num;
	uint64_t	ack_pdu_seq_num;
	uint64_t	cur_pdu_seq_num;
	uint64_t	cwnd;
	boolean_t	disabled;
	kmutex_t	mtx;
	kcondvar_t	cv;
} krrp_fl_ctrl_t;

typedef struct krrp_sess_s {
	avl_node_t				node;
	krrp_sess_id_str_t		id;
	krrp_sess_type_t		type;
	boolean_t				fake_mode;
	boolean_t				started;
	boolean_t				running;
	boolean_t				destroying;
	boolean_t				shutdown;
	boolean_t				on_hold;

	size_t					ref_cnt;

	kmutex_t				mtx;
	kcondvar_t				cv;

	krrp_pdu_engine_t		*data_pdu_engine;
	krrp_stream_t			*stream_read;
	krrp_stream_t			*stream_write;
	krrp_conn_t				*conn;

	krrp_queue_t			*ctrl_tx_queue;
	krrp_queue_t			*data_tx_queue;
	krrp_queue_t			*data_write_queue;
	krrp_fl_ctrl_t			fl_ctrl;

	struct {
		kstat_t				*ctx;
		union {
			krrp_sess_sender_kstat_t	sender;
			krrp_sess_receiver_kstat_t	receiver;
			krrp_sess_compound_kstat_t	compound;
		} data;
		char				id[KRRP_KSTAT_ID_STRING_LENGTH];
	} kstat;

	timeout_id_t			ping_timer;
	boolean_t				ping_wait_for_response;

	char auth_digest[KRRP_AUTH_DIGEST_MAX_LEN];

	krrp_error_t			error;
	nvlist_t				*private_data;
} krrp_sess_t;

int krrp_sess_create(krrp_sess_t **result_sess, const char *id,
    const char *kstat_id, const char *auth_digest,
    boolean_t sender, boolean_t fake_mode,
    boolean_t compound, krrp_error_t *error);
void krrp_sess_destroy(krrp_sess_t *sess);

int krrp_sess_attach_pdu_engine(krrp_sess_t *sess,
    krrp_pdu_engine_t *pdu_engine, krrp_error_t *error);

int krrp_sess_attach_read_stream(krrp_sess_t *sess,
    krrp_stream_t *stream, krrp_error_t *error);
int krrp_sess_attach_write_stream(krrp_sess_t *sess,
    krrp_stream_t *stream, krrp_error_t *error);

int krrp_sess_initiator_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    krrp_error_t *error);
int krrp_sess_target_attach_conn(krrp_sess_t *sess, krrp_conn_t *conn,
    nvlist_t *params, krrp_error_t *error);

void krrp_sess_get_status(krrp_sess_t *sess, nvlist_t *result);

int krrp_sess_run(krrp_sess_t *sess, boolean_t only_once,
    krrp_error_t *error);
int krrp_sess_send_stop(krrp_sess_t *sess, krrp_error_t *error);

int krrp_sess_throttle_conn(krrp_sess_t *sess, size_t limit,
    krrp_error_t *error);

int krrp_sess_get_conn_info(krrp_sess_t *sess, nvlist_t *result,
    krrp_error_t *error);

int krrp_sess_set_id(krrp_sess_t *sess, const char *sess_id_str,
    krrp_error_t *error);
int krrp_sess_compare_id(const void *opaque_sess1, const void *opaque_sess2);

boolean_t krrp_sess_is_started(krrp_sess_t *sess);
boolean_t krrp_sess_is_running(krrp_sess_t *sess);

int krrp_sess_try_hold(krrp_sess_t *sess);
void krrp_sess_rele(krrp_sess_t *sess);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_SESSION_H */
