/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef _KRRP_QUEUE_H
#define	_KRRP_QUEUE_H

#include <sys/sysmacros.h>
#include <sys/kmem.h>
#include <sys/stream.h>
#include <sys/list.h>
#include <sys/modctl.h>
#include <sys/class.h>
#include <sys/cmn_err.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct krrp_queue_s {
	kmutex_t		mtx;
	kcondvar_t		cv;
	list_t			list;
	size_t			cnt;
	boolean_t		force_return;
} krrp_queue_t;

void krrp_queue_init(krrp_queue_t **, size_t, size_t);
void krrp_queue_fini(krrp_queue_t *);
size_t krrp_queue_length(krrp_queue_t *);
void krrp_queue_set_force_return(krrp_queue_t *);
void krrp_queue_put(krrp_queue_t *, void *);
void *krrp_queue_get(krrp_queue_t *);
void *krrp_queue_get_no_wait(krrp_queue_t *);

#ifdef __cplusplus
}
#endif

#endif /* _KRRP_QUEUE_H */
