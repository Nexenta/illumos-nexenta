/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright (c) 1992, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright 2018 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef _BSM_AUDIT_KERNEL_H
#define	_BSM_AUDIT_KERNEL_H

#include <c2/audit.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

extern struct t_audit_data global_audit_data;
#define	T2A(t)	(&global_audit_data)

typedef struct t_audit_sacl {
	uint32_t tas_smask;
	uint32_t tas_fmask;
} t_audit_sacl_t;

typedef enum sacl_audit_ctrl {
	SACL_AUDIT_NONE = 0,
	SACL_AUDIT_ON,
	SACL_AUDIT_ALL,
	SACL_AUDIT_NO_SRC
} sacl_audit_ctrl_t;

struct t_audit_data {
	sacl_audit_ctrl_t tad_sacl_ctrl;
	t_audit_sacl_t tad_sacl_mask;
	t_audit_sacl_t tad_sacl_mask_src;
	t_audit_sacl_t tad_sacl_mask_dest;
};
typedef struct t_audit_data t_audit_data_t;

#ifdef __cplusplus
}
#endif

#endif /* _BSM_AUDIT_KERNEL_H */
