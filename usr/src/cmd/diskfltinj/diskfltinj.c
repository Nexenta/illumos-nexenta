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
 * Copyright 2013 Nexenta Systems, Inc.  All rights reserved.
 */

/*
 * Command-line utility for injecting SCSI transport errors in SD targets.
 * It utilizes fault injection framework, so make sure both SD and MPTSAS
 * drivers support it, or some IOCTLs may fail.
 */

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <strings.h>
#include <stdarg.h>
#include <sys/types.h>

#define	SDIOC		('T'<<8)
#define	SDIOCSTART	(SDIOC|1)
#define	SDIOCSTOP	(SDIOC|2)
#define	SDIOCPUSH	(SDIOC|7)
#define	SDIOCRETRIEVE	(SDIOC|8)
#define	SDIOCRUN	(SDIOC|9)
#define	SDIOCINSERTTRAN	(SDIOC|0xA)

enum sd_fi_tran_cmd {
/*
 * Reject this command instead of sending it the hardware.
 * Results in immediate rejecting the packet by the HBA with the TRAN_BUSY
 * reason.
 */
	SD_FLTINJ_CMD_BUSY,

/*
 * Time-out this command.
 * Results in putting the command to a stashed queue in the HBA, returning
 * TRAN_ACCEPT to the target driver and calling its completion
 * handler with the reason set to CMD_TIMEOUT, when command timeout expires
 */
	SD_FLTINJ_CMD_TIMEOUT
};

struct sd_fi_tran {
	enum sd_fi_tran_cmd tran_cmd;
};

void
usage(void)
{
	printf("diskfltinj -c command [-s] [-f] [-r] [-a] <devpath>\n");
	printf("  -c: Apply fault injection command. The following commands");
	printf("      are supported:\n");
	printf("       reject    Reject command immediately\n");
	printf("       timeout   Cause command timeout expiration\n");
	printf("  -s:  Start a new fault injection session.\n");
	printf("  -f:  Reset current fault injection session.\n");
	printf("  -r:  Run fault injection.\n");
	printf("  -a:  Access target device (read one sector).\n");
	printf("  -v:  Verbose mode.\n");
	exit(1);
}

int verbose = 0;

void
v_output(const char *fmt, ...)
{
	if (verbose) {
		va_list args;
		va_start(args, fmt);
		vfprintf(stderr, fmt, args);
		va_end(args);
	}
}

int
main(int argc, char **argv)
{
	int fd = 0;
	unsigned char buf[512];
	struct sd_fi_tran tr_err;
	int cmd = -1, opt;
	int do_access = 0;
	int start_inj = 0;
	char *devpath = NULL;
	int stop_inj = 0;
	int run_inj = 0;

	while ((opt = getopt(argc, argv, "asvfrc:")) != -1) {
		switch (opt) {
			case 'v':
				verbose = 1;
				break;
			case 'a':
				do_access = 1;
				break;
			case 's':
				start_inj = 1;
				break;
			case 'r':
				run_inj = 1;
				break;
			case 'f':
				stop_inj = 1;
				break;
			case 'c':
				if (strcmp(optarg, "reject") == 0) {
					cmd = SD_FLTINJ_CMD_BUSY;
				} else if (strcmp(optarg, "timeout") == 0) {
					cmd = SD_FLTINJ_CMD_TIMEOUT;
				} else {
					usage();
				}
				break;
			default:
				usage();
		}
	}

	/* Handle device name. */
	if ((argc - optind) == 1) {
		devpath = argv[optind];
	} else {
		usage();
	}

	/* Action must be specified. */
	if (cmd == -1 && !stop_inj && !run_inj && !start_inj) {
		usage();
	}

	/* Open device. */
	printf("Target device: %s\n", devpath);
	if ((fd = open(devpath, O_RDONLY|O_NDELAY)) == -1) {
		perror("open");
		exit(1);
	}

	/* Start new fault injection session. */
	if (start_inj) {
		v_output("Starting a new fault injection session.\n");
		if (ioctl(fd, SDIOCSTART, NULL) == -1) {
			perror("ioctl SDIOCSTART");
			exit(1);
		}
	}

	/* Inject a command. */
	if (cmd != -1) {
		tr_err.tran_cmd = cmd;

		v_output("Injecting fault.\n");
		if (ioctl(fd, SDIOCINSERTTRAN, &tr_err) == -1) {
			perror("ioctl SDIOCINSERTTRAN");
			exit(1);
		}

		if (ioctl(fd, SDIOCPUSH, NULL) == -1) {
			perror("ioctl SDIOCPUSH");
			exit(1);
		}
	}

	/* Run injection sequence. */
	if (run_inj) {
		v_output("Activating fault injection sequence.\n");
		if (ioctl(fd, SDIOCRUN, NULL) == -1) {
			perror("ioctl SDIOCRUN");
			exit(1);
		}
	}

	/* Access the device, if requested. */
	if (do_access) {
		v_output("Accessing target device.\n");
		read(fd, buf, sizeof (buf));
	}

	/* Stop fault injection, if requested */
	if (stop_inj) {
		v_output("Stopping fault injection session.\n");
		if (ioctl(fd, SDIOCSTOP, NULL) == -1) {
			perror("ioctl SDIOCSTOP");
			exit(1);
		}
	}

	return (0);
}
