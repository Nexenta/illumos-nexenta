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
 * check_domain_mt.c
 *    This program starts multiple threads to call mapid_check_domain()
 *    and test its thread-safety.
 *
 * Return value:
 *    On success, it returns 0; on error, it returns 1.
 *
 * Usage:
 *    ./check_domain_mt
 */

#include <stdio.h>
#include <pthread.h>
#include <nfs/mapid.h>

#define	FIFTY_CHARS "x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x."
#define	TWOHUNDRED_CHARS FIFTY_CHARS FIFTY_CHARS FIFTY_CHARS FIFTY_CHARS

typedef struct domain_check {
	char *str;
	int ret;
} domain_check_t;

domain_check_t data[] = {
	{ "helloworld", 1},
	{ "hello.world", 1},
	{ "HELLO.WORLD", 1},
	{ "hello-world.1234", 1},
	{ TWOHUNDRED_CHARS FIFTY_CHARS"12345", 1},
	{ "hello world", 0},
	{ "hello@world", 0},
	{ "1234.world", 1},
	{ "hello.worl-", 0},
	{ "hello.world ", 0},
	{ TWOHUNDRED_CHARS FIFTY_CHARS"123456", -1},
	{ "", 0}
};

#define	NTHREADS	(sizeof (data) / sizeof (domain_check_t))

void *check_domain(void *arg);

int
main()
{
	pthread_t threads[NTHREADS+1];
	int ids[NTHREADS+1];
	char *p;
	int i;
	int status;
	int *p_status = &status;

	/* start threads */
	for (i = 1; i <= NTHREADS; i++) {
		ids[i] = i;
		if (pthread_create(&threads[i], NULL, check_domain, &ids[i])) {
			fprintf(stderr, "failed to start thread %d\n", i);
			perror("pthread_create");
			exit(1);
		}
	}

	/* check threads' exit statuses */
	for (i = 1; i <= NTHREADS; i++) {
		if (pthread_join(threads[i], (void **)&ids[i])) {
			fprintf(stderr, "failed to get thread %d status\n", i);
			perror("pthread_join");
			exit(1);
		}

		if (ids[i]) {
			fprintf(stderr, "thread %d terminated abnormally\n");
			exit(1);
		}
	}

	exit(0);
}

void *
check_domain(void *arg) {
	int id = *((int *)arg);

	if (mapid_stdchk_domain(data[id-1].str) != data[id-1].ret) {
		fprintf(stderr,
			"mapid_stdchk_domain() failed in thread %d\n", id);
		pthread_exit((void *)1);
	}

	pthread_exit((void *)0);
}
