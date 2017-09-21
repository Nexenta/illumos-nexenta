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

#ifndef _KRRP_DBLK_H
#define	_KRRP_DBLK_H

#include <sys/types.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/time.h>
#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#include <krrp_error.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct krrp_dblk_engine_s krrp_dblk_engine_t;
typedef struct krrp_dblk_s krrp_dblk_t;

typedef void (krrp_dblk_free_notify_cb_t)(void *);
typedef void (krrp_dblk_alloc_func_t)(krrp_dblk_engine_t *,
    krrp_dblk_t **, size_t);


typedef enum {
	KRRP_DET_KMEM_ALLOC,
	KRRP_DET_KMEM_CACHE,
} krrp_dblk_engine_type_t;

typedef struct krrp_dblk_list_s {
	krrp_dblk_t	*head;
	krrp_dblk_t	*tail;
	size_t		cnt;
} krrp_dblk_list_t;

struct krrp_dblk_engine_s {
	krrp_dblk_engine_type_t	type;

	kmutex_t				mtx;
	kcondvar_t				cv;

	boolean_t				destroying;
	krrp_dblk_alloc_func_t	*alloc_func;

	kmem_cache_t			*dblk_cache;

	krrp_dblk_list_t		free_dblks;

	size_t					cur_dblk_cnt;
	size_t					max_dblk_cnt;

	size_t					dblk_head_sz;
	size_t					dblk_data_sz;
	size_t					dblk_tail_sz;

	struct {
		krrp_dblk_free_notify_cb_t	*cb;
		void						*cb_arg;
		size_t						init_value;
		size_t						cnt;
	} notify_free;
};

struct krrp_dblk_s {
	/* These fields are common for krrp_dblk_t and kreplication_buffer_t */
	void			*data;
	size_t			max_data_sz;
	size_t			cur_data_sz;
	krrp_dblk_t		*next;

	/* Private dblk's fields */
	krrp_dblk_engine_t	*engine;
	size_t				total_sz;
	frtn_t				free_rtns;

	/* This field is used by TCP/IP stack as part of mblk_t */
	void				*head;
};

int krrp_dblk_engine_create(krrp_dblk_engine_t **result_engine,
    boolean_t prealloc, size_t max_dblk_cnt, size_t dblk_head_sz,
    size_t dblk_data_sz, size_t notify_free_value,
    krrp_dblk_free_notify_cb_t *notify_free_cb, void *notify_free_cb_arg,
    krrp_error_t *error);
void krrp_dblk_engine_destroy(krrp_dblk_engine_t *engine);

void krrp_dblk_alloc(krrp_dblk_engine_t *, krrp_dblk_t **, size_t);
void krrp_dblk_rele(krrp_dblk_t *);

int krrp_dblk_get_data(krrp_dblk_t *dblk, void *buf, size_t buf_sz);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_DBLK_H */
