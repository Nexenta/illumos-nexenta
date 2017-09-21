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
 * Copyright 2016 Nexenta Systems, Inc. All rights reserved.
 */
#ifndef	_DMU_KRRP_H
#define	_DMU_KRRP_H

#ifdef	__cplusplus
extern "C" {
#endif

int dmu_krrp_buffer_write(void *buf, int len,
    dmu_krrp_task_t *krrp_task);
int dmu_krrp_buffer_read(void *buf, int len,
    dmu_krrp_task_t *krrp_task);
int dmu_krrp_arc_bypass(void *buf, int len, void *arg);
int dmu_krrp_direct_arc_read(spa_t *spa, dmu_krrp_task_t *krrp_task,
    zio_cksum_t *zc, const blkptr_t *bp);

typedef int (*dmu_krrp_arc_bypass_cb)(void *, int, dmu_krrp_task_t *);
typedef struct {
	dmu_krrp_task_t *krrp_task;
	zio_cksum_t *zc;
	dmu_krrp_arc_bypass_cb cb;
} dmu_krrp_arc_bypass_t;

#ifdef	__cplusplus
}
#endif

#endif /* _DMU_KRRP_H */
