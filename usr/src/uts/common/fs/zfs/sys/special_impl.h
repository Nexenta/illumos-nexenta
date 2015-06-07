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
 * Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * See special.c for details on the theory of operation
 */

#ifndef _SYS_SPECIAL_IMPL_H
#define	_SYS_SPECIAL_IMPL_H

#include <sys/special.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * Special Class descriptor
 */
struct spa_specialclass {
	spa_specialclass_id_t	sc_id;
	uint64_t		sc_flags;
	uint64_t		sc_mask;
};

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_SPECIAL_IMPL_H */
