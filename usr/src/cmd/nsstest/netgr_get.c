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

#include <nsswitch.h>
#include <nss_common.h>
#include <nss_dbdefs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static DEFINE_NSS_DB_ROOT(db_root);

/*
 * This is a NSS str2ent (parse) function to fill in a
 * struct nss_netgrent.  See NSS_XbyY_INIT below.
 *
 * A specialized but parse-equivalent version of this function
 * is in the files back end.  See str2netr() in:
 * $SRC/lib/nsswitch/files/common/getnetgrent.c
 */
static int
str2netgr(const char *instr, int lenstr, void *ent, char *buffer, int buflen)
{
	const char sep[] = " \t\n";
	struct nss_netgrent *netgr = ent;
	char		*p;

	if (lenstr + 1 > buflen)
		return (NSS_STR_PARSE_ERANGE);

	/*
	 * We copy the input string into the output buffer and
	 * operate on it in place.
	 */
	if (instr != buffer) {
		/* Overlapping buffer copies are OK */
		(void) memmove(buffer, instr, lenstr);
		buffer[lenstr] = '\0';
	}

	/* quick exit do not entry fill if not needed */
	if (ent == (void *)NULL)
		return (NSS_STR_PARSE_SUCCESS);

	/* skip leading space */
	p = buffer;
	while (isspace(*p))
		p++;

	/* should be at the key */
	if (*p == '\0')
		return (NSS_STR_PARSE_PARSE);
	netgr->netgr_name = p;

	/* skip the key and null terminate */
	p = strpbrk(p, sep);
	if (p == NULL)
		return (NSS_STR_PARSE_PARSE);
	*p++ = '\0';

	/* skip separators */
	while (isspace(*p))
		p++;

	/*
	 * Should be at the members list, which is the
	 * rest of the input line.
	 */
	if (*p == '\0')
		return (NSS_STR_PARSE_PARSE);
	netgr->netgr_members = p;

	return (NSS_STR_PARSE_SUCCESS);
}

static void
initf_netgroup(nss_db_params_t *p)
{
	p->name	= NSS_DBNAM_NETGROUP;
	p->default_config = NSS_DEFCONF_NETGROUP;
}

struct nss_netgrent *
netgr_getbyname(const char *name, struct nss_netgrent *result,
	char *buffer, int buflen)
{
	nss_XbyY_args_t arg = {0};

	if (name == (const char *)NULL) {
		errno = ERANGE;
		return (NULL);
	}
	NSS_XbyY_INIT(&arg, result, buffer, buflen, str2netgr);
	arg.key.name = name;
	(void) nss_search(&db_root, initf_netgroup,
	    NSS_DBOP_NETGROUP_BYNAME, &arg);
	return ((struct nss_netgrent *)NSS_XbyY_FINI(&arg));
}

static char buf[NSS_LINELEN_NETGROUP];

int
main(int argc, char **argv)
{
	struct nss_netgrent netgr, *ng;
	int i;

	if (argc < 2) {
		(void) fprintf(stderr, "usage: %s netgroup [...]\n", argv[0]);
		exit(1);
	}

	for (i = 1; i < argc; i++) {
		ng = netgr_getbyname(argv[i], &netgr, buf, sizeof (buf));
		if (ng == NULL) {
			perror(argv[i]);
			continue;
		}
		(void) printf("%s => %s\n",
		    netgr.netgr_name,
		    netgr.netgr_members);
	}
	return (0);
}
