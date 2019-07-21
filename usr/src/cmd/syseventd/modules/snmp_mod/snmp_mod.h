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
 * Copyright 2019 Nexenta by DDN, Inc. All rights reserved.
 */

#ifndef _SNMP_MOD_H
#define	_SNMP_MOD_H

#include <sys/avl.h>
#include <sys/fm/protocol.h>
#include <sys/sysevent/eventdefs.h>

#include <fm/libtopo.h>
#include <fm/topo_hc.h>
#include <fm/topo_list.h>

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>

#include <libsysevent.h>

#include <pthread.h>

#include "syseventd.h"

#ifdef __cplusplus
extern "C" {
#endif

#define	SNMP_SUPPCONF	"syseventd-trapgen"

/* nexenta-core-storage-ssm-mib OID */
#define	SSM_OID	1, 3, 6, 1, 4, 1, 40045, 1, 1, 2, 1

/* notification trap definitions */
#define	SSM_TRAPS_OID		SSM_OID, 1, 0
#define	SSM_DISK_TRAP_OID	SSM_TRAPS_OID, 1

/* notification object definitions */
#define	SSM_OBJECTS_OID		SSM_OID, 2
#define	SSM_DISK_OBJECT_OID	SSM_OBJECTS_OID, 1

/* disk trap payload */
#define	SSM_DISK_ACTION_OID	SSM_DISK_OBJECT_OID, 1
#define	SSM_DISK_DEVNAME_OID	SSM_DISK_OBJECT_OID, 2
#define	SSM_DISK_ENCID_OID	SSM_DISK_OBJECT_OID, 3
#define	SSM_DISK_SLOTID_OID	SSM_DISK_OBJECT_OID, 4
#define	SSM_DISK_ENCNAME_OID	SSM_DISK_OBJECT_OID, 5
#define	SSM_DISK_SLOTNAME_OID	SSM_DISK_OBJECT_OID, 6

/* Handlers */
extern void ssm_disk_init(void);
extern void ssm_disk_fini(void);
extern void ssm_disk_handler(sysevent_t *);

#ifdef __cplusplus
}
#endif

#endif /* _SNMP_MOD_H */
