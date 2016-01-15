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
# ASSERTION: svccfg_editprop_003
#
# DESCRIPTION:
#	Calling the 'editprop' subcommand with a invalid 
#	value of EDITOR results in a diagnostic message sent 
#	to stderr.  Invalid values of EDITOR are non-existent 
#	commands, non-editor commands.
#
# STRATEGY:
#	Test with the following conditions:
#	#1: The value of EDITOR does not exist
#	#2: The value of EDITOR is not executable
#	#3: EDITOR is null
#
# end __stf_assertion__
###############################################################################


# First STF library
. ${STF_TOOLS}/include/stf.kshlib

# Load GL library
. ${STF_SUITE}/include/gltest.kshlib

# Assertion ID
readonly assertion=svccfg_editprop_003

readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# Initialize test result 
typeset -i RESULT=$STF_PASS

function cleanup {
	
	# Note that $TEST_SERVICE may or may not exist so don't check
	# results.  Just make sure the service is gone.

	service_cleanup ${TEST_SERVICE}
	service_exists ${TEST_SERVICE}
	[[ $? -eq 0 ]] && {
		echo "--DIAG: [${assertion}, cleanup]
		service ${TEST_SERVICE} should not exist in 
		repository after being deleted, but does"

		RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	}

	rm -f $OUTFILE $ERRFILE 

	exit $RESULT
} 

trap cleanup 0 1 2 15

# make sure that the environment is sane - svc.configd is up and running
check_gl_env
[[ $? -ne 0 ]] && {
        echo "--DIAG:
	Invalid test environment - svc.configd not available"

	RESULT=$STF_UNRESOLVED 
	exit $RESULT
}

# Before starting make sure that the test service doesn't already exist.
# If it does then consider it a fatal error.
service_exists $TEST_SERVICE
[[ $? -eq 0 ]] && {
	echo "--DIAG: [${assertion}]
	service $TEST_SERVICE should not exist in repository but does"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}


#
# Add the service.  If this fails consider it a fatal error
#
svccfg add $TEST_SERVICE > $OUTFILE 2>$ERRFILE
ret=$?
[[ $ret -ne 0 ]] && {
	echo "--DIAG: [${assertion}]
	error adding service $TEST_SERVICE needed for test
	error output is $(cat $ERRFILE)"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}


# extract and print assertion information from this source script.
extract_assertion_info $ME

#
# Test #1: not existent file
#

echo "--INFO: Starting $assertion, test 1 (non-existent file)"

typeset -i TEST_RESULT=$STF_PASS

typeset editor_file=/tmp/tmp/foo.$$

[[ -f "$editor_file" ]] && {
	echo "--DIAG: [${assertion}, test 1]
	error - file $editor_file should not exist but does"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}

export EDITOR=$editor_file

cat << EOF >> $CMDFILE
select $TEST_SERVICE
editprop 
EOF

svccfg -f $CMDFILE> $OUTFILE 2>$ERRFILE

# Verify that nothing in stdout - non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}, test 1]
	stdout not expected, but got $(cat $OUTFILE)"

	TEST_RESULT=$STF_FAIL
}

# Verify that message in stderr - non-fatal error
if ! egrep -s "$not_FOUND_ERRMSG" $ERRFILE
then
	echo "--DIAG: [${assertion}, test 1]
	Expected error message \"$not_FOUND_ERRMSG\"
	but got \"$(cat $ERRFILE)\""

	TEST_RESULT=$STF_FAIL
fi

rm -f $ERRFILE $OUTFILE $CMDFILE

print_result $TEST_RESULT
RESULT=$(update_result $TEST_RESULT $RESULT)

#
# Test #2: not existent file

echo "--INFO: Starting $assertion, test 2 (non-executable file)"

typeset -i TEST_RESULT=$STF_PASS

typeset editor_file=/tmp/foo.$$

touch $editor_file > /dev/null 2>&1
chmod a-w $editor_file > /dev/null 2>&1

[[ -x "$editor_file" ]] && {
	echo "--DIAG: [${assertion}, test 2]
	error - file $editor_file is executable, but shouldn't be"

	RESULT=$(update_result $STF_UNRESOLVED $RESULT)
	exit $RESULT
}

export EDITOR=$editor_file

cat << EOF >> $CMDFILE
select $TEST_SERVICE
editprop 
EOF

svccfg -f $CMDFILE> $OUTFILE 2>$ERRFILE

# Verify that nothing in stdout - non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}, test 2]
	stdout not expected, but got $(cat $OUTFILE)"

	TEST_RESULT=$STF_FAIL
}

# Verify that message in stderr - non-fatal error
if ! egrep -s "$CANNOT_EXECUTE_ERRMSG" $ERRFILE
then
	echo "--DIAG: [${assertion}, test 2]
	Expected error message \"$CANNOT_EXECUTE_ERRMSG\"
	but got \"$(cat $ERRFILE)\""

	TEST_RESULT=$STF_FAIL
fi


rm -f $ERRFILE $OUTFILE $CMDFILE

print_result $TEST_RESULT
RESULT=$(update_result $TEST_RESULT $RESULT)

#
# Test #3: null definition
#

echo "--INFO: Starting $assertion, test 3 (null definition)"

typeset -i TEST_RESULT=$STF_PASS


export EDITOR=

cat << EOF >> $CMDFILE
select $TEST_SERVICE
editprop 
EOF

svccfg -f $CMDFILE> $OUTFILE 2>$ERRFILE

# Verify that nothing in stdout - non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}, test 3]
	stdout not expected, but got $(cat $OUTFILE)"

	TEST_RESULT=$STF_FAIL
}

# Verify that message in stderr - non-fatal error
if ! egrep -s "$CANNOT_EXECUTE_ERRMSG" $ERRFILE
then
	echo "--DIAG: [${assertion}, test 3]
	Expected error message \"$CANNOT_EXECUTE_ERRMSG\"
	but got \"$(cat $ERRFILE)\""

	TEST_RESULT=$STF_FAIL
fi


rm -f $ERRFILE $OUTFILE $CMDFILE

print_result $TEST_RESULT
RESULT=$(update_result $TEST_RESULT $RESULT)

exit $RESULT
