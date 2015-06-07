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
# NAME
#       fc_target_online_offline_io
# DESCRIPTION
#       target cable pull tests with diskomizer I/O.
#       utilized by fc target test suite
#
# ARGUMENT
#	$1 - fc initiator host
#       $2 - the seconds of target online/offline intervals
#       $3 - test rounds for target online/offline 
#
# RETURN
#       void
#
function fc_target_online_offline_io
{	
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	if [ $NO_IO = 0 ];then
		return
	fi
	typeset cmd="$LUXADM probe | grep -c \"Logical Path\""
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NO_PRE=`get_cmd_stdout`
	if [ $LUN_NO_PRE -eq 0 ];then
		cti_fail "FAIL - $hostname : fail to get LUN LIST"
		report_err "$cmd"
	elif [ $VOL_MAX -ne $LUN_NO_PRE ]; then
		cti_report "WARNING - There should be $VOL_MAX LUNs"\
                    "on initiator host $hostname setup,"\
                    "but $LUN_NO_PRE LUNs now"
                report_err "$cmd"
	else
		:
	fi

	typeset iter=1
	typeset t_portWWN
	while [ $iter -le $max_iter ]	
	do
		cti_report "Executing: running target online - offline to"\
		    "verify failover with $iter round"\
		    "and $intervals intervals"
		
		for t_portWWN in $G_TARGET
		do
			typeset port=`format_shellvar $t_portWWN`
			typeset cmd="$STMFADM offline-target $t_portWWN"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not offline fc target port"
			fi
			cti_report "sleep $intervals intervals after offline target port"
			sleep $intervals
			
			typeset cmd="$STMFADM online-target $t_portWWN"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING - Can not online fc target port"
			fi
			cti_report "sleep $intervals intervals after online target port"
			sleep $intervals
		done
		(( iter+=1 ))
	done
}
#
# NAME
#       fc_target_online_offline
# DESCRIPTION
#       target cable pull tests without diskomizer I/O.
#       utilized by fc target test suite
#
# ARGUMENT
#	$1 - fc initiator host
#       $2 - the seconds of target online/offline intervals
#       $3 - test rounds for target online/offline 
#
# RETURN
#       void
#
function fc_target_online_offline
{	
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	leadville_bug_trigger $hostname
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NO_PRE=`get_cmd_stdout  | grep -c "Logical Path"`	
	if [ $LUN_NO_PRE -eq 0 ];then
		cti_fail "FAIL - $hostname : fail to get LUN LIST"
		report_err "$cmd"
	elif [ $VOL_MAX -ne $LUN_NO_PRE ]; then
		cti_report "WARNING - There should be $VOL_MAX LUNs"\
                    "on initiator host $hostname setup,"\
                    "but $LUN_NO_PRE LUNs now"
                report_err "$cmd"
	else
		:
	fi
	
	typeset target_list="$G_TARGET"
	typeset t_portWWN
	for t_portWWN in $target_list
	do
		typeset port=`format_shellvar $t_portWWN`
		eval typeset online="\$TARGET_${port}_ONLINE"
		if [ "$online" = "Y" ];then		
			eval TARGET_${port}_ONLINE=N
			typeset cmd="$STMFADM offline-target $t_portWWN"		
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING -"\
				    "Can not offline fc target port"
			fi
		fi
	done
	cti_report "Executing: sleep $FT_SNOOZE intervals to verify"\
		"all the LUNs are offline from initiator host"
	sleep $FT_SNOOZE
	leadville_bug_trigger $hostname
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NOW=`get_cmd_stdout  | grep -c "Logical Path"`
	if [ $LUN_NOW -ne 0 ];then
		cti_fail "FAIL - There should be 0 LUNs on initiator host"\
	 	    "$hostname after offline-target, but $LUN_NOW LUNs now"
		report_err "$cmd"
	fi

	for t_portWWN in $target_list
	do
		typeset port=`format_shellvar $t_portWWN`
		eval typeset online="\$TARGET_${port}_ONLINE"
		if [ "$online" = "N" ];then		
			eval TARGET_${port}_ONLINE=Y
			typeset cmd="$STMFADM online-target $t_portWWN"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "WARNING -"\
				    "Can not online fc target port"
			fi
		fi
	done
	cti_report "Executing: sleep $FT_SNOOZE intervals to verify"\
	    "all the LUNs are online from initiator host"
	sleep $FT_SNOOZE
	leadville_bug_trigger $hostname
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NOW=`get_cmd_stdout | grep -c "Logical Path"`
	if [ $LUN_NOW -lt $LUN_NO_PRE ];then
		cti_fail "FAIL - There should be at least $LUN_NO_PRE LUNs"\
		    "on initiator host $hostname after online-target,"\
		    "but $LUN_NOW LUNs now"
		report_err "$cmd"
	fi
}

