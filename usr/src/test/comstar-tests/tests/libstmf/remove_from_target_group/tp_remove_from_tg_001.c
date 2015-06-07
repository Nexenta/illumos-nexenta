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
stmfRemoveFromTargetGroup001()
{
	int ret = 0;
	int stmfRet;
	uchar_t wwn[8];
	char *groupName = "TG";
	stmfDevid devid;
	stmfGroupProperties *groupProps;

	(void) system("svcadm disable -s stmf");
	bzero(&devid, sizeof (devid));
	stmfRet = stmfCreateTargetGroup((stmfGroupName *)groupName);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup;
	}

	wwn[0] = 0x01;
	wwn[1] = 0x23;
	wwn[2] = 0x45;
	wwn[3] = 0x67;
	wwn[4] = 0x89;
	wwn[5] = 0xab;
	wwn[6] = 0xcd;
	wwn[7] = 0xef;

	stmfRet = stmfDevidFromWwn(wwn, &devid);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 2;
		goto cleanup;
	}

	stmfRet = stmfAddToTargetGroup((stmfGroupName *)groupName, &devid);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 3;
		goto cleanup;
	}

	stmfRet = stmfGetTargetGroupMembers((stmfGroupName *)groupName,
	    &groupProps);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 4;
		goto cleanup;
	}

	if (bcmp(&devid, &(groupProps->name[0]), sizeof (devid)) != 0) {
		ret = 5;
		goto cleanup;
	}

	stmfFreeMemory(groupProps);

	stmfRet = stmfRemoveFromTargetGroup((stmfGroupName *)groupName,
	    &devid);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 6;
		goto cleanup;
	}

	stmfRet = stmfGetTargetGroupMembers((stmfGroupName *)groupName,
	    &groupProps);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 7;
		goto cleanup;
	}

	if (groupProps->cnt != 0) {
		ret = 8;
		goto cleanup;
	}

cleanup:
	(void) stmfDeleteTargetGroup((stmfGroupName *)groupName);
	(void) system("svcadm enable -rs stmf");
	(void) stmfDeleteHostGroup((stmfGroupName *)groupName);
	return (ret);
}

int
main()
{
	return (stmfRemoveFromTargetGroup001());
}
