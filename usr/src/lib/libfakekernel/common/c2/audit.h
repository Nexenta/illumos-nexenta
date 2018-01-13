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

/*
 * This file contains the declarations of the various data structures
 * used by the auditing module(s).
 */

#ifndef	_BSM_AUDIT_H
#define	_BSM_AUDIT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <sys/proc.h>

struct t_audit_sacl;
void audit_sacl(char *, cred_t *, uint32_t, boolean_t, struct t_audit_sacl *);

typedef uint_t au_asid_t;
typedef uid_t au_id_t;
struct au_mask {
	unsigned int	am_success;	/* success bits */
	unsigned int	am_failure;	/* failure bits */
};
typedef struct au_mask au_mask_t;

/*
 * The structure of the terminal ID (ipv6)
 */
struct au_tid_addr {
	dev_t  at_port;
	uint_t at_type;
	uint_t at_addr[4];
};

struct au_port_s {
	uint32_t at_major;	/* major # */
	uint32_t at_minor;	/* minor # */
};
typedef struct au_port_s au_port_t;

struct au_tid_addr64 {
	au_port_t	at_port;
	uint_t		at_type;
	uint_t		at_addr[4];
};
typedef struct au_tid_addr64 au_tid64_addr_t;
typedef struct au_tid_addr au_tid_addr_t;


#ifdef __cplusplus
}
#endif

#endif /* _BSM_AUDIT_H */
