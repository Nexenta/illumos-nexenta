/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only
 * (the "License").  You may not use this file except in compliance
 * with the License.
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
 * Copyright (c) 2001 by Sun Microsystems, Inc.
 * All rights reserved.
 */

#pragma ident	"%Z%%M%	%I%	%E% SMI"

#include <stdio.h>
#include <stdlib.h>
#include <alloca.h>
#include <string.h>
#include <errno.h>
#include <dhcp_svc_confopt.h>

int
main(void)
{
	int		i;
	dhcp_confopt_t	*dsp;

	if (read_dsvc_conf(&dsp) < 0) {
		if (errno != ENOENT) {
			perror("Read failed");
			return (1);
		} else {
			(void) fprintf(stderr,
			    "Read failed because file does not exist\n");
			/*
			 * Make one.
			 */
			dsp = alloca(4 * sizeof (dhcp_confopt_t));
			dsp[0].co_type	  = DHCP_COMMENT;
			dsp[0].co_comment = " Generated by test_confopt";
			dsp[1].co_type    = DHCP_KEY;
			dsp[1].co_key     = "RESOURCE";
			dsp[1].co_value   = "files";
			dsp[2].co_type    = DHCP_KEY;
			dsp[2].co_key     = "PATH";
			dsp[2].co_value   = "/var/dhcp";
			dsp[3].co_type    = DHCP_END;
		}
	} else {
		(void) printf("Read worked\n");

		for (i = 0; dsp[i].co_type != DHCP_END; i++) {
			if (dsp[i].co_type == DHCP_KEY) {
				(void) printf("Key: %s, Value: %s\n",
				    dsp[i].co_key, dsp[i].co_value);
				if (strcmp(dsp[i].co_key, "RESOURCE") == 0) {
					free(dsp[i].co_value);
					dsp[i].co_value = strdup("nisplus");
				}
			} else {
				(void) printf("Comment: %s\n",
				    dsp[i].co_comment);
			}
		}
	}

	if (write_dsvc_conf(dsp, 0644) < 0) {
		perror("Write failed");
		return (1);
	} else
		(void) printf("Write worked\n");

	free_dsvc_conf(dsp);
	return (0);
}