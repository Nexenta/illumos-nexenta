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
 * Copyright 2011 Nexenta, Inc.  All rights reserved.
 */

/* Some internal definitions */

#ifndef __NFS_DEFS_H__
#define	__NFS_DEFS_H__

#ifdef DEBUG
#define	TABSIZE		17
#define	MDS_TABSIZE	17
#else
#define	TABSIZE		2047
#define	MDS_TABSIZE	2047
#endif

#define	MAXTABSZ	1024*1024
#define	MDS_MAXTABSZ	1024*1024

#define	ADDRHASH(key) ((unsigned long)(key) >> 3)

#endif /* __NFS_DEFS_H__ */
