/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2012 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Test program for files / netgroup support
 */

#include <netdb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int verbose;

/*
 * Debug magic!  See lib/nsswitch/files/common/getnetgrent.c
 */

void
__nss_files_netgr_debug(const char *fmt, ...)
{
	va_list ap;

	if (!verbose)
		return;

	va_start(ap, fmt);
	(void) printf("debug: ");
	(void) vprintf(fmt, ap);
	(void) printf("\n");
	va_end(ap);
}

void
__nss_files_netgr_error(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	(void) printf("error: ");
	(void) vprintf(fmt, ap);
	(void) printf("\n");
	va_end(ap);
}

void
usage(char *prog)
{
	(void) fprintf(stderr,
	    "usage: %s [-v] [-h host] [-u user] [-d domain] netgroup\n", prog);
	exit(1);
}

int
main(int argc, char **argv)
{
	char *netgrname;
	char *host = NULL;
	char *user = NULL;
	char *dom = NULL;
	int c, rc;

	while ((c = getopt(argc, argv, "vh:u:d:")) != EOF) {
		switch (c) {
		case 'v':
			verbose++;
			break;
		case 'h':
			host = optarg;
			break;
		case 'u':
			user = optarg;
			break;
		case 'd':
			dom = optarg;
			break;
		case '?':
			usage(argv[0]);
		}
	}

	if ((optind + 1) != argc)
		usage(argv[0]);
	netgrname = argv[optind];

	rc = innetgr(netgrname, host, user, dom);
	(void) printf("%s\n", (rc) ? "yes" : "no");

#ifdef	lint
	__nss_files_netgr_debug("");
	__nss_files_netgr_error("");
#endif

	return (0);
}
