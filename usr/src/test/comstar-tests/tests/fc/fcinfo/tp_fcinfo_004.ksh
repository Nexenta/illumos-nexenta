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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
###############################################################
# tests run by this program are:
#
#  This routine tests help functions and target mode supported 
#  subocmmands and options
#
###############################################################
# __stc_assertion_start
# 
# ID: fcinfo_comstar_004
# 
# DESCRIPTION:
# 	Runs help and -? options for fcinfo. 
#         - fcinfo --help
#         - fcinfo -?
#         - fcinfo hba-port --help
#         - fcinfo hba-port -?
#         - fcinfo remote-port --help
#         - fcinfo remote-port -?
# 
# STRATEGY:
# 
# 	Setup:
# 	    None
# 	Test:
# 	    Verify the return code of each command listed below.
# 	Cleanup:
# 	    None
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 	fcinfo hba-port remote-port
# 
# TESTABILITY: explicit
# 
# AUTHOR: hyon.kim@sun.com
# 
# REVIEWERS: <e-mail, e-mail>
# 	
# 
# ASSERTION_SOURCE:
# 
# 	// Optional field - a pointer to the document source of the assertion
# 
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS
# 
# __stc_assertion_end
function fcinfo_help_cmds
{
    typeset return_code=0
    typeset re_code=0

    ###############################################################
    # test help options.  Failure will be recorded and continuue on
    ###############################################################
    CMD="fcinfo --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"
    
    CMD="fcinfo -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"


    CMD="fcinfo hba-port --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo hba-port -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo remote-port --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo remote-port -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    return $return_code
}

#########################################################
# 		test purpose 001
#########################################################
function tp_fcinfo_004
{
    typeset TEST_NAME="help options for fcinfo"
    cti_assert fcinfo_comstar_004 "Testing $TEST_NAME "
    typeset return_code=0
    typeset re_code=0

    ###############################################################
    # test help options.  Failure will be recorded and continuue on
    ###############################################################
    CMD="fcinfo --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"
    
    CMD="fcinfo -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"


    CMD="fcinfo hba-port --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo hba-port -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo remote-port --help"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    CMD="fcinfo remote-port -?"
    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"
    
    if [[ $return_code != 0 ]]
    then
        cti_report "Test Purpose 4: $TEST_NAME failed  with return"\
            "code $return_code"
        cti_fail "Test Purpose 4: $TEST_NAME failed"
    else
        cti_report "$TEST_NAME output: "
        cti_pass "Test Purpose 4: $TEST_NAME passed"
    fi
}
