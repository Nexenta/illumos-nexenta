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

#ifndef _KRRP_PDU_H
#define	_KRRP_PDU_H

#include <sys/types.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/time.h>
#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include "krrp_dblk.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	KRRP_PDU_DEFAULT_SIZE			512 * 1024
#define	KRRP_DBLKS_PER_PDU_DEFAULT		100
#define	KRRP_MAX_MEMORY_FOR_PDU_DEFAULT	1024

#define	KRRP_PDU_WITH_HDR		B_TRUE
#define	KRRP_PDU_WITHOUT_HDR		B_FALSE

/* Flags for data-pdu: first byte */
#define	KRRP_HDR_FLAG_INIT_PDU	0x0001
#define	KRRP_HDR_FLAG_FINI_PDU	0x0002

/* Flags for ctrl-pdu: second byte  */
#define	KRRP_HDR_FLAG_SHUTDOWN_GRACEFULLY	0x0100

#define	krrp_pdu_opcode(a)	(a)->hdr->opcode
#define	krrp_pdu_type(a)		(a)->type

#define	krrp_pdu_hdr(a) (a)->hdr

typedef void (krrp_pdu_free_notify_cb_t)(void *, size_t);

typedef enum {
	KRRP_PET_DATA,
	KRRP_PET_CTRL
} krrp_pdu_engine_type_t;

typedef enum {
	KRRP_PT_DATA,
	KRRP_PT_CTRL,
} krrp_pdu_type_t;

typedef struct krrp_pdu_engine_s {
	krrp_pdu_engine_type_t	type;

	kmutex_t			mtx;
	kcondvar_t			cv;

	struct {
		krrp_pdu_free_notify_cb_t	*cb;
		void						*cb_arg;
		size_t						init_value;
		size_t						cnt;
	} notify_free;

	size_t				cur_pdu_cnt;
	size_t				max_pdu_cnt;

	krrp_dblk_engine_t	*dblk_engine;
	size_t				dblks_per_pdu;
	size_t				pdu_data_sz;
} krrp_pdu_engine_t;

typedef struct krrp_hdr_s {
	uint16_t	opcode;
	uint16_t	flags;
	uint32_t	payload_sz;
	uint8_t		reserved[36];
	uint32_t	hdr_chksum;
} krrp_hdr_t;

typedef struct krrp_hdr_data_s {
	uint16_t	opcode;
	uint16_t	flags;
	uint32_t	payload_sz;
	uint64_t	pdu_seq_num;
	uint64_t	txg;
	uint8_t		reserved[20];
	uint32_t	hdr_chksum;
} krrp_hdr_data_t;

typedef struct krrp_hdr_ctrl_s {
	uint16_t	opcode;
	uint16_t	flags;
	uint32_t	payload_sz;
	uint8_t		data[36];
	uint32_t	hdr_chksum;
} krrp_hdr_ctrl_t;

typedef struct krrp_pdu_s {
	list_node_t			node;

	krrp_pdu_type_t		type;

	krrp_hdr_t			*hdr;
	krrp_dblk_t			*dblk;

	size_t				max_data_sz;
	size_t				cur_data_sz;
} krrp_pdu_t;

typedef struct krrp_pdu_data_s {
	list_node_t			node;

	krrp_pdu_type_t		type;

	krrp_hdr_data_t		*hdr;
	krrp_dblk_t			*dblk;

	size_t				max_data_sz;
	size_t				cur_data_sz;

	uint64_t			txg;
	hrtime_t			tx_start_ts;
	boolean_t			initial;
	boolean_t			final;
} krrp_pdu_data_t;

typedef struct krrp_pdu_ctrl_s {
	list_node_t			node;

	krrp_pdu_type_t		type;

	krrp_hdr_ctrl_t		*hdr;
	krrp_dblk_t			*dblk;

	size_t				max_data_sz;
	size_t				cur_data_sz;
} krrp_pdu_ctrl_t;

int krrp_pdu_engine_global_init();
void krrp_pdu_engine_global_fini();

void krrp_pdu_ctrl_alloc(krrp_pdu_ctrl_t **result_pdu,
    boolean_t with_header);

int krrp_pdu_engine_create(krrp_pdu_engine_t **result_engine, boolean_t ctrl,
    boolean_t prealloc, size_t max_memory, size_t dblks_per_pdu,
    size_t dblk_head_sz, size_t dblk_data_sz, krrp_error_t *error);
void krrp_pdu_engine_destroy(krrp_pdu_engine_t *engine);

void krrp_pdu_engine_register_callback(krrp_pdu_engine_t *engine,
    krrp_pdu_free_notify_cb_t *notify_cb, void *notify_cb_arg);
void krrp_pdu_engine_force_notify(krrp_pdu_engine_t *engine,
    boolean_t initial);

size_t krrp_pdu_engine_get_used_mem(krrp_pdu_engine_t *pdu_engine);
size_t krrp_pdu_engine_get_free_mem(krrp_pdu_engine_t *pdu_engine);

void krrp_pdu_alloc(krrp_pdu_engine_t *, krrp_pdu_t **, boolean_t);
void krrp_pdu_rele(krrp_pdu_t *);

int krrp_pdu_get_payload(krrp_pdu_ctrl_t *pdu, void **res_data,
    size_t *res_data_sz);
int krrp_pdu_get_nvl_from_payload(krrp_pdu_ctrl_t *pdu, nvlist_t **res_nvl);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_PDU_H */
