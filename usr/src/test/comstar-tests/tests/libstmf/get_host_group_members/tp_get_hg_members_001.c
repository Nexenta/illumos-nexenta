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
stmfGetHostGroupMembers001()
{
	int ret = 0;
	int i;
	int stmfRet;
	uchar_t wwn[8];
	char *groupName = "h01";
	int found = 0;
	stmfDevid devid1, devid2;
	stmfGroupProperties *groupProps;

	bzero(&devid1, sizeof (devid1));
	bzero(&devid2, sizeof (devid2));
	stmfRet = stmfCreateHostGroup((stmfGroupName *)groupName);
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

	stmfRet = stmfDevidFromWwn(wwn, &devid1);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 2;
		goto cleanup;
	}

	stmfRet = stmfAddToHostGroup((stmfGroupName *)groupName, &devid1);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 3;
		goto cleanup;
	}

	wwn[0] = 0xab;
	wwn[1] = 0xcd;
	wwn[2] = 0xef;
	wwn[3] = 0x01;
	wwn[4] = 0x23;
	wwn[5] = 0x45;
	wwn[6] = 0x67;
	wwn[7] = 0x89;

	stmfRet = stmfDevidFromWwn(wwn, &devid2);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 4;
		goto cleanup;
	}

	stmfRet = stmfAddToHostGroup((stmfGroupName *)groupName, &devid2);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 5;
		goto cleanup;
	}
	stmfRet = stmfGetHostGroupMembers((stmfGroupName *)groupName,
	    &groupProps);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 6;
		goto cleanup;
	}

	for (i = 0; i < groupProps->cnt; i++) {
		if ((bcmp(&devid1, &(groupProps->name[i]),
		    sizeof (devid1)) == 0) ||
		    (bcmp(&devid2, &(groupProps->name[i]),
		    sizeof (devid2)) == 0)) {
			found++;
		}
	}

	if (found != 2) {
		ret = 7;
		goto cleanup;
	}

cleanup:
	(void) stmfDeleteHostGroup((stmfGroupName *)groupName);
	return (ret);
}

int
main()
{
	return (stmfGetHostGroupMembers001());
}
