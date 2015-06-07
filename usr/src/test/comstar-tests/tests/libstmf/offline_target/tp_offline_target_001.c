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
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <libintl.h>
#include <unistd.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <inttypes.h>
#include <libstmf.h>

static int
stmfOfflineTarget001()
{
	int stmfRet;
	int ret = 0;
	int retries = 0;
	stmfDevidList *targetList;
	stmfTargetProperties targetProps;
	struct timespec rqtp;

	bzero(&rqtp, sizeof (rqtp));

	rqtp.tv_nsec = 10000000; /* 10 ms sleep */

	stmfRet = stmfGetTargetList(&targetList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup;
	}

	if (targetList->cnt > 0) {
		stmfRet = stmfOfflineTarget(&(targetList->devid[0]));
		if (stmfRet != STMF_STATUS_SUCCESS) {
			ret = 2;
			goto cleanup;
		}
	} else {
		ret = 3;
		goto cleanup;
	}

	targetProps.status = STMF_TARGET_PORT_ONLINE;
	while (targetProps.status != STMF_TARGET_PORT_OFFLINE &&
	    retries++ < 600) {
		stmfRet = stmfGetTargetProperties(&(targetList->devid[0]),
		    &targetProps);
		if (stmfRet != STMF_STATUS_SUCCESS) {
			ret = 4;
			goto cleanup1;
		}

		if (targetProps.status != STMF_TARGET_PORT_OFFLINE) {
			(void) nanosleep(&rqtp, NULL);
		}
	}
	if (targetProps.status != STMF_TARGET_PORT_OFFLINE) {
		ret = 5;
		goto cleanup1;
	}

cleanup1:
	(void) stmfOnlineTarget(&(targetList->devid[0]));
cleanup:
	return (ret);
}

int
main()
{
	return (stmfOfflineTarget001());
}
