#!/bin/ksh -p
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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_add_static.ksh	1.2	08/12/19 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/startup_cleanup_common

startup=startup
cleanup=cleanup

test_list="
	tp_add_static_001 \
"

function startup {
	cti_report "In startup"

	typical_startup_checks
	if (( $? != 0 )); then
		exit 1
	fi
}

function cleanup {
	cti_report "In cleanup"
	#
	# cleanup /dev/lof to prepare for the next test
	#
	if [ -d /dev/lofi ]; then
		rm -rf /dev/lofi
	fi
}


. ./tp_add_static_001	# Contains 'add_static' test purpose 001

. ${TET_ROOT:?}/common/lib/ctilib.ksh
