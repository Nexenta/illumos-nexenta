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
# ASSERTION: svcadm_disable_002
#
# DESCRIPTION:
#	Calling  'svcadm -v disable FMRI' where FMRI is a service instance
#	that is already in the disabled state will have no effect on the
#	service. A message will be sent to stdout and the exit status will
#	be 0.
# STRATEGY:
#	- Check for test setup.
#	- Configure a service 'foo$$' using svccfg
#	- Enable it using svcadm
#	- Disable it using "svcadm disable service"
#	- Using svcprop make sure 'foo$$' has STATE disabled
#	- Again attempt to disable it using "svcadm -v disable service"
#	- Make sure exit status is 0.
#	- Also verify 'stdout message' saying "$service already disabled"
#
# COMMANDS: svcadm(1)
#
# end __stf_assertion__
################################################################################

# First load up definitions of STF result variables like STF_PASS etc.
. ${STF_TOOLS}/include/stf.kshlib

# Load up definitions of shell functionality common to all smf sub-suites.
. ${STF_SUITE}/include/gltest.kshlib

# Define the cleanup function for this test
function cleanup {
	service_cleanup $service_test
	/usr/bin/rm -f $svccfg_add_script
	print_result $RESULT
}

# Define Variables
readonly assertion=svcadm_disable_002
readonly svccfg_add_script=/var/tmp/svcadm_disable_002.$$.config
readonly service_test=foo$$
readonly instance_test=instance$$
readonly target_fmri="svc:/${service_test}:${instance_test}"
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# gltest.kshlib functions to extract and print assertion information
# from this source script.
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

# Create the svccfg add script which will add entities to the
# repository for this test case.

echo "--INFO: [${assertion}]
	configure $service_test using svccfg"

cat > $svccfg_add_script <<EOF
add $service_test
select $service_test
add $instance_test
EOF

#Add objects to repository

echo "--INFO: [${assertion}]
	Add entities to repository using svccfg
		<$service_test>
		<${service_test}:${instance_test}>"

/usr/sbin/svccfg -f $svccfg_add_script >/dev/null 2>&1
ret=$?
if [ $ret -ne 0 ]; then
	echo "--DIAG: [$assertion]
	Adding entities using svccfg failed.
	EXPECTED: ret = 0
	OBSERVED: ret = $ret"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	enable <$service_test> using svcadm"

# Enable the service using svcadm
svcadm enable $service_test >/dev/null 2>&1
ret=$?
if [ $ret -ne 0 ]; then
	echo "--DIAG: [$assertion]
	svcadm enable $service_test failed.
	EXPECTED: ret = 0
	OBSERVED: ret = $ret"
	exit $RESULT
fi

# Wait until the service state transition is complete
echo "--INFO: [${assertion}]
	Wait until state transition gets completed"

service_wait_state $target_fmri online
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	<$target_fmri> is not online"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	disable $service_test using svcadm"

# Disable the service using svcadm
svcadm disable $service_test >/dev/null 2>&1
ret=$?
if [ $ret -ne 0 ]; then
	echo "--DIAG: [$assertion]
	svcadm disable $service_test failed.
	EXPECTED: ret = 0
	OBSERVED: ret = $ret"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Wait until state transition gets completed"

service_wait_state $target_fmri disabled
if [ $? -ne 0 ]; then
	state=`svcprop -p restarter/state $target_fmri 2>/dev/null`
	echo "--DIAG: [$assertion]
	EXPECTED: STATE= disabled
	OBSERVED: STATE = $state"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	VERIFY ASSERTION: attempt to disable again"

output=`svcadm -v disable $service_test 2>/dev/null` 
ret=$?
exp_out="$target_fmri disabled."
if [[ $ret -ne 0 || "$output" != "$exp_out" ]]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	svcadm -v disable $service_test (already disabled) failed.
	EXPECTED: ret = 0; output: $exp_out
	OBSERVED: ret = $ret and output: = $output"
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