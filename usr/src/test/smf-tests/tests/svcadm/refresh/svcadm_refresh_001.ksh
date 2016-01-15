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
# ASSERTION: svcadm_refresh_001
#
# DESCRIPTION:
#	Calling 'svcadm refresh FMRI' over FMRI currently in enabled state
#	should not stop (or) start the service(s)/process(es) associated
#	with those services.
# STRATEGY:
#	- locate for template.xml in $STF_SUITE/tests/svcadm/
#	- Create a simple start method
#	- Generate say 'svcadm_refresh_001.$$.xml' using template.xml 
#	- Import the xml using svccfg import <.xml>
#	- Wait until test_service loads start_process.
#	- Call svcadm refresh <FMRI>.
#	- Make sure above step exits 0.
#
# COMMANDS: svcadm(1)
#
# end __stf_assertion__
################################################################################

# First load up definitions of STF result variables like STF_PASS etc.
. ${STF_TOOLS}/include/stf.kshlib

# Load up definitions of shell functionality common to all smf sub-suites.
. ${STF_SUITE}/include/gltest.kshlib
. ${STF_SUITE}/include/svc.startd_config.kshlib

# Load up the common utility functions for tests in this directory
. ${STF_SUITE}/${STF_EXEC}/functions.kshlib

# Define the cleanup function for this test
function cleanup {
	pkill -z $(zonename) -f $start_process
	pkill -z $(zonename) -f $refresh_test_process
	cleanup_leftovers $refesh_test_service $registration_file \
		$start_process $start_file /var/tmp/$rfrsh.$$
	print_result $RESULT
}

# Define Variables
readonly assertion=svcadm_refresh_001
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})
readonly registration_template=${STF_SUITE}/tests/svcadm/refresh/template.xml
readonly registration_file=/var/tmp/svcadm_refresh_001.$$.xml
readonly refresh_test_service="refresh_001$$"
readonly refresh_test_instance="refresh_001$$"
readonly start_process=/var/tmp/refresh_001.$$.start
readonly start_file=/var/tmp/svcadm_refresh_001.startfile.$$
readonly refresh_test_process_name="rfrsh_001"
readonly refresh_test_process=/var/tmp/${refresh_test_process_name}.$$
readonly refresh_test_fmri="svc:/$refresh_test_service:$refresh_test_instance"
typeset -i pid=0

# Make sure we run as root
if ! /usr/bin/id | grep "uid=0(root)" > /dev/null 2>&1
then
	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	echo "--DIAG: [$assertion]
	This test must be run from root."
	exit $RESULT
fi

# Extract and print the assertion from this source script.
extract_assertion_info $ME

# Initialize test result to pass.
typeset -i RESULT=${STF_UNRESOLVED}

# Set a trap to execute the cleanup function
trap cleanup 0 1 2 15

# Exit code for individual commands.
typeset -i tmp_rc=0

# Execute environmental sanity checks.
check_gl_env
tmp_rc=$?
if [[ $tmp_rc -ne 0 ]]
then
	echo "--DIAG: [$assertion]
	Invalid smf environment, quitting."
	exit $RESULT
fi

set -x
# Kill any running instances of start_process and refresh_test_process_name
pkill -z $(zonename) -f $start_process
pkill -z $(zonename) -f $refresh_test_process_name

echo "--INFO: [$assertion]
	Verify that registration template $registration_template exists"

if [ ! -s $registration_template ]; then
	echo "--DIAG: [$assertion]
	$registration_template not found"
	exit $RESULT
fi

echo "--INFO: [$assertion]
	Create test start method: $start_process"

cat > $start_process <<-EOF
#!/bin/ksh -p
/bin/cp /dev/null $start_file >/dev/null 2>&1
cat > $refresh_test_process <<-EOT
#!/bin/ksh -p
while :; do echo "1" > /dev/null; done
exit 0
EOT
chmod +x $refresh_test_process
$refresh_test_process &
exit 0
EOF

echo "--INFO: [$assertion]
	chmod 755 $start_process"

chmod 755 $start_process
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	chmod 755 $start_process failed"
	exit $RESULT
fi

echo "--INFO: [$assertion]
	Generate .xml required for this test"

manifest_generate $registration_template \
	TEST_SERVICE=$refresh_test_service \
	TEST_INSTANCE=$refresh_test_instance \
	START_NAME=$start_process \
	STOP_NAME=":kill" \
	SERVICE_APP=$service_app \
	STATEFILE=$service_state > $registration_file

echo "--INFO: [$assertion]
	Verify the registration template was created and size > 0 bytes"

if [ ! -s $registration_file ]; then
	echo "--DIAG: [$assertion]
	$registration_file does not exist or has size = 0 bytes"
	exit $RESULT
fi

echo "--INFO: [$assertion]
	Import the service to repository using svccfg import"

svccfg import $registration_file > $svccfg_errfile 2>&1
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	Unable to import the service $refresh_test_service
	error messages from svccfg: \"$(cat $svccfg_errfile)\""
	exit $RESULT
fi

echo "--INFO: [$assertion]
	Imported FMRI is: $refresh_test_fmri"

# Import should automatically enable the service
echo "--INFO: [$assertion]
	Wait until $start_process is triggered"

wait_process_start 2>/dev/null
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	$start_process was not triggered upon import"
	exit $RESULT
fi

pid=`pgrep -f ${refresh_test_process_name}`
if [[ $? -ne 0 || -z $pid ]]; then
	echo "--DIAG: [$assertion]
	Could not determine pid of $start_process"
	exit $RESULT
fi

echo "--INFO: [$assertion]
	svcs -p <FMRI> and make sure pid $pid is printed"
output="`svcs -p $refresh_test_fmri | grep -w $pid | \
	awk '{ print $2 }' 2>/dev/null`"
if [[ $? -ne 0 ]] || [[ "$output" != "$pid" ]]; then
	echo "--DIAG: [$assertion]
	svcs -p $refresh_test_fmri | grep $pid | awk '{ print \$2 }' failed
	EXPECTED: output = $pid
	OBSERVED: output = $output"
	exit $RESULT
fi

#
# VERIFY ASSERTION
#
echo "--INFO: [${assertion}]
	refresh <$refresh_test_fmri> using svcadm"

svcadm refresh $refresh_test_fmri >/dev/null 2>&1
ret=$?
if [ $ret -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
		svcadm refresh $refresh_test_fmri fails
	EXPECTED: ret = 0
	OBSERVED: ret = $ret"
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Make sure process is still running with pid $pid"

svcs -p $refresh_test_fmri | grep -w $pid >/dev/null 2>&1
if [ $? -ne 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
	EXPECTED: process with pid $pid exists on system
	OBSERVED: no process with pid $pid is running"
	exit $RESULT
fi

# Disable the test instance
echo "--INFO: [$assertion]
	Disable $test_fmri"
svcadm disable $refresh_test_fmri >/dev/null 2>&1
ret=$?
if [ $ret -ne 0 ]; then
	echo "--DIAG: [$assertion]
	svcadm disable $refresh_test_fmri failed
	EXPECTED: ret = 0
	OBSERVED: ret = $ret"
fi

# Cleanup will be called upon exit

RESULT=$STF_PASS
print_result $RESULT
exit $RESULT

#
### END
#
