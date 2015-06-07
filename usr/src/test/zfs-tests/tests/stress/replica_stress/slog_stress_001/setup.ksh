#!/usr/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)setup.ksh	1.1	07/10/09 SMI"
#

. ${STF_SUITE}/include/libtest.shlib
. ${STF_SUITE}/tests/stress/replica_stress/replica_stress_common.kshlib

setup_mirrors $NUMBER_OF_MIRRORS $DISKS

ln=0
for pool in $(get_pools); do
	$MKFILE 64m /var/tmp/slog.001.${ln}

	$ZPOOL add $pool /var/tmp/slog.001.${ln}
	(( ln = ln + 1 ))
done

log_pass
