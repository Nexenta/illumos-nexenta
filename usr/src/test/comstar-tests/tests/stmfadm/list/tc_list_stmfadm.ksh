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

#
# The main test case file for the list subfunction of the stmfadm command.
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
iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11"
ic1="list001"
ic2="list002"
ic3="list003"
ic4="list004"
ic5="list005"
ic6="list006"
ic7="list007"
ic8="list008"
ic9="list009"
ic10="list010"
ic11="list011"
#
# Source in each of the test purpose files that are associated with
# each of the invocable components listed in the previous settings.
#
. ./tp_list_stmfadm_001
. ./tp_list_stmfadm_002
. ./tp_list_stmfadm_003
. ./tp_list_stmfadm_004
. ./tp_list_stmfadm_005
. ./tp_list_stmfadm_006
. ./tp_list_stmfadm_007
. ./tp_list_stmfadm_008
. ./tp_list_stmfadm_009
. ./tp_list_stmfadm_010
. ./tp_list_stmfadm_011

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
	cti_report "Checking environment and runability"
	comstar_startup_fc_target

}

#
# The cleanup function that will be called when this test case is
# invoked after all the test purposes are executed (or aborted).
#
function cleanup
{
        #
        # Call the _cleanup function to list any filesystems that were
        # in use and free any resource that might still be in use by the tests.
        #
	cti_report "Cleaning up after tests"
	comstar_cleanup_fc_target
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
