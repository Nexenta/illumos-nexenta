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

ISCSITGT_TARGET_SMF="network/iscsi/target"

#
# NAME
#	iscsitgt_target_smf_enable
#
# SYNOPSIS
#	iscsitgt_target_smf_enable
#
# DESCRIPTION:
#	This function executes enable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function iscsitgt_target_smf_enable 
{
	typeset host_name=$1
	iscsitgt_target_smf_snap 
	CMD="$SVCADM enable -rs $ISCSITGT_TARGET_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISCSITGT_TARGET_SMF smf service can NOT be enabled"
		return 
	fi	
	verify_iscsitgt_target_enable 
	if [ $? -eq 0 ];then
		cti_pass "$ISCSITGT_TARGET_SMF smf enable method testing passed."
	else
		cti_fail "FAIL - $ISCSITGT_TARGET_SMF smf enable method testing failed."
	fi
}
#
# NAME
#	iscsitgt_target_smf_disable
#
# SYNOPSIS
#	iscsitgt_target_smf_disable
#
# DESCRIPTION:
#	This function executes disable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function iscsitgt_target_smf_disable
{
	iscsitgt_target_smf_snap 
	CMD="$SVCADM disable -s $ISCSITGT_TARGET_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISCSITGT_TARGET_SMF smf service can NOT be disabled"
		return 
	fi	
	verify_iscsitgt_target_disable 
	if [ $? -eq 0 ];then
		cti_pass "$ISCSITGT_TARGET_SMF smf disable method testing passed."
	else
		cti_fail "FAIL - $ISCSITGT_TARGET_SMF smf disable method testing failed."
	fi
}

#
# NAME
#	iscsitgt_target_smf_snap
#
# SYNOPSIS
#	iscsitgt_target_smf_snap
#
# DESCRIPTION:
#	This function save the timestamp into temporary variables.
#
# RETURN
#	void
#
function iscsitgt_target_smf_snap
{
	typeset CMD="$SVCS | grep $ISCSITGT_TARGET_SMF | \
	    grep -v grep | awk '{print \$2}'"
	run_ksh_cmd  "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSITGT_TARGET_SMF smf service information"
		return 
	fi	
	ISCSITGT_TARGET_SMF_START_TIME=`get_cmd_stdout`	
}


#
# NAME
#	verify_iscsitgt_target_enable
# DESCRIPTION
#	Verify that the iscsitgt_target enable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - iscsitgt_target enable operation succeed
#	1 - iscsitgt_target enable operation fail
function verify_iscsitgt_target_enable
{
	typeset CMD="$SVCS | grep $ISCSITGT_TARGET_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_ksh_cmd  "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSITGT_TARGET_SMF smf service information"
		return 1
	fi	
	ISCSITGT_TARGET_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISCSITGT_TARGET_SMF_START_TIME" ];then
		if [ -n "$ISCSITGT_TARGET_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSITGT_TARGET_SMF passed from disable to enable."
			return 0
		else
			cti_report "FAIL - $ISCSITGT_TARGET_SMF smf is not started/online (enable)."
			return 1
		fi
	elif [ -n "$ISCSITGT_TARGET_SMF_START_TIME" ];then
		if [ "$ISCSITGT_TARGET_SMF_CURRENT_TIME" = "$ISCSITGT_TARGET_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSITGT_TARGET_SMF passed from enable to enable."
			return 0
		else
			cti_report "FAIL - $ISCSITGT_TARGET_SMF smf is restarted/online (enable)."
			return 1
		fi
	else
		cti_report "FAIL - $ISCSITGT_TARGET_SMF smf is invalid (enable)."
		return 1
	fi
}

#
# NAME
#	verify_iscsitgt_target_disable
# DESCRIPTION
#	Verify that the iscsitgt_target disable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - iscsitgt_target disable operation succeed
#	1 - iscsitgt_target disable operation fail
function verify_iscsitgt_target_disable
{
	typeset CMD="$SVCS | grep $ISCSITGT_TARGET_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_ksh_cmd  "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSITGT_TARGET_SMF smf service information"
		return 1
	fi	
	ISCSITGT_TARGET_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISCSITGT_TARGET_SMF_CURRENT_TIME" ];then
		if [ -n "$ISCSITGT_TARGET_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSITGT_TARGET_SMF passed "\
				"from enable to disable."
			return 0
		else
			cti_report "PASS - svcadm disable $ISCSITGT_TARGET_SMF passed"\
				"from disable to disable."
			return 0
		fi
	else
		cti_report "FAIL - $ISCSITGT_TARGET_SMF service is not stopped after disable.."
		return 1
	fi
}

