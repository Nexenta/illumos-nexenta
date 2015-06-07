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
#
#  This routine tests both -i and -t options for hba-port
#  and compares the output with hba-port -it and plain hba-port.  
#
###############################################################
#
# __stc_assertion_start
# 
# 
# ID: fcinfo_comstar_002
# 
# DESCRIPTION:
# 	It checks the output of hba-port commands uisng 
# 		following commands.
#        - fcinfo hba-port
#        - fcinfo hba-port -it
#        - fcinfo hba-port -i
#        - fcinfo hba-port -t
# 
# STRATEGY:
# 
# 	Setup:
# 	    Both target mode hba port and initiator mode hba prot
# 	    should exist to properly run the test.
# 	Test:
# 	    Verify the return code of each command listed above and
# 	    compare the output 
# 	    'fcinfo hba-port' vs 'fcinfo hba-port -it' 
# 	    combinatioin of -i and -t output vs 'fcinfo hba-port -it'
# 	Cleanup:
# 	    None
# 
# 	STRATEGY_NOTES:
# 		the initiator mode hba port is not required to have 
# 		remote-ports connected.
# 
# KEYWORDS:
# 	 fcinfo hba-port
# 
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
#
##############################################################################
function fcinfo_hbaport_cmds
{
    typeset return_code=0
    typeset re_code=0

    ###########################################################
    # test hba-port -it option
    ###########################################################
    CMD="fcinfo hba-port -it"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    ###########################################################
    # test hba-port -i option
    ###########################################################
    # test hba-port -i option
    CMD="fcinfo hba-port -i"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    ###########################################################
    # test hba-port -t option
    ###########################################################
    CMD="fcinfo hba-port -t"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"


    if [ $return_code -ne 0 ];then
    	cti_report "Individual hba-port -it, -i, -t commands failed." 
    else
    	# obtain an unique list of target mode WWNs for each of  the HBA types
    	cti_execute_cmd "fcinfo hba-port -it | grep Port" \
	    > ${LOGDIR}/wwn-it.out

    	# obtain an unique list of target mode WWNs for each of  the HBA types
    	cti_execute_cmd "fcinfo hba-port | grep Port" \
	    > ${LOGDIR}/wwn-plain.out

	##########################################################
    	# compare plain hba-port output with 'hba-port -it' output
	##########################################################
    	diff  ${LOGDIR}/wwn-it.out  ${LOGDIR}/wwn-plain.out >> ${LOGFILE} 2>&1
    	re_code=$?
    	cti_report "diff between plain hba-port and hba-port -it returns: "\
	    "$re_code"
    	((return_code+=$re_code))

    	#obtain typical target mode HBA to run test
    	cti_execute_cmd "fcinfo hba-port -t | grep Port" > ${LOGDIR}/tgt.out
    	cti_execute_cmd "fcinfo hba-port -i | grep Port" > ${LOGDIR}/init.out
    	cat ${LOGDIR}/init.out > ${LOGDIR}/wwn-merge.out
    	cat ${LOGDIR}/tgt.out >> ${LOGDIR}/wwn-merge.out

	##########################################################
    	# compare 'hba-port -it' output with merged output. 
	##########################################################
    	diff  ${LOGDIR}/wwn-it.out  ${LOGDIR}/wwn-merge.out >> ${LOGFILE} 2>&1
    	re_code=$?
    	cti_report "diff between hba-port -it and "\
	    "merge of hba-port -i and -t returns $re_code"
    	((return_code+=$re_code))
    fi

    return $return_code
}

##########################################################
# tp_fcinfo_002 calls fcinfo_hbaport_cmds(). 
##########################################################
function tp_fcinfo_002
{
    typeset TEST_NAME="options -i and -t for fcinfo command"
    cti_assert fcinfo_comstar_002 "Testing $TEST_NAME "
    typeset return_code=0
    typeset re_code=0

    ###########################################################
    # test hba-port -it option
    ###########################################################
    CMD="fcinfo hba-port -it"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    ###########################################################
    # test hba-port -i option
    ###########################################################
    # test hba-port -i option
    CMD="fcinfo hba-port -i"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"

    ###########################################################
    # test hba-port -t option
    ###########################################################
    CMD="fcinfo hba-port -t"
    cti_execute_cmd "$CMD"
    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"


    if [ $return_code -ne 0 ];then
    	cti_report "Individual hba-port -it, -i, -t commands failed." 
    else
    	# obtain an unique list of target mode WWNs for each of  the HBA types
	CMD="fcinfo hba-port -it | grep 'Port WWN' > ${LOGDIR}/wwn-it.out"
    	cti_execute_cmd $CMD
	cti_reportfile "${LOGDIR}/wwn-it.out"

    	# obtain an unique list of target mode WWNs for each of  the HBA types
	CMD="fcinfo hba-port | grep 'Port WWN' > ${LOGDIR}/wwn-plain.out"
    	cti_execute_cmd $CMD 

	##########################################################
    	# compare plain hba-port output with 'hba-port -it' output
	##########################################################
    	CMD="diff  ${LOGDIR}/wwn-it.out  ${LOGDIR}/wwn-plain.out"
	cti_execute_cmd $CMD
    	re_code=$?
    	cti_report "diff between plain hba-port and hba-port -it returns: "\
	    "$re_code"
    	((return_code+=$re_code))

    	#obtain typical target mode HBA to run test
	CMD="fcinfo hba-port -t | grep 'Port WWN' > ${LOGDIR}/tgtmode.out"
    	cti_execute_cmd $CMD 
	CMD="fcinfo hba-port -i | grep 'Port WWN' > ${LOGDIR}/initmode.out"
    	cti_execute_cmd $CMD 
    	cti_execute_cmd "cat ${LOGDIR}/initmode.out > ${LOGDIR}/wwn-merge.out"
    	cti_execute_cmd "cat ${LOGDIR}/tgtmode.out >> ${LOGDIR}/wwn-merge.out"
	cti_reportfile "${LOGDIR}/wwn-merge.out"

	##########################################################
    	# compare 'hba-port -it' output with merged output. 
	##########################################################
    	cti_execute_cmd "diff ${LOGDIR}/wwn-it.out ${LOGDIR}/wwn-merge.out"
    	re_code=$?
    	cti_report "diff between hba-port -it and "\
	    "merge of hba-port -i and -t returns $re_code"
    	((return_code+=$re_code))
    fi

    if [[ $return_code != 0 ]]
    then
        cti_report "Test Purpose 2: $TEST_NAME failed  with return"\
            "code $return_code"
        cti_fail "Test Purpose 2: $TEST_NAME failed"
    else
        cti_report "$TEST_NAME output: "
        cti_pass "Test Purpose 2: $TEST_NAME passed"
    fi
}
