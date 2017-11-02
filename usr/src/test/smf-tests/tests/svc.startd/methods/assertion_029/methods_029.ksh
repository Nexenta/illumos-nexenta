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

#
# start __stf_assertion__
#
# ASSERTION: methods_029
# DESCRIPTION:
#  Service with a single sub-process.
#  If a service instance in the degraded state dies due to a hwerr
#  then the svc.startd should attempt to restart the service.
#
# end __stf_assertion__
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/gltest.kshlib
. ${STF_SUITE}/include/svc.startd_config.kshlib
. ${STF_SUITE}/tests/include/svc.startd_fileops.kshlib
. ${STF_SUITE}/tests/svc.startd/include/svc.startd_common.kshlib

typeset service_setup=0
function cleanup {
	common_cleanup
}

trap cleanup 0 1 2 15

readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

DATA=$MYLOC

registration_template=$DATA/service_029.xml

extract_assertion_info $ME

# make sure that the svc.startd is running
verify_daemon
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: svc.startd is not executing. Cannot "
	print -- "  continue"
	exit $STF_UNRESOLVED
fi

# feature testing
features=`feature_test MTST`
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: $features missing from startd"
	exit $STF_UNTESTED
fi

# Make sure the environment is clean - the test service isn't running
print -- "--INFO: Cleanup any old $test_FMRI state"
service_cleanup $test_service
rm -f $service_state
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: unable to clean up any pre-existing state"
	exit $STF_UNRESOLVED
fi

print -- "--INFO: generating manifest for importation into repository"
manifest_generate $registration_template \
	TEST_SERVICE=$test_service \
	TEST_INSTANCE=$test_instance \
	SERVICE_APP=$service_app \
	LOGFILE=$service_log \
	STATEFILE=$service_state \
	MONITOR_RESULT="returncode $SVC_DEGRADED" \
	> $registration_file

print -- "--INFO: Importing service into repository"
manifest_purgemd5 $registration_file
svccfg -v import $registration_file >$svccfg_errfile 2>&1
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: Unable to import the service $test_FMRI"
	print -- "  error messages from svccfg: \"$(cat $svccfg_errfile)\""
	exit $STF_UNRESOLVED
fi
service_setup=1

print -- "--INFO: enabling $test_FMRI"
svcadm enable $test_FMRI
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: enable command of $test_FMRI failed"
	exit $STF_FAIL
fi

print -- "--INFO: waiting for execution of start method"
service_wait_method $test_FMRI start
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: Service $test_FMRI didn't issue start"
	exit $STF_UNRESOLVED
fi

print -- "--INFO: sending service to degraded state"
svcadm mark degraded $test_FMRI
if [ $? -ne 0 ]; then
	print -- "--DIAG: Could not send service $test_FMRI to degraded"
	exit $STF_FAIL
fi

print -- "--INFO: Validating service reaches degraded mode"
service_wait_state $test_FMRI degraded
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: Service $test_FMRI didn't"
	print -- "  transition to degraded mode"
	exit $STF_FAIL
fi

PIDS=`service_getpids -s $test_service -i $test_instance -f $service_state`
print -- "--INFO: child pids are: $PIDS"

# pad run log
$service_app -s $test_service -i $test_instance -l $service_log -m "blank"

print -- "--INFO: issue a hwerr to the service"
$service_app -s $test_service -i $test_instance -l $service_log -m "trigger" \
	-r "forkexec 0 mtst udue"

print -- "--INFO: Waiting for service's start method"
service_wait_method $test_FMRI start
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: didn't issue start method"
	exit $STF_FAIL
fi

print -- "--INFO: Waiting for service to reach degraded state"
service_wait_state $test_FMRI degraded
if [ $? -ne 0 ]; then
	print -- "--DIAG: $assertion: service $test_FMRI didn't"
        print -- "  go to degraded"
	exit $STF_FAIL
fi

print -- "--INFO: Cleaning up service"
cleanup

exit $STF_PASS