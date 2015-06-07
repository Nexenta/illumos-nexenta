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
##################################################################
#
#  This routine tests unsupported fcinfo options which introduced
#   	as part of comstar support.
#
##################################################################
# __stc_assertion_start
# 
# ID: fcinfo_comstar_003
# 
# DESCRIPTION:
# 	Test unsupported fcinfo options which are introduced by
# 	comstar support.
# 
# 	The following test should be failed.
# 	- fcinfo hba-port -i on target mode port
# 	- fcinfo hba-port -t on initiator mode.
# 	- fcinfo hba-port -s on target mode port
# 	- fcinfo remote-port -s -p <target mode port>
# 
# STRATEGY:
# 
# 	Setup:
# 	    Both target mode hba port and intiator mode hba port
# 	    should exists on the hosts.  
# 	Test:
# 	    Verify failure on each command listed above.
# 	Cleanup:
# 	    None
# 
# 	STRATEGY_NOTES:
# 		remote initiators should be connected to the target mode
# 		port to properly run the remote-port related test.
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
##############################################################################
function tp_fcinfo_003
{
    typeset TEST_NAME="testing unsupported options for fcinfo command"
    typeset return_code=0
    typeset re_code=0
    cti_assert fcinfo_comstar_003 "Testing $TEST_NAME "

    CMD="fcinfo hba-port -t"
    cti_execute_cmd "$CMD"
	 re_code=$?
    cti_report "$CMD returns: $re_code"
    if [ $re_code -ne 0 ];then return 1;fi

    #############################################################
    # list of target mode hba-port WWNs.
    #############################################################
    
    # obtain an unique list of target mode WWNs for each of  the HBA types
    CMD="fcinfo hba-port -t | grep 'Port WWN' > ${LOGDIR}/tgtmode-wwn.out3"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-wwn.out3"

    #obtain typical target mode HBA to run test
    CMD="fcinfo hba-port -t | grep Manufacturer > ${LOGDIR}/tgtmode-hbatype.out3"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-hbatype.out3"
    
    CMD="paste  ${LOGDIR}/tgtmode-hbatype.out3 ${LOGDIR}/tgtmode-wwn.out3"
    CMD="$CMD > ${LOGDIR}/tgtmode-wwn-hba-list.out3"
    cti_execute_cmd $CMD
    cti_reportfile "${LOGDIR}/tgtmode-wwn-hba-list.out3"

    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out3 |"\
	"grep QLogic > ${LOGDIR}/tgtmode-unique.list3"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out3 |"\
	"grep JNI >> ${LOGDIR}/tgtmode-unique.list3"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out3 |"\
	"grep Emulex >> ${LOGDIR}/tgtmode-unique.list3"
    cti_execute_cmd "cat ${LOGDIR}/tgtmode-wwn-hba-list.out3 |"\
	"grep Sun >> ${LOGDIR}/tgtmode-unique.list3"
    cti_reportfile "${LOGDIR}/tgtmode-unique.list3"
        
    CMD="cut -f 3 -d: ${LOGDIR}/tgtmode-unique.list3"
    CMD="$CMD > ${LOGDIR}/uniquetgtmodeHBAWWNList3"
    cti_execute_cmd $CMD 
    cti_reportfile "${LOGDIR}/uniquetgtmodeHBAWWNList3"

    UNIQHBAWWNLIST=`eval "cat ${LOGDIR}/uniquetgtmodeHBAWWNList"`

    #############################################################
    # Each target mode port, check the invalid options.
    #############################################################
    for hbaPWWN in $UNIQHBAWWNLIST; 
    do
        cti_report "Working on Targt mode HBAPort: $hbaPWWN"
        CMD="fcinfo hba-port -i $hbaPWWN"
	    cti_execute_cmd "$CMD"
	    re_code=$?
    	cti_report "$CMD returns: $re_code"
	#if not failed, increase return code.
    	if [ $re_code -eq 0 ];then
    		((return_code+=1))
    	fi

	CMD="fcinfo remote-port -s -p $hbaPWWN"
	    cti_execute_cmd "$CMD"
	    re_code=$?
        cti_report "$CMD returns: $re_code"
	#if not failed, increase return code.
    	if [ $re_code -eq 0 ];then
    		((return_code+=1))
    	fi

	for rmtport1 in `eval "fcinfo remote-port -p $hbaPWWN" \
            | grep 'Remote Port WWN' | awk ' { print $4 }'`; 
        do
	
		CMD="fcinfo remote-port -s -p $hbaPWWN $rmtport1"
        	cti_execute_cmd "$CMD"
        	re_code=$?
        	cti_report "$CMD returns: $re_code"
		#if not failed, increase return code.
    		if [ $re_code -eq 0 ];then
    			((return_code+=1))
    		fi
	done
    done

    # obtain an unique list of initiator mode WWNs for each of  the HBA types
    CMD="fcinfo hba-port -i | grep 'Port WWN' > ${LOGDIR}/initmode-wwn.out"
    cti_execute_cmd $CMD 
	
    #if failed to get initiator port list skip the test.
    re_code=$?
    if [ $re_code -ne 0 ];then
   	cti_report "Failed to get an initiator mode port."
    else
    	#obtain typical init mode HBA to run test
        CMD="fcinfo hba-port -i | grep Manufacturer > ${LOGDIR}/initmode-hbatype.out"
    	cti_execute_cmd $CMD 
    
        CMD="paste  ${LOGDIR}/initmode-hbatype.out ${LOGDIR}/initmode-wwn.out"
	CMD="$CDM > ${LOGDIR}/initmode-wwn-hba-list.out"
        cti_execute_cmd $CMD
        cti_reportfile "${LOGDIR}/initmode-wwn-hba-list.out"

        cti_execute_cmd "cat ${LOGDIR}/initmode-wwn-hba-list.out |"\
		"grep QLogic > ${LOGDIR}/initmode-unique.list"
        cti_execute_cmd "cat ${LOGDIR}/initmode-wwn-hba-list.out |"\
		"grep JNI >> ${LOGDIR}/initmode-unique.list"
        cti_execute_cmd "cat ${LOGDIR}/initmode-wwn-hba-list.out |"\
		"grep Emulex >> ${LOGDIR}/tgtmode-unique.list"
        cti_execute_cmd "cat ${LOGDIR}/initmode-wwn-hba-list.out |"\
		"grep Sun >> ${LOGDIR}/tgtmode-unique.list"
        cti_reportfile "${LOGDIR}/initmode-unique.list"
        
        CMD="cut -f 3 -d: ${LOGDIR}/initmode-unique.list"
	CMD="$CMD > ${LOGDIR}/uniqueinitmodeHBAWWNList"
        cti_execute_cmd $CMD 
        cti_reportfile "${LOGDIR}/uniquetgtmodeHBAWWNList"

    	UNIQHBAWWNLIST=`eval "cat ${LOGDIR}/uniqueinitmodeHBAWWNList"`

    	for hbaPWWN in $UNIQHBAWWNLIST; 
    	do
        	cti_report "Working on Initiator mode HBAPort: $hbaPWWN"
		# check failure on -i option.
        	CMD="fcinfo hba-port -t $hbaPWWN"
	    	cti_execute_cmd "$CMD"
	    	re_code=$?
    		cti_report "$CMD returns: $re_code"
		#if not failed, increase return code.
    		if [ $re_code -eq 0 ];then
    			((return_code+=1))
    		fi
    	done
    fi
    
    if [[ $return_code != 0 ]]
    then
        cti_report "Test Purpose 3: $TEST_NAME failed  with return"\
            "code $return_code"
        cti_fail "Test Purpose 3: $TEST_NAME failed"
    else
        cti_report "$TEST_NAME output: "
        cti_pass "Test Purpose 3: $TEST_NAME passed"
    fi
}
