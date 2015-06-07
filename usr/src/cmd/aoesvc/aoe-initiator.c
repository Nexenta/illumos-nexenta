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
 * Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/aoe.h>
#include <sys/list.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <libaoe.h>
#include <libdllink.h>
#include <libintl.h>
#include <libscf.h>
#include <locale.h>
#include <locale.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <syslog.h>
#include <wchar.h>
#include <libipadm.h>

int
main(void)
{
	AOE_STATUS		status;
	PAOE_SMF_PORT_LIST	portlist = NULL;
	PAOE_SMF_PORT_INSTANCE	port = NULL;
	int			i;
	ipadm_handle_t		iph;
	ipadm_status_t		rc;

	(void) setlocale(LC_ALL, "");

	/*
	 * Loading configuration from the Service Management Facility.
	 * Note: Loading the configuration from SMF is done in libaoe.
	 *	Please see the aoe_load_config routine in libaoe.c
	 *	for the procedure of doing this.
	 */
	status = aoe_load_config(AOE_PORTTYPE_INITIATOR, &portlist);
	if (status != AOE_STATUS_OK) {
		syslog(LOG_ERR, "Failed loading AoE configuration "
		    "from SMF. status=%d", status);
		return (1);
	}

	if (portlist == NULL)
		return (0);

	if (ipadm_open(&iph, IPH_IPMGMTD) != IPADM_SUCCESS) {
		syslog(LOG_ERR, "Could not open ipadm handle.");
		return (1);
	}

	for (i = 0; i < portlist->port_num; i++) {
		char	buf[MAXLINKNAMELEN];
		char	*linkname = NULL;

		port = &portlist->ports[i];
		(void) strlcpy(buf, port->linknames, MAXLINKNAMELEN);
		linkname = strtok(buf, ",");
		while (linkname != NULL) {
			/* Unplumb the interfaces */
			rc = ipadm_delete_if(iph, linkname,
			    AF_INET, IPADM_OPT_ACTIVE);
			if (rc != IPADM_SUCCESS)
				syslog(LOG_ERR,
				    "Failed unplumbing %s, rc=%d",
				    linkname, rc);
			linkname = strtok(NULL, ",");
		}
		if (port->type == AOE_PORTTYPE_INITIATOR) {
			status = aoe_create_port(port->id, port->linknames,
			    port->promisc, AOE_PORTTYPE_INITIATOR,
			    port->policy, port->module);
			if (status != AOE_STATUS_OK) {
				syslog(LOG_ERR, "Failed creating AoE port. "
				    "port_id=%d, status=%d", port->id, status);
			}
		}
	}

	if (portlist != NULL)
		free(portlist);

	ipadm_close(iph);
	return (0);
}
