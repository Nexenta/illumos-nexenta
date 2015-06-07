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
# The main test case file for the offline subfunction of the stmfadm command.
# This file contains the test startup functions and the invocable component offline
# of all the test purposes that are to be executed.
#

#
# Set the tet global variables tet_startup and tet_cleanup to the
# startup and cleanup function names
#
tet_startup="startup"
tet_cleanup="cleanup"

#
# The offline of invocable components for this test case set.
# All the components are a 1:1 relation to each test purpose.
#
iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10"
iclist="$iclist ic11 ic12 ic13 ic14 ic15 ic16 ic17 ic18 ic19 ic20"
ic1="offline001"
ic2="offline002"
ic3="offline003"
ic4="offline004"
ic5="offline005"
ic6="offline006"
ic7="offline007"
ic8="offline008"
ic9="offline009"
ic10="offline010"
ic11="offline011"
ic12="offline012"
ic13="offline013"
ic14="offline014"
ic15="offline015"
ic16="offline016"
ic17="offline017"
ic18="offline018"
ic19="offline019"
ic20="offline020"
#
# Source in each of the test purpose files that are associated with
# each of the invocable components offlineed in the previous settings.
#
. ./tp_offline_stmfadm_001
. ./tp_offline_stmfadm_002
. ./tp_offline_stmfadm_003
. ./tp_offline_stmfadm_004
. ./tp_offline_stmfadm_005
. ./tp_offline_stmfadm_006
. ./tp_offline_stmfadm_007
. ./tp_offline_stmfadm_008
. ./tp_offline_stmfadm_009
. ./tp_offline_stmfadm_010
. ./tp_offline_stmfadm_011
. ./tp_offline_stmfadm_012
. ./tp_offline_stmfadm_013
. ./tp_offline_stmfadm_014
. ./tp_offline_stmfadm_015
. ./tp_offline_stmfadm_016
. ./tp_offline_stmfadm_017
. ./tp_offline_stmfadm_018
. ./tp_offline_stmfadm_019
. ./tp_offline_stmfadm_020

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
        # Call the _cleanup function to offline any filesystems that were
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
