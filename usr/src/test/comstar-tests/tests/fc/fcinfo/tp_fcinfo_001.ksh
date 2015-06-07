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
# ID: fcinfo_comstar_001
# 
# DESCRIPTION:
# 	Runs supported fcinfo subcommand/options to comstar hba port. 
#         - fcinfo hba-port -t
#         - fcinfo hba-port -tl
#         - fcinfo hba-port <target mode hba-port wwn>
#         - fcinfo hba-port -l <target mode hba-port wwn>
#         - fcinfo remote-port -p <hba-port wwn>
#         - fcinfo remote-port -pl <hba-port wwn>
#         - fcinfo remote-port -pl <hba-port wwn> <remote-port wwn>
#         - fcinfo remote-port -pl <hba-port wwn> <remote-port wwn1>
#                                 <remote-port wwn2>
# 
# STRATEGY:
# 
# 	Setup:
# 	    Target mode hba port should exists on the hosts that the test
# 	    runs.
# 	Test:
# 	    Verify the return code of each command listed below.
# 	Cleanup:
# 	    None
# 
# 	STRATEGY_NOTES:
# 		remote initiators should be connected to properly drive
# 		the remote-port test.
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
#########################################################
# 		test purpose 001
#########################################################
function tp_fcinfo_001
{
    typeset TEST_NAME="all supported subcommands/options for comstar ports"
    cti_assert fcinfo_comstar_001 "Testing $TEST_NAME "
    typeset MAX_DEVICES=3
    typeset return_code=0
    typeset re_code=0

    #########################################################
    # if no target mode port found, stop and return and error
    #########################################################
    CMD="fcinfo hba-port -t"
    cti_execute_cmd "$CMD"
    if [ $? -ne 0 ];then return 1;fi

    #########################################################
    # if construct the list of target mode ports.
    #########################################################
    # obtain an unique list of target mode WWNs for each of  the HBA types
    CMD="fcinfo hba-port -t | grep 'Port WWN' > ${LOGDIR}/tgtmode-wwn.out"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-wwn.out"

    #obtain typical target mode HBA to run test
    CMD="fcinfo hba-port -t | grep Manufacturer > ${LOGDIR}/tgtmode-hbatype.out"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-hbatype.out"
    
    CMD="paste  ${LOGDIR}/tgtmode-hbatype.out ${LOGDIR}/tgtmode-wwn.out"
    CMD="$CMD > ${LOGDIR}/tgtmode-wwn-hba-list.out"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-wwn-hba-list.out"

    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out |"\
	"grep QLogic > ${LOGDIR}/tgtmode-unique.list"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out |"\
	"grep JNI >> ${LOGDIR}/tgtmode-unique.list"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out |"\
	"grep Emulex >> ${LOGDIR}/tgtmode-unique.list"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out |"\
	"grep Sun >> ${LOGDIR}/tgtmode-unique.list"
    cti_reportfile "${LOGDIR}/tgtmode-unique.list"
        
    CMD="cut -f 3 -d: ${LOGDIR}/tgtmode-unique.list >"
    CMD="$CMD ${LOGDIR}/uniquetgtmodeHBAWWNList"
    cti_execute_cmd $CMD 
    cti_reportfile "${LOGDIR}/uniquetgtmodeHBAWWNList"

    #Go through each target mode port and run hba-port/remote-port command.
    UNIQHBAWWNLIST=`eval "cat ${LOGDIR}/uniquetgtmodeHBAWWNList"`
    for hbaPWWN in $UNIQHBAWWNLIST; 
    do
        cti_report "Working on Targt mode HBAPort: $hbaPWWN"

	# run hba-port with a specific hba port wwn.
        CMD="fcinfo hba-port $hbaPWWN"
	    cti_execute_cmd "$CMD"
	    re_code=$?
    	((return_code+=$re_code))
    	cti_report "$CMD returns: $re_code"
	
	# run hba-port -l with a specific hba port wwn.
	CMD="fcinfo hba-port -l $hbaPWWN"
	    cti_execute_cmd "$CMD"
	    re_code=$?
        ((return_code+=$re_code))
        cti_report "$CMD returns: $re_code"

	# run remote-port -p with a specific hba port wwn.
    	CMD="fcinfo remote-port -p $hbaPWWN"
        cti_execute_cmd "$CMD"
        re_code=$?
        ((return_code+=$re_code))
        cti_report "$CMD returns: $re_code"

	# run remote-port -lp with a specific hba port wwn.
    	CMD="fcinfo remote-port -lp $hbaPWWN"
        cti_execute_cmd "$CMD"
        re_code=$?
        ((return_code+=$re_code))
        cti_report "$CMD returns: $re_code"

    	#########################################################
    	# Go through each remote port run -lp 
    	#########################################################
	for rmtport1 in `eval "fcinfo remote-port -p $hbaPWWN" \
            | grep 'Remote Port WWN' | awk ' { print $4 }'`; 
        do
	
	    # run remote-port -lp with a specific hba port wwn and remote port
	    # wwn.
	    CMD="fcinfo remote-port -lp $hbaPWWN $rmtport1"
        	cti_execute_cmd "$CMD"
        	re_code=$?
            ((return_code+=$re_code))
            cti_report "$CMD returns: $re_code"
	    device_count=0
	    for rmtport2 in `eval "fcinfo remote-port -p $hbaPWWN" \
                | grep 'Remote Port WWN' | awk ' { print $4}'`; 
            do
	       # run remote-port -lp with a specific hba port wwn and remote
	       # port wwns.
		CMD="fcinfo remote-port -lp $hbaPWWN $rmtport1 $rmtport2"
        		cti_execute_cmd "$CMD"
        		re_code=$?
        	((return_code+=$re_code))
        	cti_report "$CMD returns: $re_code"
		if [[ $device_count -le $MAX_DEVICES ]]; then
              	    device_count=`expr $device_count + 1`
            	else
                    break
            	fi
	    done
	done
    done

    #########################################################
    # Testing -lt option without wwn operand.
    #########################################################
    cti_report "Testing -lt option without wwn operand"
    CMD="fcinfo hba-port -lt"
	    cti_execute_cmd "$CMD"
	    re_code=$?
    ((return_code+=$re_code))
    cti_report "$CMD returns: $re_code"
	
    if [[ $return_code != 0 ]]
    then
        cti_report "Test Purpose 1: $TEST_NAME failed  with return"\
            "code $return_code"
        cti_fail "Test Purpose 1: $TEST_NAME failed"
    else
        cti_report "$TEST_NAME output: "
        cti_pass "Test Purpose 1: $TEST_NAME passed"
    fi
}
