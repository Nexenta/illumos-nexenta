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
# ASSERTION: depends_011
# DESCRIPTION:
#  A service with a single dependency in an "exclude_all" grouping
#  set in the service's definition. If any of the dependencies 
#  come online then the service will be transitioned into the offline
#  state.
#  Services: a, b; b specifies exclude_all of (a)
#
# end __stf_assertion__
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/gltest.kshlib
. ${STF_SUITE}/include/svc.startd_config.kshlib
. ${STF_SUITE}/tests/svc.startd/include/svc.startd_common.kshlib

typeset service_setup=0
function cleanup {
	common_cleanup
	rm -f $service_state1 $service_state2
}

trap cleanup 0 1 2 15

readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

DATA=$MYLOC

readonly registration_template=$DATA/service_011.xml

extract_assertion_info $ME

# make sure that the svc.startd is running
verify_daemon
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: svc.startd is not executing. Cannot "
	echo "  continue"
	exit $STF_UNRESOLVED
fi

# Make sure the environment is clean - the test service isn't running
echo "--INFO: Cleanup any old $test_FMRI1, $test_FMRI2 state"
service_cleanup $test_service
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: cleanup of a previous instance failed"
	exit $STF_UNRESOLVED
fi

echo "--INFO: generating manifest for importation into repository"
manifest_generate $registration_template \
	TEST_SERVICE=$test_service \
	TEST_INSTANCE1=$test_instance1 \
	TEST_INSTANCE2=$test_instance2 \
	SERVICE_APP=$service_app \
	LOGFILE=$service_log \
	STATEFILE1=$service_state1 \
	STATEFILE2=$service_state2 > $registration_file

echo "--INFO: Importing service into repository"
manifest_purgemd5 $registration_file
svccfg -v import $registration_file >$svccfg_errfile 2>&1

if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Unable to import the services $test_FMRI1"
        echo "  and $test_FMRI2 error messages from svccfg: "
        echo "  \"$(cat $svccfg_errfile)\""
	exit $STF_UNRESOLVED
fi
service_setup=1

echo "--INFO: Wait for $test_FMRI1 to come online"
service_wait_state $test_FMRI1 online
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 didn't come online"
	echo "  services state:"
	svcs -l $test_service\*
	exit $STF_FAIL
fi

echo "--INFO: Enabling service $test_FMRI2"
svcadm enable $test_FMRI2
if [ $? -ne 0 ]; then
        echo "--DIAG: $assertion: Service $test_FMRI2 did not enable"
        exit $STF_FAIL
fi

echo "--INFO: Waiting for $test_FMRI2 to come online - it should not"
service_wait_state $test_FMRI2 online
if [ $? -eq 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI2 came online"
	echo "  services state:"
	svcs -l $test_service\*
	exit $STF_FAIL
fi

echo "--INFO: Disabling $test_FMRI1"
svcadm disable $test_FMRI1
if [ $? -ne 0 ]; then
        echo "--DIAG: $assertion: Service $test_FMRI1 did not disable"
        exit $STF_FAIL
fi

echo "--INFO: Verifying that $test_FMRI1 goes to disabled"
service_wait_state $test_FMRI1 disabled
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 didn't go to disabled"
	exit $STF_FAIL
fi

echo "--INFO: Waiting for $test_FMRI2 to come online"
service_wait_state $test_FMRI2 online
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI2 did not come online"
	echo "  services state:"
	svcs -l $test_service\*
	exit $STF_FAIL
fi

echo "--INFO: Enabling service $test_FMRI1"
svcadm enable $test_FMRI1
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 wouldn't enable"
	exit $STF_FAIL
fi

echo "--INFO: Wait for $test_FMRI1 to come online"
service_wait_state $test_FMRI1 online
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 didn't come online"
	exit $STF_FAIL
fi

echo "--INFO: Verify that $test_FMRI2 goes offline"
service_wait_state $test_FMRI2 offline
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 didn't go offline"
	echo "  services state:"
	svcs -l $test_service\*
	exit $STF_FAIL
fi

echo "--INFO: Disabling $test_FMRI1"
svcadm disable $test_FMRI1
if [ $? -ne 0 ]; then
        echo "--DIAG: $assertion: Service $test_FMRI1 did not disable"
        exit $STF_FAIL
fi

echo "--INFO: Verifying that $test_FMRI1 goes to disabled"
service_wait_state $test_FMRI1 disabled
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI1 didn't go to disabled"
	exit $STF_FAIL
fi

echo "--INFO: Waiting for $test_FMRI2 to come online"
service_wait_state $test_FMRI2 online
if [ $? -ne 0 ]; then
	echo "--DIAG: $assertion: Service $test_FMRI2 did not come online"
	echo "  services state:"
	svcs -l $test_service\*
	exit $STF_FAIL
fi

echo "--INFO: Cleaning up service"
cleanup

exit $STF_PASS