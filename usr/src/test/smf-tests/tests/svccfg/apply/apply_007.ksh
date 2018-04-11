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
# ASSERTION: svccfg_apply_007
#
# DESCRIPTION:
#	Calling the 'apply' subcommand where the file is a invalid
#	service profile will result in a diagnostic message
#	displayed on stderr.  The exit status will be 1.
# 
# STRATEGY:
#	This is a simple test passing to import a .xml file with an
#	error (i.e. an invalid service profile).  
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
	
	rm -f $OUTFILE $ERRFILE 

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

assertion=svccfg_apply_007
readonly registration_file=$MYLOC/apply_007_profile.xml

# extract and print assertion information from this source script.
extract_assertion_info $ME

svccfg import $registration_file > $OUTFILE 2>$ERRFILE
ret=$?
[[ $ret -ne 1 ]] &&  {
	echo "--DIAG: [${assertion}]
	svccfg import expected to return 1, got $ret"

	RESULT=$STF_FAIL
}

# Verify that nothing in stdout - this is a non-fatal error
[[ -s $OUTFILE ]] &&  {
	echo "--DIAG: [${assertion}]
	stdout not expected, but got $(cat $OUTFILE)"

	RESULT=$STF_FAIL
}

# Verify that a message is sent to stderr
if ! egrep -s "$UNPARSEABLE_ERRMSG" $ERRFILE
then
	echo "--DIAG: [${assertion}]
	Expected error message \"$UNPARSEABLE_ERRMSG\"
	but got \"$(cat $ERRFILE)\""

	RESULT=$STF_FAIL
fi


rm -f $ERRFILE $OUTFILE

exit $RESULT
