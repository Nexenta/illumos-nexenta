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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_zones_named.ksh	1.3	09/03/09 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/startup_cleanup_common

startup=startup
cleanup=cleanup

test_list="
	tp_zones_named_001
"

function startup {
	cti_report "In startup"

}

function cleanup {
	cti_report "In cleanup"
}


. ./tp_zones_named_001	# Contains 'zones_named' test purpose 001

. ${TET_ROOT:?}/common/lib/ctilib.ksh
