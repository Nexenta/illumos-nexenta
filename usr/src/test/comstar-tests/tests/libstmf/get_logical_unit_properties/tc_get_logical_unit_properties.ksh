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
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
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
# List of test purposes
#
iclist="ic1 ic2 ic3"
ic1="stmfGetLogicalUnitProperties001"
ic2="stmfGetLogicalUnitProperties002"
ic3="stmfGetLogicalUnitProperties003"


#
# Following functions invoke the binary test purpose
# and used by tet 
#

function stmfGetLogicalUnitProperties001 {
	./tp_get_lu_properties_001
	if [ $? -ne 0 ]; then
		cti_result FAIL
	else
		cti_result PASS
	fi
}

function stmfGetLogicalUnitProperties002 {
	./tp_get_lu_properties_002
	if [ $? -ne 0 ]; then
		cti_result FAIL
	else
		cti_result PASS
	fi
}

function stmfGetLogicalUnitProperties003 {
	./tp_get_lu_properties_003
	if [ $? -ne 0 ]; then
		cti_result FAIL
	else
		cti_result PASS
	fi
}

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
        comstar_startup
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
