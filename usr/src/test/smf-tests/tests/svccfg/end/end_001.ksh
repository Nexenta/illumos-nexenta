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
# ASSERTION: svccfg_end_001
#
# DESCRIPTION:
#	The subcommand "end" causes svccfg to end processing and exit.
# 	If no errors were encountered during processing, the exit status
# 	is zero.
#
# STRATEGY:
#	Write a simple svccfg script which calls end and then does
#	a list subcommand.  Make sure that the list subcommand isn't
#	executed.
#
# end __stf_assertion__
###############################################################################

# First STF library
. ${STF_TOOLS}/include/stf.kshlib

# Load GL library
. ${STF_SUITE}/include/gltest.kshlib


readonly ME=$(whence -p ${0})
readonly MYLOC=$(dirname ${ME})

# Initialize test result 
typeset -i RESULT=$STF_PASS


function cleanup {
	
	rm -f $OUTFILE $ERRFILE $CMDFILE

	exit $RESULT
}

trap cleanup 0 1 2 15

# make sure that the environment is sane - svc.configd is up and running
check_gl_env
[[ $? -ne 0 ]] && {
	echo "--DIAG: 
	Invalid test environment -svc.configd not available"

	RESULT=$STF_UNRESOLVED
	exit $RESULT
}

# extract and print assertion information from this source script.
extract_assertion_info $ME

assertion=svccfg_end_001

cat <<EOF >>$CMDFILE
end
list
EOF


svccfg -f $CMDFILE > $OUTFILE 2>$ERRFILE
ret=$?

# Verify that the return value is as expected - non-fatal error
[[ $ret -ne 0 ]] &&  {
	echo "--DIAG: [${assertion}, test 1]
	svccfg expected to return 0, got $ret"

	RESULT=$STF_FAIL
}

# Verify that nothing in stdout - non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}, test 1]
	stdout not expected, but got $(cat $OUTFILE)"

	RESULT=$STF_FAIL
}

# Verify that nothing in stderr - non-fatal error
[[ -s $ERRFILE ]] &&  {
	echo "--DIAG: [${assertion}, test 1]
	stderr not expected, but got $(cat $ERRFILE)"

	RESULT=$STF_FAIL
}

	
rm -f $ERRFILE $OUTFILE $CMDFILE

print_result $RESULT

