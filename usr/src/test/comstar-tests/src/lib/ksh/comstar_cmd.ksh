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
#	run_ksh_cmd
#
# DESCRIPTION
#	Run the local command with timeout check mechanism.
#	To prevent the executing command hanging during the testing,
#	the command will be running in backgroup and be checked in loop 
#	by 1 second interval to detect whether it ends. 
#	If exceeds $TIME_OUT,
#	    The process will be killed and the relevant information is saved.
#	Else,
#	    The stdout of command will be save at $CMD_STDOUT file.
#	    The stderr of command will be save at $CMD_STDERR file.
#	    The stdret of command will be save at $CMD_STDRET file.
#
# RETURN
#	stdout, stderr and return value is saved into temporary files
#	void
#
CMD_STDOUT=$LOGDIR/cmd.stdout
CMD_STDERR=$LOGDIR/cmd.stderr
CMD_RETVAL=$LOGDIR/cmd.retval

function run_ksh_cmd
{
	local_command=$1
	time_out=${TIME_OUT:-60}
	eval "$local_command;echo \$?" > $CMD_STDOUT 2>$CMD_STDERR &
	local_pid=$!
	typeset d_index=0
	while [ $d_index -lt $time_out ]
	do
		id_retval=`ps -ef |grep -v grep | grep -w $local_pid | awk \
			'BEGIN{ RET=1;} \
			{if ($2=='"$local_pid"') RET=0;} \
			END {print RET}'`
		if [ "$id_retval" = 0 ]; then
			(( d_index=$d_index+1 ))
			sleep 1
		else
			break
		fi
	done
	if [ $d_index -eq $time_out ]; then
		ptree $local_pid | sed -n "/$local_pid/,\$p" | awk '{print $1}'\
			| sort -r | while read proc_id
		do
			kill -9 $proc_id >/dev/null 2>&1
		done
		cti_report "WARNING - local $local_command timeout for "\
			"$time_out seconds was killed."  >> $CMD_STDERR
		echo "1" > $CMD_RETVAL
		return
	fi
        wait $local_pid >/dev/null 2>&1
        tail -1 $CMD_STDOUT > $CMD_RETVAL
        sed -e '$d' $CMD_STDOUT >/tmp/tmp
        mv /tmp/tmp $CMD_STDOUT	
}

#
# NAME
#	run_rsh_cmd
#
# DESCRIPTION
#	Since rsh is obsoleted, implementing ssh here
#	The stdout of command will be save at $CMD_STDOUT file.
#	The stderr of command will be save at $CMD_STDERR file.
#	The stdret of command will be save at $CMD_STDRET file.
#
# RETURN
#	remote stdout, stderr and return value is saved into 
#	local temporary files
#       void
#
function run_rsh_cmd
{
	rhost=$1
	rcmd=$2
	
	ssh -o "StrictHostKeyChecking no" $rhost "$rcmd" > /tmp/stdout 2> /tmp/stderr

	echo $? > $CMD_RETVAL
	cat /tmp/stdout > $CMD_STDOUT
	cat /tmp/stderr > $CMD_STDERR

	# Sleep some seconds here if needed
} 

#
# NAME
#       get_cmd_stdout
#
# DESCRIPTION
#       output the specified file with std out content
#
# RETURN
#       void
#
function get_cmd_stdout
{
	if [ -s $CMD_STDOUT ];then
		cat $CMD_STDOUT
	fi
}
#
# NAME
#       get_cmd_stderr
#
# DESCRIPTION
#       output the specified file with error content
#
# RETURN
#       void
#
function get_cmd_stderr
{
	if [ -s $CMD_STDERR ];then
		cat $CMD_STDERR
	fi
}
#
# NAME
#       get_cmd_retval
#
# DESCRIPTION
#       output the specified file with return code content
#
# RETURN
#       void
#
function get_cmd_retval
{
	if [ -s $CMD_RETVAL ];then
		cat $CMD_RETVAL
	else
		echo 999
	fi
}
#
# NAME
#       report_err
#
# DESCRIPTION
#       provide the formatted to print information 
#	when unexpected result returns
#
# RETURN
#       void
#
function report_err
{
	typeset l_cmd=$*
	if [ `get_cmd_retval` -eq 0 ];then
		cti_report "INFO with executing: $l_cmd"
	else
		cti_report "ERROR with executing: $l_cmd"
	fi
	cti_reportfile $CMD_RETVAL "Return Value"
	cti_reportfile $CMD_STDOUT "Standard Output"
	cti_reportfile $CMD_STDERR "Standard Error"
}

#
# NAME
#	POS_results
#
# DESCRIPTION:
#	Evaluate the results of a command that was expected return status of
#	zero.  If the command did not return status of zero print a
#	failure line to the journal containing fail_string, set tet_result
#	to FAIL.
#
#	$1 result to check
# 	$2 command line
#
function POS_result
{
	typeset Pr_result=$1
	typeset Pr_cmd=$2

	check_for_core $Pr_result 
	if [ $? -ne 0 ]
	then
		cti_report "FAIL - command failed but possibly due to corefile:"
		cti_report "	$Pr_cmd"
		cti_fail
	fi

	# Verify return code is 0
	if [ $Pr_result -ne 0 ]
	then
		cti_report "FAIL - $Pr_cmd"
		cti_fail
	fi
}

#
# NAME
#	NEG_results
#
# DESCRIPTION:
#	Evaluate the results of a command that was expected return non-zero
#	status.  If the command did not return non-zero status print a
#	failure line to the journal containing fail_string, set tet_result
#	to FAIL.
#
# 	$1 result to check
# 	$2 command line
#
function NEG_result
{
	typeset Nr_result=$1
	typeset Nr_cmd=$2

	#
	# Should check for core on NEG results just to make
	# sure the reason for failure was not a core dump,
	# because core dumps are bad.
	#
	check_for_core $Nr_result 
	if [ $? -ne 0 ]
	then
		cti_report "FAIL - command failed but possibly due to corefile:"
		cti_report "	$Nr_cmd"
		cti_fail
	fi

	# Verify return code is != 0
	if [ $Nr_result -eq 0 ]
	then
		cti_report "FAIL - command should have failed but succeeded:"
		cti_report "	$Nr_cmd"
		cti_fail
	fi
}

#
# NAME
#	check_for_core
#
# DESCRIPTION
# 	Check for the potential catastrophic failure of the command based
# 	on the result.
#
# RETURN
#	0 - if no core was found to be produced
#	1 - if a core was found to be produced
#
function check_for_core
{
	typeset cfc_retval=0

	# core dump=128, return code=core dump + signal. 
	# terminated by system probably.
	if [ $1 -ge 128 ]
	then
		tet_infoline "Core dump likely produced by the command."
		cfc_retval=1
	fi

	#
	# Check to see if the failure was due to the itadm, sbdadm and stmfadm falling
	# down, and producing a core.
	#
	core_check_and_save
	if [ $? -ne 0 ];then
		cfc_retval=1
	fi
	return $cfc_retval
}

#
# NAME
#	core_check_and_save
#
# DESCRIPTION
# 	Check for the core file and save into debug_files directory
#
# RETURN
#	0 - if no core was found to be produced
#	1 - if a core was found to be produced
#
function core_check_and_save
{
	typeset cfc_retval=0
	if [ -f /core ]; then
		file /core | grep sbd > /dev/null
		if [ $? -eq 0 ]; then
			mv /core $LOGDIR_TCCDLOG/core_sbdadm.$tc_id.$$
			cti_report "Core dump produced by the $SBDADM "
			cti_report "Saved core as "\
				"$LOGDIR_TCCDLOG/core_sbdadm.$tc_id.$$"
			cfc_retval=1
		fi
		file /core | grep stmf > /dev/null
		if [ $? -eq 0 ]; then
			mv /core $LOGDIR_TCCDLOG/core_smtfadm.$tc_id.$$
			cti_report "Core dump produced by the $STMFADM "
			cti_report "Saved core as "\
				"$LOGDIR_TCCDLOG/core_smtfadm.$tc_id.$$"
			cfc_retval=1
		fi
		file /core | grep itadm > /dev/null
		if [ $? -eq 0 ]; then
			mv /core $LOGDIR_TCCDLOG/core_itadm.$tc_id.$$
			cti_report "Core dump produced by the $ITADM "
			cti_report "Saved core as "\
				"$LOGDIR_TCCDLOG/core_itadm.$tc_id.$$"
			cfc_retval=1
		fi
	fi
	return cfc_retval
}

#
# NAME
#	run_generic_cmd
#
# DESCRIPTION
# 	The generic cli implementation method to judge the return value,
# 	print out the command information and its result.
#
# RETURN
#	0 - if no core was found to be produced
#	1 - if a core was found to be produced
#
function run_generic_cmd
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset cmd="$*"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`

	report_err "$cmd"

	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
	else
		NEG_result $retval "$cmd"
	fi
}

