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
 * Copyright 2012 Nexenta Systems, Inc. All rights reserved.
 */

#ifndef	_LIBAOE_H
#define	_LIBAOE_H

#include <sys/aoe.h>
#include <sys/ioctl.h>
#include <sys/list.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <libdllink.h>
#include <libintl.h>
#include <libscf.h>
#include <locale.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <syslog.h>
#include <unistd.h>
#include <wchar.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * AoE Port Type
 */
#define	AOE_PORTTYPE_INITIATOR		0
#define	AOE_PORTTYPE_TARGET		1

typedef int AOE_STATUS;

#define	AOE_STATUS_OK				0
#define	AOE_STATUS_ERROR			1
#define	AOE_STATUS_ERROR_INVAL_ARG		2
#define	AOE_STATUS_ERROR_BUSY			3
#define	AOE_STATUS_ERROR_ALREADY		4
#define	AOE_STATUS_ERROR_PERM			5
#define	AOE_STATUS_ERROR_OPEN_DEV		6
#define	AOE_STATUS_ERROR_MAC_LEN		8
#define	AOE_STATUS_ERROR_CREATE_MAC		12
#define	AOE_STATUS_ERROR_OPEN_MAC		13
#define	AOE_STATUS_ERROR_CREATE_PORT		14
#define	AOE_STATUS_ERROR_MAC_NOT_FOUND		15
#define	AOE_STATUS_ERROR_OFFLINE_DEV		16
#define	AOE_STATUS_ERROR_MORE_DATA		17
#define	AOE_STATUS_ERROR_GET_LINKINFO		19
#define	AOE_STATUS_ERROR_EXISTS			20
#define	AOE_STATUS_ERROR_SERVICE_NOT_FOUND	21
#define	AOE_STATUS_ERROR_NOMEM			22
#define	AOE_STATUS_ERROR_MEMBER_NOT_FOUND	23


/*
 * Define commonly used constants
 */
#define	AOE_MAX_MAC_NAMES_LEN	256
#define	AOE_MAX_PORTID_LEN	8
#define	AOE_PORT_LIST_LEN	255

#define	AOE_SCF_ADD		0
#define	AOE_SCF_REMOVE		1

#define	AOE_INITIATOR_SERVICE	"network/aoe/initiator"
#define	AOE_TARGET_SERVICE	"network/aoe/target"
#define	AOE_PG_NAME		"aoe-port-list-pg"
#define	AOE_PORT_LIST_PROP	"port_list_p"

#define	DBUS_HAL_DESTINATION	"org.freedesktop.Hal"
#define	DBUS_HAL_PATH		"/org/freedesktop/Hal/Manager"
#define	DBUS_HAL_INTERFACE	"org.freedesktop.Hal.Manager"
#define	DBUS_HAL_COM_DEV_LIST	"GetAllDevices"
#define	DBUS_HAL_COM_DEV_REM	"Remove"

/*
 * AoE port instance in smf repository
 */
typedef struct aoe_smf_port_instance {
	int		id;
	char		linknames[MAXLINKNAMELEN];
	int		promisc;
	aoe_cli_type_t	type;
	aoe_cli_policy_t policy;
	char		module[AOE_ACP_MODLEN];
} AOE_SMF_PORT_INSTANCE, *PAOE_SMF_PORT_INSTANCE;

/*
 * AoE port instance list
 */
typedef struct aoe_smf_port_list {
	uint32_t		port_num;
	AOE_SMF_PORT_INSTANCE	ports[1];
} AOE_SMF_PORT_LIST, *PAOE_SMF_PORT_LIST;

AOE_STATUS	aoe_create_port(int portid, char *ifnames, int promisc,
		    aoe_cli_type_t type, aoe_cli_policy_t policy, char *module);
AOE_STATUS	aoe_delete_port(int portid);
AOE_STATUS	aoe_get_port_list(uint32_t *port_num, aoe_port_list_t **ports);
AOE_STATUS	aoe_load_config(uint32_t port_type,
		    AOE_SMF_PORT_LIST **portlist);
const char	*aoe_strerror(AOE_STATUS error);

#ifdef	__cplusplus
}
#endif

#endif	/* _LIBAOE_H */
