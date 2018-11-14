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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

###############################################################################
# start __stf_assertion__
#
# ASSERTION: svcadm_refresh_007
#
# DESCRIPTION:
#	Calling 'svcadm refresh <service>, where service
#	has multiple instances	should pass and exit 0.
# STRATEGY:
#	- Check for test setup.
#	- Configure a service 'foo$$' using svccfg
#	- Attempt to put multiple instances to the service.
#	- Now attempt to put them in refresh mode.
#	- Make sure svcadm for refresh <service> passes with
#		exit 0.
#
# COMMANDS: svcadm(1)
#
# end __stf_assertion__
################################################################################

# First load up definitions of STF result variables like STF_PASS etc.
. ${STF_TOOLS}/include/stf.kshlib

# Load up definitions of shell functionality common to all smf sub-suites.
. ${STF_SUITE}/include/gltest.kshlib

# Load up the functions for the tests in this directory
. ${STF_SUITE}/${STF_EXEC}/functions.kshlib

# Define the cleanup function for this test
function cleanup {
	cleanup_leftovers $service_test $svccfg_add_script
	print_result $RESULT
}

# Define Variables
readonly assertion=svcadm_refresh_007
readonly svccfg_add_script=/var/tmp/svcadm_refresh_007.$$.config
readonly service_test=foo$$
readonly instance_test=instance$$
readonly instance_test1=instance1$$
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# Extract and print the assertion from this source script.
extract_assertion_info $ME

# Initialize test result to pass.
typeset -i RESULT=${STF_UNRESOLVED}

# Set a trap to execute the cleanup function when specified signals
# are received.
trap cleanup 0 1 2 15

# Exit code for individual commands.
typeset -i tmp_rc=0

# Make sure we run as root
if ! /usr/bin/id | grep "uid=0(root)" > /dev/null 2>&1
then
        echo "--DIAG: [$assertion]
        This test must be run from root."
	exit $RESULT
fi


# Execute environmental sanity checks.
check_gl_env
tmp_rc=$?
if [[ $tmp_rc -ne 0 ]]
then
	echo "--DIAG: [$assertion]
	Invalid smf environment, quitting."
	exit $RESULT
fi

# Local 'return code' variable
typeset -i rc=0

# Create the svccfg add script which will add entities to the
# repository for this test case.

echo "--INFO: [${assertion}]
	configure $service_test using svccfg"

cat > $svccfg_add_script <<EOF
add $service_test
select $service_test
add $instance_test
add $instance_test1
EOF

#Add objects to repository

echo "--INFO: [${assertion}]
	Adding entities <$service_test> to repository using svccfg"

/usr/sbin/svccfg -f $svccfg_add_script >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
	echo "--DIAG: [$assertion]
	Adding entities using svccfg failed.
	EXPECTED: svccfg exit status 0
	RETURNED: svccfg exit status $rc"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	enable <$service_test:$instance_test> using svcadm"

#Enable the service using svcadm
/usr/sbin/svcadm enable $service_test:$instance_test >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
	echo "--DIAG: [$assertion]
	svcadm enable $service_test:$instance_test failed.
	EXPECTED: exit 0
	RETURNED: exit $rc"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	enable <$service_test:$instance_test1> using svcadm"

#Enable the service using svcadm
/usr/sbin/svcadm enable $service_test:$instance_test1 >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
	echo "--DIAG: [$assertion]
	svcadm enable $service_test:$instance_test1 failed.
	EXPECTED: exit 0
	RETURNED: exit $rc"
	exit $RESULT
fi

#Wait just for sometime, let the service STATE gets updated

echo "--INFO: [${assertion}]
	Wait for sometime to state transition gets completed"

service_wait_state $service_test:$instance_test online
rc=$?
if [ $rc -ne 0 ]; then
	echo "--DIAG: [$assertion]
	<$service_test:$instance_test> is not online"
	exit $RESULT
fi

service_wait_state $service_test:$instance_test1 online
rc=$?
if [ $rc -ne 0 ]; then
	echo "--DIAG: [$assertion]
	<$service_test:$instance_test1> is not online"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Now attempt to refresh "

#Enable the service using svcadm
/usr/sbin/svcadm refresh $service_test >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	svcadm refresh $service_test should pass
	EXPECTED: exit 0
	RETURNED: exit $rc"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Assertion proved"

RESULT=$STF_PASS
print_result $RESULT
exit $RESULT

#
### END
#
