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
# ASSERTION: svccfg_import_009
#
# DESCRIPTION:
#	Calling the 'import' subcommand with a valid service manifest 
#	that was previously applied (with the same services and
#	instances) will result in changes to any of the existing
#	repository information, if the override property is set.
#
#
# STRATEGY:
#	This test loads in the a simple .xml file - the same as the basic
#	.xml file in import_001 with one additional property used for 
#	testing this assertion.  The property is a simple astring
#	called "testinfo".  This .xml is imported into the repository.
#	After this the xml file is modified such that the value of
#	the property "testinfo" is changed.  Then the .xml file is
#	imported again.  The assertion is verified by checking that
#	the "testinfo" property had *not* been updated.
#	
# end __stf_assertion__
###############################################################################


# First STF library
. ${STF_TOOLS}/include/stf.kshlib

# Load GL library
. ${STF_SUITE}/include/gltest.kshlib

# Load svc.startd library for manifest_generate
. ${STF_SUITE}/include/svc.startd_config.kshlib

readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# Initialize test result 
typeset -i RESULT=$STF_PASS


function cleanup {
	
	# Note that $TEST_SERVICE may or may not exist so don't check
	# results.  Just make sure the service is gone.

	manifest_purgemd5 $registration_file

	service_cleanup ${TEST_SERVICE}

	service_exists ${TEST_SERVICE}
	[[ $? -eq 0 ]] && {
		echo "--DIAG: [${assertion}, cleanup]
		service ${TEST_SERVICE} should not exist in 
		repository after being deleted, but does"

		RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	}

	rm -f $ERRFILE $OUTFILE $registration_file

	exit $RESULT
}

trap cleanup 0 1 2 15

# make sure that the environment is sane - svc.configd  is up and running
check_gl_env
[[ $? -ne 0 ]] && {
	echo "--DIAG: 
	     	Invalid test environment - svc.configd  not available"

        RESULT=$STF_UNRESOLVED
	exit $RESULT
}

assertion=svccfg_import_009

# extract and print assertion information from this source script.
extract_assertion_info $ME

# Before starting make sure that the test service doesn't already exist.
# If it does then consider it a fatal error.

service_exists $TEST_SERVICE
[[ $? -eq 0 ]] && {
	echo "--DIAG: [${assertion}]
	service $TEST_SERVICE should not exist in
	repository but does"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}

# # Start assertion testing
#

readonly registration_template=$MYLOC/import_009.xml
readonly registration_file=$MYLOC/foo.xml
readonly LOGFILE=/tmp/log.$$
readonly STATEFILE=/tmp/state.$$

manifest_generate $registration_template \
	TEST_SERVICE=$TEST_SERVICE \
	TEST_INSTANCE=$TEST_INSTANCE \
	SERVICE_APP=$SERVICE_APP  \
 	LOGFILE=$LOGFILE \
	STATEFILE=$STATEFILE | sed 's/TESTDATA/first/' | sed 's/OVERRIDE_VALUE/true/' >$registration_file


manifest_purgemd5 $registration_file

svccfg  import $registration_file > $OUTFILE 2>$ERRFILE
ret=$?

[[ $ret -ne 0 ]] &&  {
	echo "--DIAG: [${assertion}]
	svccfg import expected to return 0, got $ret"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}

service_exists $TEST_SERVICE
[[ $? -ne 0 ]] && {
       	echo "--DIAG: [${assertion}]
	service $TEST_SERVICE should exist in repository but does not"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}


prop_value_1=$(svcprop -p cfg/testinfo $TEST_SERVICE:$TEST_INSTANCE)
[[ "${prop_value_1}" != "first" ]] && {
       	echo "--DIAG: [${assertion}]
	cfg/testinfo property value is ${prop_value_1}, expected first"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}


# create a manifest with all the same data EXCEPT the value of one
# property should be different
manifest_generate $registration_template \
	TEST_SERVICE=$TEST_SERVICE \
	TEST_INSTANCE=$TEST_INSTANCE \
	SERVICE_APP=$SERVICE_APP  \
 	LOGFILE=$LOGFILE \
	STATEFILE=$STATEFILE | sed 's/TESTDATA/second/' | sed 's/OVERRIDE_VALUE/true/' >$registration_file

# Try to import the file again 
svccfg  import $registration_file > $OUTFILE 2>$ERRFILE
ret=$?
[[ $ret -ne 0 ]] &&  {
	echo "--DIAG: [${assertion}]
	svccfg import expected to return 0, got $ret"

	RESULT=$STF_FAIL
}

# Verify that nothing in stdout - this is a non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}]
	stdout not expected, but got $(cat $OUTFILE)"

	RESULT=$STF_FAIL
}

# Verify that nothing in sterr - this is a non-fatal error
[[ -s $ERRFILE ]] &&  {
	echo "--DIAG: [${assertion}]
	stderr not expected, but got $(cat $ERRFILE)"

	RESULT=$STF_FAIL
}



prop_value_2=$(svcprop -p cfg/testinfo $TEST_SERVICE:$TEST_INSTANCE)
[[ "${prop_value_2}" != "second" ]] && {
       	echo "--DIAG: [${assertion}]
	cfg/testinfo updated property value is ${prop_value_2}, expected second"

	RESULT=$STF_FAIL
}

rm -f $ERRFILE $OUTFILE /tmp/export.$$.?
exit $RESULT