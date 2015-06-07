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
stmfGetLogicalUnitList001()
{
	int stmfRet;
	int ret = 0;
	int i;
	boolean_t foundA = B_FALSE, foundB = B_FALSE;
	stmfGuidList *luList;
	stmfGuid guidA, guidB;
	stmfLogicalUnitProperties luProps;
	char sbdadmDeleteLuA[MAXPATHLEN];
	char sbdadmDeleteLuB[MAXPATHLEN];
	char guidAsciiBufA[33];
	char guidAsciiBufB[33];

	(void) system("touch /tmp/stmfGetLogicalUnitListA.lu");
	(void) system("touch /tmp/stmfGetLogicalUnitListB.lu");
	(void) system("sbdadm create-lu -s 10g"
	    " /tmp/stmfGetLogicalUnitListA.lu");
	(void) system("sbdadm create-lu -s 10g"
	    " /tmp/stmfGetLogicalUnitListB.lu");
	stmfRet = stmfGetLogicalUnitList(&luList);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup;
	}

	for (i = 0; i < luList->cnt; i++) {
		stmfRet = stmfGetLogicalUnitProperties(&(luList->guid[i]),
		    &luProps);
		if (strncmp(luProps.alias, "/tmp/stmfGetLogicalUnitListA.lu",
		    sizeof (luProps.alias)) == 0) {
			foundA = B_TRUE;
			bcopy(&luList->guid[i], &guidA, sizeof (guidA));
		}
		if (strncmp(luProps.alias, "/tmp/stmfGetLogicalUnitListB.lu",
		    sizeof (luProps.alias)) == 0) {
			foundB = B_TRUE;
			bcopy(&luList->guid[i], &guidB, sizeof (guidB));
		}
	}
	if (!foundA || !foundB) {
		ret = 2;
		goto cleanup;
	}

	guidToAscii(&guidA, guidAsciiBufA);
	guidToAscii(&guidB, guidAsciiBufB);

	(void) snprintf(sbdadmDeleteLuA, sizeof (sbdadmDeleteLuA), "%s %s",
	    "sbdadm delete-lu", guidAsciiBufA);

	(void) snprintf(sbdadmDeleteLuB, sizeof (sbdadmDeleteLuA), "%s %s",
	    "sbdadm delete-lu", guidAsciiBufB);

cleanup:
	(void) system(sbdadmDeleteLuA);
	(void) system(sbdadmDeleteLuB);
	(void) system("rm /tmp/stmfGetLogicalUnitListA.lu");
	(void) system("rm /tmp/stmfGetLogicalUnitListB.lu");
	return (ret);
}

int
main()
{
	return (stmfGetLogicalUnitList001());
}
