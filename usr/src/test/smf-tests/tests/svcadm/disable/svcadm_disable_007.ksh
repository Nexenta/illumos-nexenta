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
# 
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

###############################################################################
# start __stf_assertion__
#
# ASSERTION: svcadm_disable_007
#
# DESCRIPTION:
#	svcadm disable <without any arguments> should fail with exit 2.
#	svcadm -v disable <without any arguments> should fail with exit 2.
# STRATEGY:
#
# COMMANDS: svcadm(1)
#
# end __stf_assertion__
################################################################################

# First load up definitions of STF result variables like STF_PASS etc.
. ${STF_TOOLS}/include/stf.kshlib

# Load up definitions of shell functionality common to all smf sub-suites.
. ${STF_SUITE}/include/gltest.kshlib

# Define Variables
readonly assertion=svcadm_disable_007
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# gltest.kshlib functions to extract and print assertion information
# from this source script.
extract_assertion_info $ME

# Initialize test result to pass.
typeset -i RESULT=${STF_UNRESOLVED}

# Exit code for individual commands.
typeset -i tmp_rc=0

# Make sure we run as root
if ! /usr/bin/id | grep "uid=0(root)" > /dev/null 2>&1
then
        echo "--DIAG: [$assertion]
        This test must be run from root."
	print_result $RESULT
	exit $RESULT
fi


# Execute environmental sanity checks.
check_gl_env
tmp_rc=$?
if [[ $tmp_rc -ne 0 ]]
then
    echo "--DIAG: [$assertion]
	Invalid smf environment, quitting."
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [${assertion}]
	Call svcadm disable <no arguments>"

svcadm disable >/dev/null 2>&1
ret=$?
if [ $ret -ne 2 ]; then
    RESULT=$(update_result $STF_FAIL $RESULT)
    echo "--DIAG: [$assertion]
	EXPECTED: svcadm disable <no arguments> should exit 2
	ACTUAL: svcadm disable <no arguments> exited with $ret"
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [${assertion}]
	Call svcadm -v disable <no arguments>"

svcadm -v disable >/dev/null 2>&1
ret=$?
if [ $ret -ne 2 ]; then
    RESULT=$(update_result $STF_FAIL $RESULT)
    echo "--DIAG: [$assertion]
	EXPECTED: svcadm -v disable <no arguments> should exit 2
	ACTUAL: svcadm -v disable <no arguments> exited with $ret"
    print_result $RESULT
    exit $RESULT
fi

RESULT=$STF_PASS
print_result $RESULT
exit $RESULT
