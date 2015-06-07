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
stmfAddViewEntry001()
{
	int ret = 0;
	int i;
	boolean_t found = B_FALSE;
	stmfViewEntry viewEntry;
	stmfGuidList *luList;
	stmfLogicalUnitProperties luProps;
	stmfViewEntryList *viewEntryList;
	char sbdadmDeleteLu[MAXPATHLEN];
	char guidAsciiBuf[33];
	int stmfRet;

	bzero(&viewEntry, sizeof (viewEntry));
	(void) system("touch /tmp/stmfAddViewEntry.lu");
	(void) system("sbdadm create-lu -s 10g /tmp/stmfAddViewEntry.lu");
	stmfRet = stmfGetLogicalUnitList(&luList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup1;
	}

	for (i = 0; i < luList->cnt; i++) {
		stmfRet = stmfGetLogicalUnitProperties(&(luList->guid[i]),
		    &luProps);
		if (strncmp(luProps.alias, "/tmp/stmfAddViewEntry.lu",
		    sizeof (luProps.alias)) == 0) {
			found = B_TRUE;
			break;
		}
	}
	if (!found) {
		ret = 1;
		goto cleanup1;
	}

	guidToAscii(&luList->guid[i], guidAsciiBuf);

	(void) snprintf(sbdadmDeleteLu, sizeof (sbdadmDeleteLu), "%s %s",
	    "sbdadm delete-lu", guidAsciiBuf);

	viewEntry.allHosts = B_TRUE;
	viewEntry.allTargets = B_TRUE;
	viewEntry.luNbrValid = B_FALSE;

	stmfRet = stmfAddViewEntry(&(luList->guid[i]), &viewEntry);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup2;
	}

	stmfRet = stmfGetViewEntryList(&(luList->guid[i]), &viewEntryList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup3;
	}

	if (viewEntryList->cnt > 0) {
		if ((viewEntryList->ve[0].allHosts != B_TRUE) ||
		    (viewEntryList->ve[0].allTargets != B_TRUE)) {
			ret = 2;
			goto cleanup3;
		}
		if (viewEntryList->ve[0].luNbrValid != B_TRUE) {
			ret = 2;
			goto cleanup3;
		}
	}

cleanup3:
	(void) stmfRemoveViewEntry(&(luList->guid[i]),
	    viewEntryList->ve[0].veIndex);
cleanup2:
	(void) printf("Executing - %s\n", sbdadmDeleteLu);
	(void) system(sbdadmDeleteLu);
cleanup1:
	(void) system("/usr/bin/rm /tmp/stmfAddViewEntry.lu");
	return (ret);
}

int
main()
{
	return (stmfAddViewEntry001());
}
