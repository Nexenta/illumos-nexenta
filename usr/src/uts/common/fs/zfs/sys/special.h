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

#ifndef _SYS_SPECIAL_H
#define	_SYS_SPECIAL_H

#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/fs/zfs.h>
#include <sys/spa.h>
#include <sys/zio.h>

#ifdef	__cplusplus
extern "C" {
#endif

typedef struct spa_specialclass spa_specialclass_t;

/* types of special class */
typedef enum spa_specialclass_id {
	SPA_SPECIALCLASS_ZIL,
	SPA_SPECIALCLASS_META,
	SPA_SPECIALCLASS_WRCACHE,
	SPA_NUM_SPECIALCLASSES
} spa_specialclass_id_t;

#define	META_PLACEMENT_OFF	0
#define	META_PLACEMENT_ON	1
#define	META_PLACEMENT_DUAL	2

void spa_set_specialclass(spa_t *, objset_t *, spa_specialclass_id_t);
spa_specialclass_id_t spa_specialclass_id(objset_t *);
spa_specialclass_t *spa_get_specialclass(objset_t *);
uint64_t spa_specialclass_flags(objset_t *);
void spa_check_special(spa_t *);
boolean_t spa_write_data_to_special(spa_t *, objset_t *);

/* currently there are 2 flags */
enum specialflagbit {
	/* 2 bits - data type */
	SPECIAL_FLAGBIT_DATAUSER,
	SPECIAL_FLAGBIT_DATAMETA,

	SPECIAL_NUM_FLAGBITS
};

#define	SPECIAL_FLAG_DATAUSER	(1ULL << SPECIAL_FLAGBIT_DATAUSER)
#define	SPECIAL_FLAG_DATAMETA	(1ULL << SPECIAL_FLAGBIT_DATAMETA)

#define	SPECIAL_FLAGSMASK	((1ULL << SPECIAL_NUM_FLAGBITS) - 1)

/* only meta data on special */
#define	SPECIAL_META_FLAGS	(SPECIAL_FLAG_DATAMETA)
#define	SPECIAL_META_MASK	(0)

/* both meta and user data on special */
#define	SPECIAL_WRCACHE_FLAGS	(SPECIAL_FLAG_DATAUSER | SPECIAL_FLAG_DATAMETA)
#define	SPECIAL_WRCACHE_MASK	(SPECIAL_FLAG_DATAUSER | SPECIAL_FLAG_DATAMETA)

metaslab_class_t *spa_select_class(spa_t *spa, zio_prop_t *io_prop);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_SPECIAL_H */
