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

FCOE_SMF="system/fcoe_target"
FCOE_MANIFEST="/lib/svc/manifest/system/fcoe_target.xml"
FCOE_PORTLIST_PG="fcoe-port-list-pg"
FCOE_PORTLIST_PROPERTY="fcoe-port-list-pg/port_list_p"

#
# NAME
#	fcoe_smf_enable
#
# SYNOPSIS
#	fcoe_smf_enable
#
# DESCRIPTION:
#	This function executes enable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function fcoe_smf_enable
{
	fcoe_smf_snap
	CMD="$SVCADM enable -rs $FCOE_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $FCOE_SMF smf service can NOT be enabled"
		return 
	fi	
	verify_fcoe_enable	
	if [ $? -eq 0 ];then
		cti_pass "$FCOE_SMF smf enable method testing passed."
	else
		cti_fail "FAIL - $FCOE_SMF smf enable method testing failed."
	fi
}
#
# NAME
#	fcoe_smf_disable
#
# SYNOPSIS
#	fcoe_smf_disable
#
# DESCRIPTION:
#	This function executes disable method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function fcoe_smf_disable
{
	fcoe_smf_snap
	CMD="$SVCADM disable -s $FCOE_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $FCOE_SMF smf service can NOT be disabled"
		return 
	fi	
	verify_fcoe_disable	
	if [ $? -eq 0 ];then
		cti_pass "$FCOE_SMF smf disable method testing passed."
	else
		cti_fail "FAIL - $FCOE_SMF smf disable method testing failed."
	fi
}
#
# NAME
#	fcoe_smf_refresh
#
# SYNOPSIS
#	fcoe_smf_refresh
#
# DESCRIPTION:
#	This function executes refresh method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function fcoe_smf_refresh
{
	fcoe_smf_snap
	CMD="$SVCADM refresh $FCOE_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $FCOE_SMF smf service can NOT be refreshed"
		return 
	fi	
	sleep 20
	verify_fcoe_refresh
	if [ $? -eq 0 ];then
		cti_pass "$FCOE_SMF smf refresh method testing passed."
	else
		cti_fail "FAIL - $FCOE_SMF smf refresh method testing failed."
	fi
}
#
# NAME
#	fcoe_smf_restart
#
# SYNOPSIS
#	fcoe_smf_restart
#
# DESCRIPTION:
#	This function executes restart method for testing.
#
# RETURN
#       Set the result code if an exception is encountered 
#	void
#
function fcoe_smf_restart
{
	fcoe_smf_snap
	CMD="$SVCADM restart $FCOE_SMF"
	cti_report "Executing: $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"
		cti_fail "FAIL - $FCOE_SMF smf service can NOT be restarted"
		return 
	else
		cti_report "$CMD passed"
	fi	
	sleep 20
}
#
# NAME
#	fcoe_smf_snap
#
# SYNOPSIS
#	fcoe_smf_snap
#
# DESCRIPTION:
#	This function save the timestamp into temporary variables.
#
# RETURN
#       1 failed
#       0 successful
#
function fcoe_smf_snap
{
	FCOE_SMF_START_TIME=`$SVCS |grep $FCOE_SMF | \
		grep -v grep | awk '{print $2}'`	
}


#
# NAME
#	verify_fcoe_enable
# DESCRIPTION
#	Verify that the fcoe enable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - fcoe enable operation succeed
#	1 - fcoe enable operation fail
function verify_fcoe_enable
{
	FCOE_SMF_CURRENT_TIME=`$SVCS |grep $FCOE_SMF  | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$FCOE_SMF_START_TIME" ];then
		if [ -n "$FCOE_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm enable $FCOE_SMF passed from disable to enable."
			fcoe_disable_enable
			return 0
		else
			cti_report "FAIL - $FCOE_SMF service is not started/online (enable)."
			return 1
		fi
	elif [ -n "$FCOE_SMF_START_TIME" ];then
		if [ "$FCOE_SMF_CURRENT_TIME" = "$FCOE_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $FCOE_SMF passed from enable to enable."
			return 0
		else
			cti_report "FAIL - $FCOE_SMF service is restarted/online (enable)."
			return 1
		fi
	else
		cti_report "FAIL - $FCOE_SMF service state is invalid (enable)."
		return 1
	fi
}

#
# NAME
#	verify_fcoe_disable
# DESCRIPTION
#	Verify that the fcoe disable operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - fcoe disable operation succeed
#	1 - fcoe disable operation fail
function verify_fcoe_disable
{
	FCOE_SMF_CURRENT_TIME=`$SVCS | grep $FCOE_SMF | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$FCOE_SMF_CURRENT_TIME" ];then
		if [ -n "$FCOE_SMF_START_TIME" ];then
			cti_report "PASS - svcadm enable $FCOE_SMF passed "\
				"from enable to disable."
			fcoe_enable_disable
			return 0
		else
			cti_report "PASS - svcadm disable $FCOE_SMF passed"\
				"from disable to disable."
			return 0
		fi
	else
		cti_report "FAIL - $FCOE_SMF service is not stopped after disable.."
		return 1
	fi
}


#
# NAME
#	verify_fcoe_refresh
# DESCRIPTION
#	Verify that the refresh operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - fcoe refresh operation succeed
#	1 - fcoe refresh operation fail
function verify_fcoe_refresh
{
	FCOE_SMF_CURRENT_TIME=`$SVCS |grep $FCOE_SMF | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$FCOE_SMF_START_TIME" ];then
		if [ -z "$FCOE_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm refresh $FCOE_SMF passed, "\
				"keep $FCOE_SMF offline."
			return 0
		else
			cti_report "FAIL - svcadm refresh $FCOE_SMF failed, "\
				"$FCOE_SMF is online."
			return 1
		fi		
	else
	  	if [ -z "$FCOE_SMF_CURRENT_TIME" ];then
			cti_report "FAIL - svcadm refresh $FCOE_SMF failed, "\
				"$FCOE_SMF is offline."
			return 1
		else
			cti_report "PASS - svcadm refresh $FCOE_SMF passed, "\
				"keep $FCOE_SMF online."
			return 0
		fi
	fi
}
#
# NAME
#	verify_fcoe_restart
# DESCRIPTION
#	Verify that the restart operation successfully or not.
#
# RETURN
#	Sets the result code
#	0 - fcoe restart operation succeed
#	1 - fcoe restart operation fail
function verify_fcoe_restart
{
	FCOE_SMF_CURRENT_TIME=`$SVCS |grep $FCOE_SMF | grep -v grep | \
		grep online | awk '{print $2}'`
	if [ -z "$FCOE_SMF_START_TIME" ];then
		if [ -z "$FCOE_SMF_CURRENT_TIME" ];then
			cti_report "PASS - svcadm restart $FCOE_SMF passed, "\
				"keep $FCOE_SMF offline."
			return 0
		else
			cti_report "FAIL - svcadm restart $FCOE_SMF failed, "\
				"$FCOE_SMF is online."
			return 1
		fi		
	else
	  	if [ -z "$FCOE_SMF_CURRENT_TIME" ];then
			cti_report "FAIL - svcadm restart $FCOE_SMF failed, "\
				"$FCOE_SMF is offline."
			return 1
		else
			cti_report "PASS - svcadm restart $FCOE_SMF passed, "\
				"keep $FCOE_SMF online."
			return 0
		fi
	fi
}
#
# NAME
#	check_fcoe_disable
# DESCRIPTION
#	Check fcoe smf service is offline to 
#	make sure target group can be modified.
#
# RETURN
#	Sets the result code
#	0 - fcoe smf is offline
#	1 - fcoe smf is online
function check_fcoe_disable
{
	typeset -i ret=`$SVCS -a |grep $FCOE_SMF |grep -v grep | \
		grep online >/dev/null 2>&1;echo $?`
	if [ $ret -eq 0 ];then
		return 1
	else
		return 0
	fi
}

#
# NAME
#	check_fcoe_smf_stored
# DESCRIPTION
#	Check fcoe port information is stored by smf service
#	Exacmple: check_fcoe_smf_stored nxge0
#
# RETURN
#	Sets the result code
#	0 - fcoe port information is stored in smf database
#	1 - fcoe port information is not stored in smf database
function check_fcoe_smf_stored
{
  	typeset mac_interface=$1
	cti_report "$SVCCFG -s $FCOE_SMF listprop $FCOE_PORTLIST_PROPERTY | grep $mac_interface" 
	CMD="$SVCCFG -s $FCOE_SMF listprop $FCOE_PORTLIST_PROPERTY | grep $mac_interface" 
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]; then
		cti_report "check_fcoe_smf_stored found $mac_interface"
		return 0
	else
		cti_report "check_fcoe_smf_stored did not find $mac_interface"
		return 1
	fi
}

#
# NAME
#	fcoe_smf_add_propgroup
# DESCRIPTION
#	Add property group to fcoe service
#	Exacmple: fcoe_smf_add_propvalue
#
# RETURN
#	Sets the result code
#	0 - added succesfully
#	1 - failed to add property value
function fcoe_smf_add_propgroup
{
	CMD="$SVCCFG -s $FCOE_SMF addpg $FCOE_PORTLIST_PG astring"
	cti_report "Executing $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]; then
		cti_report "fcoe_smf_add_propgroup addpg passed"
		return 0
	else
		cti_report "fcoe_smf_add_propgroup addpg failed"
		return 1
	fi
}

#
# NAME
#	fcoe_smf_setprop
# DESCRIPTION
#	Create a property name and add a property value to fcoe service
#	Exacmple: fcoe_smf_add_propvalue nxge0
#
# RETURN
#	Sets the result code
#	0 - added succesfully
#	1 - failed to add property value
function fcoe_smf_setprop
{
  	typeset mac_interface=$1
	typeset propvalue="${mac_interface}:0000000000000000:0000000000000000:1:0"
	CMD="$SVCCFG -s $FCOE_SMF setprop $FCOE_PORTLIST_PROPERTY = ustring: $propvalue"
	cti_report "Executing $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]; then
		cti_report "fcoe_smf_add_propvalue addpropvalue for $mac_interface passed"
		return 0
	else
		cti_report "fcoe_smf_add_propvalue addpropvalue for $mac_interface failed"
		return 1
	fi
}

#
# NAME
#	fcoe_smf_add_propvalue
# DESCRIPTION
#	Add one property value to fcoe service after property is created
#	Exacmple: fcoe_smf_add_propvalue nxge0
#
# RETURN
#	Sets the result code
#	0 - added succesfully
#	1 - failed to add property value
function fcoe_smf_add_propvalue
{
  	typeset mac_interface=$1
	typeset propvalue="${mac_interface}:0000000000000000:0000000000000000:1:0"
	CMD="$SVCCFG -s $FCOE_SMF addpropvalue $FCOE_PORTLIST_PROPERTY $propvalue"
	cti_report "Executing $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]; then
		cti_report "fcoe_smf_add_propvalue addpropvalue for $mac_interface passed"
		return 0
	else
		cti_report "fcoe_smf_add_propvalue addpropvalue for $mac_interface failed"
		return 1
	fi
}

#
# NAME
#	fcoe_enable_disable
# DESCRIPTION
#	fcoe is changed from enable to disable, all the LU and Target will be 
#	offline, but if disable to disable, the onlined LU and Target will be 
#	kept online
#
# RETURN
#	void
function fcoe_enable_disable
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
#	fcoe_disable_enable
# DESCRIPTION
#	fcoe is changed from disable to enable, all the LU and Target will be 
#	online, but if enable to enable, the offlined LU and Target will be 
#	kept offline
#
# RETURN
#	void
function fcoe_disable_enable
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
#	fcoe_smf_reload
#
# SYNOPSIS
#	fcoe_smf_reload
#
# DESCRIPTION:
#	This function clean up all the persitent data in target host and
#	reload the fcoe service as a cleaned one
#
# RETURN
#       Set the result code if an exception is encountered 
#       1 failed
#       0 successful
#
function fcoe_smf_reload
{	
	cti_report "Executing $SVCCFG delete -f $FCOE_SMF"
	$SVCCFG delete -f $FCOE_SMF
	if [ $? -ne 0 ];then
		cti_fail "FAIL - delete smf entry $FCOE_MANIFEST failed."
		return 1
	fi
	cti_report "$FCOE_SMF smf delete method testing passed."

	cti_report "Executing $SVCCFG import $FCOE_MANIFEST"
	$SVCCFG import $FCOE_MANIFEST
	if [ $? -ne 0 ];then
		cti_fail "FAIL - import smf entry $FCOE_MANIFEST failed."
		return 1
	fi
	cti_report "$FCOE_SMF smf import method testing passed."
	sleep 20
	return 0
}
