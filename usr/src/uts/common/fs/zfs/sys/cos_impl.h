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
 * ZFS Class of Storage is:
 *
 * 1. descriptor that combines user and system defined properties to control
 * ZFS IO pipeline stages and, effectively, propagate user data and/or
 * associated metadata to/from stable storage differently - on a per CoS basis
 *
 * 2. mechanism to match user data with a specific class (or classes) of disks
 * within the heterogeneous storage volume when placing the data
 *
 * The following COS attributes are supported:
 *  - min/max active to control queue depths of the I/O classes
 *  - preferred_read - weight for biasing reads (e.g. if vdev is a side
 *    of a mirror)
 *  - unmap_freed - whether to unmap unused space (e.g. TRIM)
 */


#ifndef _SYS_COS_IMPL_H
#define	_SYS_COS_IMPL_H

#include <sys/cos.h>
#include <sys/zio.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * in core cos structure
 */
struct cos {
	spa_t		*cos_spa;
	/* properties follow */
	uint64_t	cos_guid;
	uint64_t	cos_min_active[ZIO_PRIORITY_NUM_QUEUEABLE];
	uint64_t	cos_max_active[ZIO_PRIORITY_NUM_QUEUEABLE];
	uint64_t	cos_preferred_read;
	/* user defined name */
	char		cos_name[MAXCOSNAMELEN];
	/* modified with atomic ops */
	uint64_t	cos_refcnt;
	list_node_t	cos_list_node;
};

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_COS_IMPL_H */
