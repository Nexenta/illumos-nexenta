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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * get_domain.c
 *    This file calls mapid_get_domain() to get mapid domain on the
 *    system. To do that, it needs to call mapid_reeval_domain() first.
 *
 * Return Value:
 *    On success, it outputs the value on stdout, and returns 0;
 *    on error, it returns 1.
 *
 * Usage:
 *    ./get_domain
 */

#include <stdio.h>
#include <nfs/mapid.h>

int
main()
{
	char *p;

	mapid_reeval_domain((cb_t *)0);
	p = mapid_get_domain();

	if (!p) exit(1);

	printf("%s\n", p);
	exit(0);
}
