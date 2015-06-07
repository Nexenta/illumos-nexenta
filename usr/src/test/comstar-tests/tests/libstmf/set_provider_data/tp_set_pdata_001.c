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
stmfSetProviderData001()
{
	/* currently same as stmfGetProviderData001 */
	/* return (stmfGetProviderData001()); */
	int stmfRet;
	int ret = 0;
	char *test = "TEST_LU_PROVIDER";
	char *lookup;
	nvlist_t *nvl;
	nvlist_t *nvlGet = NULL;

	(void) nvlist_alloc(&nvl, NV_UNIQUE_NAME, 0);

	(void) nvlist_add_string(nvl, test, test);

	stmfRet = stmfSetProviderData("tape-dev", nvl, STMF_LU_PROVIDER_TYPE);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 1;
		goto cleanup;
	}

	stmfRet = stmfGetProviderData("tape-dev", &nvlGet,
	    STMF_LU_PROVIDER_TYPE);
	if (stmfRet != STMF_STATUS_SUCCESS) {
		ret = 2;
		goto cleanup;
	}
	if (nvlist_lookup_string(nvlGet, test, &lookup) != 0) {
		ret = 3;
		goto cleanup;
	}

cleanup:
	(void) stmfClearProviderData("tape-dev", STMF_LU_PROVIDER_TYPE);
	nvlist_free(nvl);
	nvlist_free(nvlGet);
	return (ret);
}

int
main()
{
	return (stmfSetProviderData001());
}
