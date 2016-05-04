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
 * derive_domain_dl.c
 *    This program uses dlopen() to load libmapid library and
 *    call mapid_derive_domain() to get mapid domain.
 *
 * Return value:
 *    On success, outputs domain value and returns 0;
 *    on error, returns 1.
 *
 * Usage:
 *    ./derive_domain_dl
 */

#include <stdio.h>
#include <dlfcn.h>
#include <link.h>
#include <nfs/mapid.h>

#define	LIB 	"/usr/lib/nfs/libmapid.so"
typedef char *(*DeriveDomain)(void);

int
main(int argc, char **argv)
{
	void * dlh;
	DeriveDomain derive_domain;

	dlh = dlopen(LIB, RTLD_LAZY);
	if (dlh == (void *)0) {
		fprintf(stderr, LIB" not found\n%s\n", dlerror());
		exit(1);
	}

	derive_domain = (DeriveDomain)dlsym(dlh, "mapid_derive_domain");
	if (derive_domain == (DeriveDomain)0) {
		fprintf(stderr, "mapid_derive_domain() not found\n");
		perror("dlsym");
		exit(1);
	}

	printf("%s\n", derive_domain());

	exit(0);
}
