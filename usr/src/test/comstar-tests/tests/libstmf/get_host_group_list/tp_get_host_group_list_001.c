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
stmfGetHostGroupList001()
{
	int ret = 0;
	int stmfRet = 0;
	int i;
	int found = 0;
	stmfGroupList *groupList;
	char *hostGroup1 = "h01";
	char *hostGroup2 = "h02";
	char *hostGroup3 = "h03";

	stmfRet = stmfCreateHostGroup((stmfGroupName *)hostGroup1);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup;
	}

	stmfRet = stmfCreateHostGroup((stmfGroupName *)hostGroup2);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 2;
		goto cleanup;
	}

	stmfRet = stmfCreateHostGroup((stmfGroupName *)hostGroup3);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 3;
		goto cleanup;
	}

	stmfRet = stmfGetHostGroupList(&groupList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 4;
		goto cleanup;
	}

	for (i = 0; i < groupList->cnt; i++) {
		if ((strcmp(hostGroup1, (char *)groupList->name[i]) == 0) ||
		    (strcmp(hostGroup2, (char *)groupList->name[i]) == 0) ||
		    (strcmp(hostGroup3, (char *)groupList->name[i]) == 0)) {
			found++;
		}
	}

	if (found != 3) {
		ret = 5;
		goto cleanup;
	}

cleanup:
	(void) stmfDeleteHostGroup((stmfGroupName *)hostGroup1);
	(void) stmfDeleteHostGroup((stmfGroupName *)hostGroup2);
	(void) stmfDeleteHostGroup((stmfGroupName *)hostGroup3);
	return (ret);
}

int
main()
{
	return (stmfGetHostGroupList001());
}
