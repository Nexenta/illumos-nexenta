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
 * get_domain_mt.c
 *    This program starts multiple threads to call mapid_get_domain()
 *    and test its thread-safety.
 *
 * Return value:
 *    On success, it returns 0; on error, it returns 1.
 *
 * Usage:
 *    ./get_domain_mt
 */

#include <stdio.h>
#include <pthread.h>
#include <nfs/mapid.h>

#define	NTHREADS	100

char domain[256];

void *get_domain(void *arg);

int
main()
{
	pthread_t threads[NTHREADS+1];
	int ids[NTHREADS+1];
	char *p;
	int i;

	mapid_reeval_domain((cb_t *)0);
	p = mapid_get_domain();
	if (!p) {
		fprintf(stderr, "mapid_get_domain() returned NULL\n");
		perror("mapid_get_domain");
		exit(1);
	}
	strcpy(domain, p);

	/* start threads */
	for (i = 1; i <= NTHREADS; i++) {
		ids[i] = i;
		if (pthread_create(&threads[i], NULL, get_domain, &ids[i])) {
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
get_domain(void *arg) {
	int id = *((int *)arg);
	char *p;

	p = mapid_get_domain();
	if (!p) {
		fprintf(stderr, "mapid_get_domain() returned NULL"
		"in thread %d\n", id);
		perror("mapid_get_domain");
		pthread_exit((void *)1);
	}

	if (strcmp(domain, p)) {
		fprintf(stderr, "domain values don't match:\n");
		fprintf(stderr, "Main Thread\t\tThread %d\n", id);
		fprintf(stderr, "===========\t\t=========\n", id);
		fprintf(stderr, "%s\t\t%s\n", domain, p);
		pthread_exit((void *)1);
	}

	pthread_exit((void *)0);
}
