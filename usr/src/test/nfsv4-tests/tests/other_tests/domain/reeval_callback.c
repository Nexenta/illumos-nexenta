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
 * reeval_callback.c
 *    This file is designed to test mapid_reeval_domain(cb_t *)'s
 *    callback behavior. It sends requests to libmapid_syscfgd.ksh to
 *    change configuration on the test system, and then call
 *    mapid_reeval_domain() and check the callback function passed to it
 *    is invoked and the new domain value is correct.
 *
 * Return value:
 *    On success, it returns 0; on error, it returns 1.
 *
 * Usage:
 *    ./reeval_callback <setup_cmd> <cleanup_cmd>
 *        - setup_cmd: the cmd to change system configuration
 *        - cleanup_cmd: the cmd to restore sytem configuration
 */

#include <stdio.h>
#include <nfs/mapid.h>

#define	DNAMEMAX	(NS_MAXCDNAME + 1)
#define	LOG(fmt, ...)	if (b_debug) { printf(fmt, __VA_ARGS__); }
#define	STRLEN	128

char domain_from_cb[DNAMEMAX];
char domain_from_lib[DNAMEMAX];
int b_debug;
char tmpdir[STRLEN/2] = { 0 };

void *cb_get_domain(void *);
int execute_command(char *);

int
main(int argc, char ** argv)
{
	cb_t cb;
	FILE *file;
	char *p;
	char buffer[STRLEN];
	int n;
	char setup_cmd[STRLEN] = { 0 };
	char cleanup_cmd[STRLEN] = { 0 };

	/* check if debug mode is on */
	if ((p = getenv("DEBUG")) && atoi(p)) {
		b_debug = 1;
	}

	if ((p = getenv("TMPDIR"))) {
		strncpy(tmpdir, p, (STRLEN/2 - 1));
	} else {
		strcpy(tmpdir, "/tmp");
	}

	if (argc != 3) {
		fprintf(stderr, "Usage: %s <setup_cmd> <cleanup_cmd>\n",
		    argv[0]);
		exit(1);
	} else {
		strncpy(setup_cmd, argv[1], STRLEN-1);
		strncpy(cleanup_cmd, argv[2], STRLEN-1);
	}

	cb.fcn = cb_get_domain;
	/* calback function gets called only when there is domain change */
	cb.signal = 0;

	/*
	 * Round 1
	 */

	mapid_reeval_domain(&cb);

	strncpy(domain_from_lib, mapid_get_domain(), DNAMEMAX);
	LOG("Get new domain from lib: %s\n", domain_from_lib);

	if (strcmp(domain_from_lib, domain_from_cb)) {
		fprintf(stderr,
		    "domain values mismatch in initialization phase!\n");
		exit(1);
	}

	/*
	 * modify /etc/default/nfs
	 */
	if (execute_command(setup_cmd)) exit(1);

	/*
	 * Round 2
	 */

	mapid_reeval_domain(&cb);

	strncpy(domain_from_lib, mapid_get_domain(), DNAMEMAX);
	LOG("Get new domain from lib: %s\n", domain_from_lib);

	if (strcmp(domain_from_lib, domain_from_cb)) {
		fprintf(stderr,
		"domain values mismatch after system config changed!\n");
		exit(1);
	}

	/*
	 * Restore /etc/default/nfs
	 */
	if (execute_command(cleanup_cmd)) exit(1);

	exit(0);
}

void *
cb_get_domain(void * arg) {
	char    *new_domain = (char *)arg;

	strncpy(domain_from_cb, new_domain, DNAMEMAX);
	LOG("Get new domain from callback function: %s\n", domain_from_cb);
	return (0);
}

int
execute_command(char *cmd) {
	char fname[STRLEN];
	FILE *file;
	char buffer[STRLEN];
	int n;
	int b_succeed = 0;

	/* create $TMPDIR/<cmd> file to initiate the request */
	sprintf(fname, "%s/.libmapid/%s", tmpdir, cmd);

	file = fopen(fname, "w+");
	if (!file) {
		fprintf(stderr, "failed to create %s\n", fname);
		perror("fopen");
		return (1);
	}
	fclose(file);
	LOG("Create %s file\n", fname);

	/* check result file */
	n = 48;
	sprintf(fname, "%s/.libmapid/DONE", tmpdir);
	while (n > 0) {
		sleep(5);
		if ((file = fopen(fname, "r"))) {
			/* Got response! Check if it contains "OK" string */
			LOG("Get response in %s file\n", fname);

			fgets(buffer, STRLEN, file);
			if (strstr(buffer, "OK")) b_succeed = 1;
			fclose(file);

			break;
		}
		n--;
	}

	if (!n) {
		/* time ran out */
		fprintf(stderr, "%s not found...time out! \n", fname);
		return (1);
	}

	if (!b_succeed) {
		/* libmapid_syscfgd.ksh failed to handle the request */
		fprintf(stderr,
			"%s failed to modify /etc/default/nfs\n", fname);
		fprintf(stderr, "libmapid_syscfgd log: %s\n", buffer);
		return (1);
	}

	/* remove the result file */
	unlink(fname);

	return (0);
}
