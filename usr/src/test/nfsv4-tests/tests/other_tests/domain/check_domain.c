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
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * check_domain.c
 *    This program takes domain string from command line and calls
 *    mapid_stdchk_domain() to check it. Result value is output on
 *    stdout.
 *
 * Return value:
 *    On success, returns 0; on error, returns 1.
 *
 * Usage:
 *    ./check_domain <domain> <expected_result>
 */

#include <stdio.h>
#include <nfs/mapid.h>

int
main(int argc, char **argv)
{
	int valid;

	if (argc != 3) {
		fprintf(stderr,
		    "Usage: %s <domain> <expected_result>\n", argv[0]);
		exit(1);
	}

	valid = mapid_stdchk_domain(argv[1]);
	printf("%d\n", valid);

	if (valid != atoi(argv[2])) exit(1);

	exit(0);
}
