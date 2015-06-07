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

#include <libstmftest.h>

static int
stmfAddViewEntry003()
{
	int ret = 0;
	int i;
	boolean_t foundA = B_FALSE, foundB = B_FALSE;
	stmfViewEntry viewEntry;
	stmfGuidList *luList;
	stmfGuid guidA, guidB;
	stmfLogicalUnitProperties luProps;
	char sbdadmDeleteLuA[MAXPATHLEN];
	char sbdadmDeleteLuB[MAXPATHLEN];
	char guidAsciiBufA[33];
	char guidAsciiBufB[33];
	int stmfRet;

	bzero(&viewEntry, sizeof (viewEntry));
	(void) system("touch /tmp/stmfAddViewEntryA.lu");
	(void) system("touch /tmp/stmfAddViewEntryB.lu");
	(void) system("sbdadm create-lu -s 10g /tmp/stmfAddViewEntryA.lu");
	(void) system("sbdadm create-lu -s 10g /tmp/stmfAddViewEntryB.lu");
	stmfRet = stmfGetLogicalUnitList(&luList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup1;
	}

	for (i = 0; i < luList->cnt; i++) {
		stmfRet = stmfGetLogicalUnitProperties(&(luList->guid[i]),
		    &luProps);
		if (strncmp(luProps.alias, "/tmp/stmfAddViewEntryA.lu",
		    sizeof (luProps.alias)) == 0) {
			foundA = B_TRUE;
			bcopy(&luList->guid[i], &guidA, sizeof (guidA));
		}
		if (strncmp(luProps.alias, "/tmp/stmfAddViewEntryB.lu",
		    sizeof (luProps.alias)) == 0) {
			foundB = B_TRUE;
			bcopy(&luList->guid[i], &guidB, sizeof (guidB));
		}
	}
	if (!foundA || !foundB) {
		ret = 1;
		goto cleanup1;
	}

	guidToAscii(&guidA, guidAsciiBufA);
	guidToAscii(&guidB, guidAsciiBufB);

	(void) snprintf(sbdadmDeleteLuA, sizeof (sbdadmDeleteLuA), "%s %s",
	    "sbdadm delete-lu", guidAsciiBufA);

	(void) snprintf(sbdadmDeleteLuB, sizeof (sbdadmDeleteLuA), "%s %s",
	    "sbdadm delete-lu", guidAsciiBufB);

	viewEntry.allHosts = B_TRUE;
	viewEntry.allTargets = B_TRUE;
	viewEntry.luNbrValid = B_TRUE;
	viewEntry.luNbr[0] = 232 >> 8;
	viewEntry.luNbr[1] = 232 & 0xff;

	stmfRet = stmfAddViewEntry(&guidA, &viewEntry);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup2;
	}

	stmfRet = stmfAddViewEntry(&guidB, &viewEntry);
	if (stmfRet != STMF_ERROR_LUN_IN_USE) {
		ret = 2;
		goto cleanup2;
	}

cleanup3:
	(void) stmfRemoveViewEntry(&guidA, 0);
cleanup2:
	(void) system(sbdadmDeleteLuA);
	(void) system(sbdadmDeleteLuB);
cleanup1:
	(void) system("rm /tmp/stmfAddViewEntryA.lu");
	(void) system("rm /tmp/stmfAddViewEntryB.lu");
	return (ret);
}

int
main()
{
	return (stmfAddViewEntry003());
}
