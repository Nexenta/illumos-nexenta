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

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	NUMUSERS	11
#define	NOOK		1

char	*testname;

void usage(int);


/*
 * Prints out the usage message and exits with the
 * passed in exit code "ec"
 */
void
usage(int ret)
{
	fprintf(stderr, "usage: %s [-h] [-d <dbg>] [-n <nfiles>]\n", testname);
	fprintf(stderr, "\t -d <dbg>      Information level: 0 - none \n"
	    "\t                                  1 - debug \n");
	fprintf(stderr, "\t -n <nfiles>    Number of files to create\n");
	fprintf(stderr, "\t -h help (this message\n");

	exit(ret);
}

/*
 * Main test loop.
 */
int
main(int  argc, char *argv[])
{
	extern int  optind;
	extern char *optarg;

	char  filename[256];
	int   file_flags = (O_CREAT|O_TRUNC|O_RDWR);
	int   fd = -1;
	int   i = 0;
	int   c;
	gid_t glist[NUMUSERS] = {0, 1, 2, 3, 4, 5, 8, 9,
				23456787, 23456788, 23456789};
	uid_t ulist[NUMUSERS] = {0, 1, 2, 3, 4, 5, 8, 9,
				10, 10, 1};
	gid_t gid = (gid_t)-1;
	uid_t uid = (uid_t)-1;

	/* default values */
	int   debug = 0; 	/* silent execution, no error messages */
	int   NumFiles = 1000;	/* 1K files */

	if (getuid() != 0 && geteuid() != 0) {
		fprintf(stderr, "ERROR: This program must be run as root.\n");
		exit(NOOK);
	}

	testname = argv[0];

	while ((c = getopt(argc, argv, "hd:n:")) != -1) {
		switch (c) {

		/* number of testcase runs to perform */
		case 'n':
			NumFiles = atoi(optarg);
			break;

		case 'd':
			switch (atoi(optarg)) {
			case 0:
				debug = 0;
				break;
			case 1:
				debug = 1;
				break;
			default:
				usage(-1);
			}
			break;

		case 'h':
			usage(0);
			break;
		default:
			usage(-1);
		}
	}

	if (debug)
		printf("DEBUG: NumFiles=%d\n", NumFiles);

	/* verify limits */
	if (NumFiles < 0) {
		fprintf(stderr,
		    "%s ERROR: number of files must be positive.\n", testname);
		exit(NOOK);
	}

	if (NumFiles >= 1000000) {
		fprintf(stderr,
		    "%s ERROR: number of files must be < 1000000.\n", testname);
		exit(NOOK);
	}

	if (debug)
		printf("DEBUG: NUMUSERS=%d\n", NUMUSERS);

	/*	Start creating tests */
	for (i = 0; i < NumFiles; i++) {
		/* create and open a file */
		sprintf(filename, "fil%06d", i);

		/* select and choose ids */
		gid = glist[i % NUMUSERS];
		if (setegid(gid) < 0) {
			fprintf(stderr, "ERROR: failed to setegid(%d)\n", gid);
			perror(" ");
			exit(NOOK);
		}

		uid = ulist[i % NUMUSERS];
		if (seteuid(uid) < 0) {
			fprintf(stderr, "ERROR: failed to seteuid(%d)\n", uid);
			perror(" ");
			exit(NOOK);
		}

		if (debug) {
			printf("DEBUG: in loop <i=%d> ...\n", i);
			printf("DEBUG:   euid=%d, egid=%d\n", uid, gid);
			printf("DEBUG:   open(%s, 0%o).\n", filename, 777);
		}
		/* create a file */
		if ((fd = open(filename, file_flags, 0777)) < 0) {
			fprintf(stderr,
			    "ERROR: failed to open(%s)\n", filename);
			perror(" ");
			exit(NOOK);
		}

		if (debug)
			printf("DEBUG:   reset euid=0, egid=0\n");
		/* return id to root */
		if (setegid(0) < 0) {
			fprintf(stderr, "ERROR: failed to re-setegid(0)\n");
			perror(" ");
			exit(NOOK);
		}

		if (seteuid(0) < 0) {
			fprintf(stderr, "ERROR: failed to re-seteuid(0)\n");
			perror(" ");
			exit(NOOK);
		}

		if (debug)
			printf("DEBUG:   closing <%s>\n", filename);
		/* close the file */
		if (close(fd) < 0) {
			fprintf(stderr,
			    "ERROR: failed to close(%s)\n", filename);
			perror(" ");
			exit(NOOK);
		}
	}

	printf("%s %d files were created successfully\n\n", testname, NumFiles);

	return (0);
}
