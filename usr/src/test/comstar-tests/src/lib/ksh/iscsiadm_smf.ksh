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

ISCSI_INITIATOR_SMF="network/iscsi/initiator"
ISCSI_INITIATOR_MANIFEST="/lib/svc/manifest/network/iscsi/iscsi-initiator.xml"

#
# NAME
#	iscsi_initiator_smf_enable
#
# SYNOPSIS
#	iscsi_initiator_smf_enable
#
# DESCRIPTION:
#	This function executes enable method for testing.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function iscsi_initiator_smf_enable 
{
	typeset host_name=$1
	iscsi_initiator_smf_snap $host_name
	CMD="$SVCADM enable -rs $ISCSI_INITIATOR_SMF"
	cti_report "Executing: $CMD"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISCSI_INITIATOR_SMF smf service can NOT be enabled"
		return 
	fi	
	verify_iscsi_initiator_enable $host_name
	if [ $? -eq 0 ];then
		cti_pass "$ISCSI_INITIATOR_SMF smf enable method testing passed."
	else
		cti_fail "FAIL - $ISCSI_INITIATOR_SMF smf enable method testing failed."
	fi
}
#
# NAME
#	iscsi_initiator_smf_disable
#
# SYNOPSIS
#	iscsi_initiator_smf_disable
#
# DESCRIPTION:
#	This function executes disable method for testing.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function iscsi_initiator_smf_disable
{
	typeset host_name=$1
	iscsi_initiator_smf_snap $host_name
	CMD="$SVCADM disable -s $ISCSI_INITIATOR_SMF"
	cti_report "Executing: $CMD"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $ISCSI_INITIATOR_SMF smf service can NOT be disabled"
		return 
	fi	
	verify_iscsi_initiator_disable $host_name
	if [ $? -eq 0 ];then
		cti_pass "$ISCSI_INITIATOR_SMF smf disable method testing passed."
	else
		cti_fail "FAIL - $ISCSI_INITIATOR_SMF smf disable method testing failed."
	fi
}

#
# NAME
#	iscsi_initiator_smf_snap
#
# SYNOPSIS
#	iscsi_initiator_smf_snap
#
# DESCRIPTION:
#	This function save the timestamp into temporary variables.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	void
#
function iscsi_initiator_smf_snap
{
	typeset host_name=$1
	typeset CMD="$SVCS | grep $ISCSI_INITIATOR_SMF | \
	    grep -v grep | awk '{print \$2}'"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSI_INITIATOR_SMF smf service information"
		return 
	fi	
	ISCSI_INITIATOR_SMF_START_TIME=`get_cmd_stdout`	
}


#
# NAME
#	verify_iscsi_initiator_enable
# DESCRIPTION
#	Verify that the iscsi_initiator enable operation successfully or not.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	0 - iscsi_initiator enable operation succeed
#	1 - iscsi_initiator enable operation fail
function verify_iscsi_initiator_enable
{
	typeset host_name=$1
	typeset CMD="$SVCS | grep $ISCSI_INITIATOR_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSI_INITIATOR_SMF smf service information"
		return 1
	fi	
	ISCSI_INITIATOR_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISCSI_INITIATOR_SMF_START_TIME" ];then
		if [ -n "$ISCSI_INITIATOR_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSI_INITIATOR_SMF passed from disable to enable."
			return 0
		else
			cti_report "FAIL - $ISCSI_INITIATOR_SMF smf is not started/online (enable)."
			return 1
		fi
	elif [ -n "$ISCSI_INITIATOR_SMF_START_TIME" ];then
		if [ "$ISCSI_INITIATOR_SMF_CURRENT_TIME" = "$ISCSI_INITIATOR_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSI_INITIATOR_SMF passed from enable to enable."
			return 0
		else
			cti_report "FAIL - $ISCSI_INITIATOR_SMF smf is restarted/online (enable)."
			return 1
		fi
	else
		cti_report "FAIL - $ISCSI_INITIATOR_SMF smf is invalid (enable)."
		return 1
	fi
}

#
# NAME
#	verify_iscsi_initiator_disable
# DESCRIPTION
#	Verify that the iscsi_initiator disable operation successfully or not.
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	0 - iscsi_initiator disable operation succeed
#	1 - iscsi_initiator disable operation fail
function verify_iscsi_initiator_disable
{
	typeset host_name=$1
	typeset CMD="$SVCS | grep $ISCSI_INITIATOR_SMF | \
	    grep -v grep | grep online | awk '{print \$2}'"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - can not list the $ISCSI_INITIATOR_SMF smf service information"
		return 1
	fi	
	ISCSI_INITIATOR_SMF_CURRENT_TIME=`get_cmd_stdout`
	if [ -z "$ISCSI_INITIATOR_SMF_CURRENT_TIME" ];then
		if [ -n "$ISCSI_INITIATOR_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $ISCSI_INITIATOR_SMF passed "\
				"from enable to disable."
			return 0
		else
			cti_report "PASS - svcadm disable $ISCSI_INITIATOR_SMF passed"\
				"from disable to disable."
			return 0
		fi
	else
		cti_report "FAIL - $ISCSI_INITIATOR_SMF service is not stopped after disable.."
		return 1
	fi
}

