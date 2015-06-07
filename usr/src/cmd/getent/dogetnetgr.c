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

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <netdb.h>
#include "getent.h"

int
dogetnetgr(const char **list)
{
	char *host;
	char *user;
	char *dom;
	int rc = EXC_SUCCESS;

	if (list == NULL || *list == NULL)
		return (EXC_ENUM_NOT_SUPPORTED);

	for (; *list != NULL; list++) {
		printf("\n%s", *list);
		setnetgrent(*list);
		for (;;) {
			rc = getnetgrent(&host, &user, &dom);
			if (!rc)
				break;
			printf(" \\\n\t(%s,%s,%s)",
			    (host) ? host : "",
			    (user) ? user : "",
			    (dom)  ? dom  : "");
		}
		printf("\n");
	}

	return (rc);
}
