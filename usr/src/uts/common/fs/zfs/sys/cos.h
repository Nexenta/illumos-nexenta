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

#ifndef _SYS_COS_H
#define	_SYS_COS_H

#include <sys/avl.h>
#include <sys/zfs_context.h>
#include <sys/nvpair.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/fs/zfs.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * This is the interface to SPA Class Of Storage related functionality.
 * For more details, see comments in cos_impl.h
 */

/*
 * Macros for conversion between zio priorities and vdev properties.
 * These rely on the specific corresponding order of the zio_priority_t
 * and cos_prop_t enum definitions to simplify the conversion.
 */
#define	COS_PROP_TO_ZIO_PRIO_MIN(prp)	((prp) - COS_PROP_READ_MINACTIVE)
#define	COS_ZIO_PRIO_TO_PROP_MIN(pri)	((pri) + COS_PROP_READ_MINACTIVE)
#define	COS_PROP_MIN_VALID(prp)			\
	(((prp) >= COS_PROP_READ_MINACTIVE) &&	\
	((prp) <= COS_PROP_SCRUB_MINACTIVE))
#define	COS_PROP_TO_ZIO_PRIO_MAX(prp)	((prp) - COS_PROP_READ_MAXACTIVE)
#define	COS_ZIO_PRIO_TO_PROP_MAX(pri)	((pri) + COS_PROP_READ_MAXACTIVE)
#define	COS_PROP_MAX_VALID(prp)			\
	(((prp) >= COS_PROP_READ_MAXACTIVE) &&	\
	((prp) <= COS_PROP_SCRUB_MAXACTIVE))

/*
 * Forward declaration
 */
typedef struct cos cos_t;

void spa_cos_enter(spa_t *);
void spa_cos_exit(spa_t *);
void spa_cos_init(spa_t *);
void spa_cos_fini(spa_t *);

int spa_alloc_cos(spa_t *, const char *, uint64_t);
int spa_free_cos(spa_t *, const char *, boolean_t);
int spa_list_cos(spa_t *, nvlist_t *);
int spa_cos_prop_set(spa_t *, const char *, nvlist_t *);
int spa_cos_prop_get(spa_t *, const char *, nvlist_t **);

cos_t *spa_lookup_cos_by_guid(spa_t *, uint64_t);
cos_t *spa_lookup_cos_by_name(spa_t *, const char *);

int spa_load_cos_props(spa_t *);

void cos_hold(cos_t *cos);
void cos_rele(cos_t *cos);

uint64_t cos_get_prop_uint64(cos_t *cos, cos_prop_t p);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_COS_H */
