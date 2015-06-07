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

# The main test case file to test iscsi authentication methods.
#
# This file contains the test startup functions and the invocable component list
# of all the test purposes that are to be executed.
#

#
# Set the tet global variables tet_startup and tet_cleanup to the
# startup and cleanup function names
#
tet_startup="startup"
tet_cleanup="cleanup"

#
# The list of invocable components for this test case set.
# All the components are a 1:1 relation to each test purpose.
#
iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11 ic12"

ic1="iscsi_auth_001"
ic2="iscsi_auth_002"
ic3="iscsi_auth_003"
ic4="iscsi_auth_004"
ic5="iscsi_auth_005"
ic6="iscsi_auth_006"
ic7="iscsi_auth_007"
ic8="iscsi_auth_008"
ic9="iscsi_auth_009"
ic10="iscsi_auth_010"
ic11="iscsi_auth_011"
ic12="iscsi_auth_012"

#
# Source in each of the test purpose files that are associated with
# each of the invocable components listed in the previous settings.
#
. ./tp_iscsi_auth_001
. ./tp_iscsi_auth_002
. ./tp_iscsi_auth_003
. ./tp_iscsi_auth_004
. ./tp_iscsi_auth_005
. ./tp_iscsi_auth_006
. ./tp_iscsi_auth_007
. ./tp_iscsi_auth_008
. ./tp_iscsi_auth_009
. ./tp_iscsi_auth_010
. ./tp_iscsi_auth_011
. ./tp_iscsi_auth_012

STAND_ALONE=1

#
# The startup function that will be called when this test case is
# invoked before any test purposes are executed.
#
function startup
{
        #
        # Call the _startup function to initialize the system and
        # verify the system resources and setup the filesystems to be
        # used by the tests.
        #
	cti_report "Starting up"
	comstar_startup_iscsi_target
}

#
# The cleanup function that will be called when this test case is
# invoked after all the test purposes are executed (or aborted).
#
function cleanup
{
        #
        # Call the _cleanup function to remove any filesystems that were
        # in use and free any resource that might still be in use by the tests.
        #
	cti_report "Cleaning up after tests"
	comstar_cleanup_iscsi_target
}

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

