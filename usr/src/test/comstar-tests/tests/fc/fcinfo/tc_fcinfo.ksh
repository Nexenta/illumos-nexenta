#! /usr/bin/ksh -p
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


tet_startup=startup
tet_cleanup=cleanup
iclist="ic1 ic2 ic3 ic4"
ic1="tp_fcinfo_001"
ic2="tp_fcinfo_002"
ic3="tp_fcinfo_003"
ic4="tp_fcinfo_004"

function startup
{
	cti_report "Checking environment and runability"
	create_comstar_logdir
}

function cleanup
{
	cti_report "Cleaning up after tests"
}

# test purpose for comstar related fcinfo commands
. ./tp_fcinfo_001
. ./tp_fcinfo_002
. ./tp_fcinfo_003
. ./tp_fcinfo_004
#
# Source in the common utilities and tools that are used by the test purposes
# and test case.
#

. ${CTI_SUITE}/lib/comstar_common

#
# Source in the cti and tet required utilities and tools.
#
. ${CTI_ROOT}/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
