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

#This function is to cleanup the leftovers by this test

function wait_process_start {
	count=0
	while [ $count -lt 10 ]; do
		echo "--INFO: [$assertion]
			Verify if testfoo.$$ is loaded and started"

		pid=`pgrep -z $(zonename) -f testfoo.$$` 
		if [[ $? -eq 0 && ! -z $pid ]]; then
			return 0
		else
			sleep 1
		fi
		count=`expr $count + 1`
	done

	#If test process not started by service in given time
	#then fail and return 1

	if [ $count -eq 10 ]; then
			return 1
	fi
}

function cleanup {
	kill -9 $pid
	service_cleanup $test_service
	/usr/bin/rm -f /var/tmp/$test_process

	/usr/bin/rm -f $registration_file
	/usr/bin/rm -f /var/tmp/testfoo.$$
	/usr/bin/rm -f /var/tmp/$test_process

}

###############################################################################
# start __stf_assertion__
#
# ASSERTION: svcadm_disable_004
#
# DESCRIPTION:
#	Calling 'svcadm -v disable FMRI' where FMRI is a service instance
#	that is in the enabled state will result in the service being stopped
#	and being transitioned into disabled state. A message will be sent to
#	stdout and the exit status will be 0.
# STRATEGY:
#	- locate for template.xml in $STF_SUITE/tests/svcadm/
#	- Create a simple test_process that sleeps for may be 10 secs.
#	- Generate say 'svcadm_disable_004.$$.xml' using template.xml 
#		which contains say service='test_service', 
#		instance='test_instance'
#		execname='test_process' for both start and stop event.
#	- Import the xml using svccfg import <.xml>
#	- Wait until test_service loads test_process.
#	- Now attempt to disable the service.
#	- Make sure svcadm -v disable <service> is successful with exit 0.
#	- Also verify that "$service disabled verbose message is printed"
#	- Wait for the transition period from enable to disable.
#	- Also verify that 'test_process' is no more running it is STOPPED.
#	- Make sure now 'service' state is disabled.
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

# Define Variables
readonly assertion=svcadm_disable_004
readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})
readonly registration_template=${STF_SUITE}/tests/svcadm/disable/template.xml
readonly registration_file=/var/tmp/svcadm_disable_004.$$.xml
readonly test_service="disable_004$$"
readonly test_instance="disable_004$$"
readonly test_process=disable_004.$$
pid=""

# Make sure we run as root
if ! /usr/bin/id | grep "uid=0(root)" > /dev/null 2>&1
then
	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	echo "--DIAG: [$assertion]
	This test must be run from root."
	print_result $RESULT
	exit $RESULT
fi

# gltest.kshlib functions to extract and print assertion information
# from this source script.
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
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [$assertion]
	Verify if required template is located"

if [ ! -s $registration_template ]; then
    echo "--DIAG: [$assertion]
	$registration_template is not located"
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [$assertion]
	Create a test process in /var/tmp/$test_process"

cat > /var/tmp/$test_process << EOF
#!/bin/ksh -p
print "#!/bin/ksh -p" > /var/tmp/testfoo.$$
print "sleep 1000" >> /var/tmp/testfoo.$$
print "exit 0" >> /var/tmp/testfoo.$$
chmod 755 /var/tmp/testfoo.$$
/var/tmp/testfoo.$$ &
exit 0
EOF

echo "--INFO: [$assertion]
	chmod 755 /var/tmp/$test_process"

chmod 755 /var/tmp/$test_process
if [ $? -ne 0 ]; then
    echo "--DIAG: [$assertion]
	chmod 755 /var/tmp/$test_process failed"
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [$assertion]
	Generate .xml required for this test  using given template.xml"

manifest_generate $registration_template \
	TEST_SERVICE=$test_service \
	TEST_INSTANCE=$test_instance \
	EXEC_NAME=/var/tmp/$test_process \
	STOP_NAME=":kill" \
	SERVICE_APP=$service_app \
	STATEFILE=$service_state > $registration_file

echo "--INFO: [$assertion]
	Verify if registration template is located and size > 0 bytes"

if [ ! -s $registration_file ]; then
    echo "--DIAG: [$assertion]
	$registration_file is not located"
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [$assertion]
	Import the service to repository using svccfg import"

svccfg import $registration_file > $svccfg_errfile 2>&1
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: Unable to import the service $test_FMRI"
	print -- "  error messages from svccfg: \"$(cat $svccfg_errfile)\""
	exit $STF_UNRESOLVED
fi

echo "--INFO: [$assertion]
	Wait until the testfoo.$$ is loaded by $test_service"

#This function sets variable 'pid'

wait_process_start 2>/dev/null
if [ $? -ne 0 ]; then
    echo "--DIAG: [$assertion]
	testfoo.$$ not started by svccfg -v import $registration_file"
    print_result $RESULT
    exit $RESULT
fi

echo "--INFO: [$assertion]
	svcs -Hp <FMRI> and make sure $pid is printed"
output=`svcs -p svc:/$test_service:$test_instance | grep -w $pid | \
	awk '{print $2}' 2>/dev/null`
if [[ $? -ne 0 || "$output" != "$pid" ]]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
		svcs -Hp $test_service:$test_instance | grep testfoo.$$ fails
	EXPECTED: output = $pid
	ACTUAL: output = $output"
	print_result $RESULT
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	disable <$test_service> using svcadm"

output=`svcadm -v disable svc:/$test_service:$test_instance 2>/dev/null`
ret=$?
if [[ $ret -ne 0 || \
	$output != "svc:/$test_service:$test_instance disabled." ]]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
		svcadm disable svc:/$test_service:$test_instance fails
	EXPECTED: output = ret 0;  and 
		message = svc:/$test_service:$test_instance disabled.
	ACTUAL: output ret = $ret message = $output"
	print_result $RESULT
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Just wait for sometime to STATE gets updated"

service_wait_state $test_service:$test_instance disabled
if [ $? -ne 0 ]; then
	echo "--DIAG: [$assertion]
	<$service_test> is not disabled"
	print_result $RESULT
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Make sure svcs -Hp $test_service doesn't print $pid"

svcs -Hp svc:/$test_service:$test_instance | grep -w $pid >/dev/null 2>&1
if [ $? -eq 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
		svcs -Hp svc:/$test_service:$test_instance | grep $pid should
		fail; It means svcs -Hp shouldn't print process info as the
		process is dead"
	print_result $RESULT
	exit $RESULT
fi

echo "--INFO: [${assertion}]
	Make sure process is really dead using ps"

ps -ef -z $(zonename) | grep -w $pid | grep -v grep >/dev/null 2>&1
if [ $? -eq 0 ]; then
	RESULT=$(update_result $STF_FAIL $RESULT)
	echo "--DIAG: [$assertion]
		ps -ef -z $(zonename) | grep $pid should fail"
	print_result $RESULT
	exit $RESULT
fi

RESULT=$STF_PASS
print_result $RESULT
exit $RESULT

