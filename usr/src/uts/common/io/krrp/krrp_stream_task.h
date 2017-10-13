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

#ifndef _KRRP_STREAM_TASK_H
#define	_KRRP_STREAM_TASK_H

#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/atomic.h>
#include <sys/stream.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <sys/kreplication_common.h>

#include <krrp_error.h>

#include "krrp_queue.h"
#include "krrp_pdu.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * A skip mask is a string that looks like
 *		prop_name=prop_value
 *
 * max len of prop_name is ZAP_MAXNAMELEN
 * max len of prop_value is ZAP_MAXVALUELEN
 * and 1 byte to store '='
 */
#define	KRRP_SKIP_SNAP_MASK_LEN ZAP_MAXNAMELEN + ZAP_MAXVALUELEN + 1

#define	KRRP_DBLK_TAIL_SIZE	sizeof (kreplication_buffer_t)

typedef enum {
	KRRP_STEM_READ = 1,
	KRRP_STEM_WRITE,
} krrp_stream_te_mode_t;

typedef enum {
	KRRP_STRMRF_RECURSIVE		= (1 << 0),
	KRRP_STRMRF_SEND_PROPS		= (1 << 1),
	KRRP_STRMRF_SEND_ALL_SNAPS	= (1 << 2),
	KRRP_STRMRF_EMBEDDED		= (1 << 3),
	KRRP_STRMRF_ENABLE_CHKSUM	= (1 << 4),
	KRRP_STRMRF_COMPRESSED		= (1 << 5),
	KRRP_STRMRF_LARGE_BLOCKS	= (1 << 6)
} krrp_stream_read_flag_t;

typedef enum {
	KRRP_STRMWF_FORCE_RECV		= (1 << 0),
	KRRP_STRMWF_DISCARD_HEAD	= (1 << 1),
	KRRP_STRMWF_LEAVE_TAIL		= (1 << 2),
	KRRP_STRMWF_ENABLE_CHKSUM	= (1 << 3)
} krrp_stream_write_flag_t;


typedef struct krrp_stream_te_s {
	krrp_queue_t			*tasks;
	krrp_queue_t			*tasks_done;
	krrp_queue_t			*tasks_done2;
	kmem_cache_t			*tasks_cache;
	krrp_stream_te_mode_t	mode;

	void					*global_zfs_ctx;

	const char				*dataset;

	char					skip_snaps_prop_name[ZAP_MAXNAMELEN];
	char					skip_snaps_prop_val[ZAP_MAXVALUELEN];

	boolean_t				fake_mode;
	boolean_t				discard_head;
	boolean_t				leave_tail;
	boolean_t				force_receive;
	boolean_t				recursive;
	boolean_t				incremental_package;
	boolean_t				properties;
	boolean_t				enable_cksum;
	boolean_t				embedded;
	boolean_t				compressed;
	boolean_t				large_blocks;
	nvlist_t				*ignore_props_list;
	nvlist_t				*replace_props_list;

	krrp_check_enough_mem	*mem_check_cb;
	void					*mem_check_cb_arg;
} krrp_stream_te_t;

typedef struct krrp_stream_task_s krrp_stream_task_t;

typedef void krrp_stream_task_shandler_t(krrp_stream_task_t *);
typedef int krrp_stream_task_handler_t(krrp_stream_task_t *, krrp_pdu_data_t *);

struct krrp_stream_task_s {
	list_node_t					node;

	kreplication_zfs_args_t		zargs;

	void						*zfs_ctx;
	uint64_t					txg;
	uint64_t					fake_data_sz;
	boolean_t					done;
	krrp_stream_task_shandler_t	*start;
	krrp_stream_task_shandler_t	*shutdown;
	krrp_stream_task_handler_t	*process;
	krrp_stream_te_t				*engine;

	/* These fields are used only at recv-side */
	uint64_t					txg_start;
	uint64_t					txg_end;

	/* These fields are used only at send-side */
	hrtime_t					init_hrtime;

	/* To implement sleep() for fake-tasks */
	kmutex_t					mtx;
	kcondvar_t					cv;
};

int krrp_stream_te_read_create(krrp_stream_te_t **result_te,
    const char *dataset, krrp_stream_read_flag_t flags,
    krrp_check_enough_mem *mem_check_cb, void *mem_check_cb_arg,
	const char *skip_snaps_mask, krrp_error_t *error);
int krrp_stream_te_write_create(krrp_stream_te_t **result_te,
    const char *dataset, krrp_stream_write_flag_t flags,
    nvlist_t *ignore_props_list, nvlist_t *replace_props_list,
    krrp_error_t *error);
int krrp_stream_te_fake_read_create(krrp_stream_te_t **result_te,
    krrp_error_t *error);
int krrp_stream_te_fake_write_create(krrp_stream_te_t **result_te,
    krrp_error_t *error);

void krrp_stream_te_destroy(krrp_stream_te_t *task_engine);

size_t krrp_stream_task_num_of_tasks(krrp_stream_te_t *);

void krrp_stream_task_engine_get_task(krrp_stream_te_t *,
    krrp_stream_task_t **);

void krrp_stream_fake_read_task_init(krrp_stream_te_t *, uint64_t);
void krrp_stream_read_task_init(krrp_stream_te_t *, uint64_t,
    const char *, const char *, nvlist_t *);
void krrp_stream_write_task_init(krrp_stream_te_t *, uint64_t,
    krrp_stream_task_t **, nvlist_t *);
void krrp_stream_task_fini(krrp_stream_task_t *);

hrtime_t krrp_stream_task_calc_rpo(krrp_stream_task_t *);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_STREAM_TASK_H */
