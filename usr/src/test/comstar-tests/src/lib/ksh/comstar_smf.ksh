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

STMF_SMF="system/stmf"
STMF_MANIFEST="/lib/svc/manifest/system/stmf.xml"

#
# NAME
#	stmf_smf_enable
#
# SYNOPSIS
#	stmf_smf_enable
#
# DESCRIPTION:
#	This function executes enable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function stmf_smf_enable
{
	stmf_smf_snap
	CMD="$SVCADM enable -rs $STMF_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $STMF_SMF smf service can NOT be enabled"
		return 
	fi	
	verify_stmf_enable	
	if [ $? -eq 0 ];then
		cti_pass "$STMF_SMF smf enable method testing passed."
	else
		cti_fail "FAIL - $STMF_SMF smf enable method testing failed."
	fi
}
#
# NAME
#	stmf_smf_disable
#
# SYNOPSIS
#	stmf_smf_disable
#
# DESCRIPTION:
#	This function executes disable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function stmf_smf_disable
{
	stmf_smf_snap
	CMD="$SVCADM disable -s $STMF_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $STMF_SMF smf service can NOT be disabled"
		return 
	fi	
	verify_stmf_disable	
	if [ $? -eq 0 ];then
		cti_pass "$STMF_SMF smf disable method testing passed."
	else
		cti_fail "FAIL - $STMF_SMF smf disable method testing failed."
	fi
}
#
# NAME
#	stmf_smf_refresh
#
# SYNOPSIS
#	stmf_smf_refresh
#
# DESCRIPTION:
#	This function executes refresh method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function stmf_smf_refresh
{
	stmf_smf_snap
	CMD="$SVCADM refresh $STMF_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $STMF_SMF smf service can NOT be refreshed"
		return 
	fi	
	sleep 5
	verify_stmf_refresh
	if [ $? -eq 0 ];then
		cti_pass "$STMF_SMF smf refresh method testing passed."
	else
		cti_fail "FAIL - $STMF_SMF smf refresh method testing failed."
	fi
}
#
# NAME
#	stmf_smf_snap
#
# SYNOPSIS
#	stmf_smf_snap
#
# DESCRIPTION:
#	This function save the timestamp into temporary variables.
#
# RETURN
#	void
#
function stmf_smf_snap
{
	STMF_SMF_START_TIME=`$SVCS |grep $STMF_SMF | \
		grep -v grep | awk '{print $2}'`	
}


#
# NAME
#	verify_stmf_enable
# DESCRIPTION
#	Verify that the stmf enable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - stmf enable operation succeed
#	1 - stmf enable operation fail
function verify_stmf_enable
{
	STMF_SMF_CURRENT_TIME=`$SVCS |grep $STMF_SMF  | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$STMF_SMF_START_TIME" ];then
		if [ -n "$STMF_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm enable $STMF_SMF passed from disable to enable."
			stmf_disable_enable
			return 0
		else
			cti_report "FAIL - $STMF_SMF service is not started/online (enable)."
			return 1
		fi
	elif [ -n "$STMF_SMF_START_TIME" ];then
		if [ "$STMF_SMF_CURRENT_TIME" = "$STMF_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $STMF_SMF passed from enable to enable."
			return 0
		else
			cti_report "FAIL - $STMF_SMF service is restarted/online (enable)."
			return 1
		fi
	else
		cti_report "FAIL - $STMF_SMF service state is invalid (enable)."
		return 1
	fi
}

#
# NAME
#	verify_stmf_disable
# DESCRIPTION
#	Verify that the stmf disable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - stmf disable operation succeed
#	1 - stmf disable operation fail
function verify_stmf_disable
{
	STMF_SMF_CURRENT_TIME=`$SVCS | grep $STMF_SMF | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$STMF_SMF_CURRENT_TIME" ];then
		if [ -n "$STMF_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $STMF_SMF passed "\
				"from enable to disable."
			stmf_enable_disable
			return 0
		else
			cti_report "PASS - svcadm disable $STMF_SMF passed"\
				"from disable to disable."
			return 0
		fi
	else
		cti_report "FAIL - $STMF_SMF service is not stopped after disable.."
		return 1
	fi
}


#
# NAME
#	verify_stmf_refresh
# DESCRIPTION
#	Verify that the refresh operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - stmf refresh operation succeed
#	1 - stmf refresh operation fail
function verify_stmf_refresh
{
	STMF_SMF_CURRENT_TIME=`$SVCS |grep $STMF_SMF | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$STMF_SMF_START_TIME" ];then
		if [ -z "$STMF_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm refresh $STMF_SMF passed, "\
				"keep $STMF_SMF offline."
			return 0
		else
			cti_report "FAIL - svcadm refresh $STMF_SMF failed, "\
				"$STMF_SMF is online."
			return 1
		fi		
	elif [ -n "$STMF_SMF_START_TIME" ];then
		if [ "$STMF_SMF_CURRENT_TIME" != "$STMF_SMF_START_TIME" ];then
			cti_report "PASS - svcadm refresh $STMF_SMF passed, "\
				"$STMF_SMF is restarted."
			return 0
		else
			cti_report "FAIL - svcadm refresh $STMF_SMF failed, "\
				"$STMF_SMF is not restarted." 
			return 1
		fi
	else
		cti_report "FAIL - $STMF_SMF smf service is invalid (refresh)."
		return 1
	fi
}
#
# NAME
#	check_stmf_disable
# DESCRIPTION
#	Check stmf smf service is offline or not
#
# RETURN
#	Sets the result code
#	0 - stmf smf is offline
#	1 - stmf smf is online
function check_stmf_disable
{
	typeset -i ret=`$SVCS -a |grep $STMF_SMF |grep -v grep | \
		grep online >/dev/null 2>&1;echo $?`
	if [ $ret -eq 0 ];then
		return 1
	else
		return 0
	fi
}

#
# NAME
#	stmf_enable_disable
# DESCRIPTION
#	stmf is changed from enable to disable, all the LU and Target will be 
#	offline, but if disable to disable, the onlined LU and Target will be 
#	kept online
#
# RETURN
#	void
function stmf_enable_disable
{
        for port in $G_TARGET
        do
		typeset scsi_id=`format_scsiname "$port"`
		typeset shell_id=`format_shellvar "$scsi_id"`
		eval TARGET_${shell_id}_ONLINE=N
        done
        for vol in $G_VOL
        do
		eval typeset -u guid=\$LU_${vol}_GUID
		eval LU_${guid}_ONLINE=N
        done
}

#
# NAME
#	stmf_disable_enable
# DESCRIPTION
#	stmf is changed from disable to enable, all the LU and Target will be 
#	online, but if enable to enable, the offlined LU and Target will be 
#	kept offline
#
# RETURN
#	void
function stmf_disable_enable
{
        for port in $G_TARGET
        do
		typeset scsi_id=`format_scsiname "$port"`
		typeset shell_id=`format_shellvar "$scsi_id"`
		eval TARGET_${shell_id}_ONLINE=Y
        done
        for vol in $G_VOL
        do
		eval typeset -u guid=\$LU_${vol}_GUID
		eval LU_${guid}_ONLINE=Y
        done
}

#
# NAME
#	stmf_smf_reload
#
# SYNOPSIS
#	stmf_smf_reload
#
# DESCRIPTION:
#	This function clean up all the persitent data in target host and
#	reload the stmf service as a cleaned one
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function stmf_smf_reload
{	
	$SVCCFG delete -f $STMF_SMF
	if [ $? -ne 0 ];then
		cti_fail "FAIL - delete smf entry $STMF_MANIFEST failed."
		return 1
	fi

	# iscsi targets will be removed when stmf is cleared by "svccfg delete"
	if [ "$TARGET_TYPE" = "ISCSI" ];then
        	unset G_TARGET
        	unset G_TPG
        	unset TARGET_AUTH_INITIATOR
	fi

	cti_report "$STMF_SMF smf delete method testing passed."
	$SVCCFG import $STMF_MANIFEST
	if [ $? -ne 0 ];then
		cti_fail "FAIL - import smf entry $STMF_MANIFEST failed."
		return 1
	fi
	cti_report "$STMF_SMF smf import method testing passed."
	return 0
}
