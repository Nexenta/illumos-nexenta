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

set -A VOL	vol0 vol1 vol2 vol3 vol4
set -A HG 	hg0 hg1 hg2 hg3 hg4
set -A TG 	tg0 tg1 tg2 tg3 tg4
set -A INITIATOR initiator0 initiator1 initiator2 initiator3 initiator4
set -A TARGET target0 target1 target2 target3 target4

IQN_INITIATOR=iqn.1986-03.com.sun:01:initiator
IQN_TARGET=iqn.1986-03.com.sun:02:target

LOGDIR=${LOGDIR:=/var/tmp/comstar_log}

SETCHAPSECRET_ksh="${CTI_SUITE}/bin/modify_chap_secret_ksh"
SETRADIUSSECRET_ksh="${CTI_SUITE}/bin/modify_radius_secret_ksh"
SETCHAPSECRET_rsh="${CTI_SUITE}/bin/modify_chap_secret_rsh"

. ${CTI_SUITE}/lib/comstar_init
. ${CTI_SUITE}/lib/comstar_io
. ${CTI_SUITE}/lib/comstar_fs
. ${CTI_SUITE}/lib/comstar_tcc
. ${CTI_SUITE}/lib/comstar_smf
. ${CTI_SUITE}/lib/comstar_fcoe
. ${CTI_SUITE}/lib/fcoet_smf
. ${CTI_SUITE}/lib/comstar_cmd
. ${CTI_SUITE}/lib/comstar_host
. ${CTI_SUITE}/lib/comstar_mpxio
. ${CTI_SUITE}/lib/comstar_fault
. ${CTI_SUITE}/lib/comstar_utils
. ${CTI_SUITE}/lib/comstar_unix_cmd
. ${CTI_SUITE}/lib/comstar_syslog

. ${CTI_SUITE}/lib/sbdadm_command
. ${CTI_SUITE}/lib/sbdadm_info
. ${CTI_SUITE}/lib/sbdadm_verify

. ${CTI_SUITE}/lib/stmfadm_command
. ${CTI_SUITE}/lib/stmfadm_info
. ${CTI_SUITE}/lib/stmfadm_verify

. ${CTI_SUITE}/lib/fc_host_cablepull
. ${CTI_SUITE}/lib/fc_target_cablepull
. ${CTI_SUITE}/lib/iscsi_host_cablepull
. ${CTI_SUITE}/lib/iscsi_target_cablepull
. ${CTI_SUITE}/lib/switch_fault

. ${CTI_SUITE}/lib/syntax_auto

. ${CTI_SUITE}/lib/itadm_command
. ${CTI_SUITE}/lib/itadm_info
. ${CTI_SUITE}/lib/itadm_verify
. ${CTI_SUITE}/lib/itadm_smf

. ${CTI_SUITE}/lib/iscsiadm_command
. ${CTI_SUITE}/lib/iscsiadm_info
. ${CTI_SUITE}/lib/iscsiadm_verify
. ${CTI_SUITE}/lib/iscsiadm_smf
. ${CTI_SUITE}/lib/iscsiadm_global

. ${CTI_SUITE}/lib/iscsitadm_smf
. ${CTI_SUITE}/lib/isnsadm_smf
. ${CTI_SUITE}/lib/portal_utils

#
# NAME
#	print_test_case
#
# DESCRIPTION
#	Print the test case name to the results formatted to fit with
#	60 characters.
# 
# RETURN
#	void
#
function print_test_case
{
	unset ptc_short_info
	ptc_info="Test case $*"

	cti_report "==================================================="

	if [ `echo $ptc_info | $WC -c` -gt 60 ]
	then
		#
		# Split the line
		#
		ptc_ltrcnt=0
		for ptc_word in $ptc_info
		do
			if [ "$ptc_word" = "\n" ]
			then
				cti_report "$ptc_short_info"
				ptc_short_info=""
				ptc_ltrcnt=0
				continue
			fi

			ptc_wordsz=`echo $ptc_word | $WC -c`
			ptc_ltrcnt=`$EXPR $ptc_ltrcnt + $ptc_wordsz + 1`
			if [ $ptc_ltrcnt -gt 60 ]
			then
				cti_report "$ptc_short_info"
				ptc_short_info=" $ptc_word"
				ptc_ltrcnt=`$EXPR $ptc_wordsz`
			else
				ptc_short_info="$ptc_short_info $ptc_word"
			fi
		done
		if [ $ptc_ltrcnt -gt 0 ]
		then
			cti_report "$ptc_short_info"
		fi
	else
		cti_report "$ptc_info"
	fi

	cti_report "==================================================="
}

#
# NAME
#	tp_cleanup
#
# DESCRIPTION
# 	it's an uniform interface for test environment cleanup,
#	its inlined interface depends upon the target type which is 
#	defined in the config file.
#
# RETURN
#	void
#
function tp_cleanup
{
	if [ "$TARGET_TYPE" = "FC" ];then
		tp_fc_cleanup
	elif [ "$TARGET_TYPE" = "FCOE" ];then
		tp_fcoe_cleanup
	elif [ "$TARGET_TYPE" = "ISCSI" ];then
		tp_iscsi_cleanup
	else
		cti_unresolved "UNRESOLVED - un-defined variable TARGET_TYPE:"\
		    "$TARGET_TYPE. Please re-configure the configuration file"
	fi
}

#
# NAME
#	tp_fcoe_cleanup
#
# DESCRIPTION
# 	Delete all the existing elements relating to fcoe targets
#	Check whether there is core file dumped after tp ends
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function tp_fcoe_cleanup
{
	cti_report "-----------------------------"
	cti_report "fcoe_cleanup test purpose is cleaning up itself"
	typeset cfc_retval=0

        FCOE_DOIO=${FCOE_DOIO:-${FCOEDOIO}}
	if [ $FCOE_DOIO -ne 0 ];then	
		env_stmf_cleanup
		(( cfc_retval+=$? ))
		env_sbd_cleanup
		(( cfc_retval+=$? ))
	fi
	fcoe_cleanup_ports	
	(( cfc_retval+=$? ))
	core_check_and_save
	(( cfc_retval+=$? ))
	if [ $cfc_retval -ne 0 ];then
		cti_unresolved "UNRESOLVED - fcoe cleanup return value"
		    ": $cfc_retval"
		cfc_retval=1
	fi
	return cfc_retval
}

#
# NAME
#	tp_fc_cleanup
#
# DESCRIPTION
# 	Delete all the existing elements relating to fc targets
#	Check whether there is core file dumped after tp ends
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function tp_fc_cleanup
{
	cti_report "-----------------------------"
	cti_report "fc test purpose is cleaning up itself"
	typeset cfc_retval=0

	env_stmf_cleanup
	(( cfc_retval+=$? ))
	env_sbd_cleanup
	(( cfc_retval+=$? ))
	core_check_and_save
	(( cfc_retval+=$? ))
	if [ $cfc_retval -ne 0 ];then
		cti_unresolved "UNRESOLVED - fc cleanup return value"
		    ": $cfc_retval"
		cfc_retval=1
	fi
	return cfc_retval
}

#
# NAME
#	env_sbd_cleanup
#
# DESCRIPTION
# 	Delete all the existing luns
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function env_sbd_cleanup
{
	typeset ret_code=0
	# clean up the persistent data 
	typeset CMD="$SBDADM list-lu"
	run_ksh_cmd "$CMD"
	get_cmd_stdout | grep "Found 0 LU(s)" >/dev/null 2>&1
	if [ $? -ne 0 ];then
		get_cmd_stdout | sed -n '6,$p' | awk '{print $1}' | \
			while read guid
		do
			typeset CMD="$SBDADM delete-lu $guid"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi
		done
	fi		
	typeset CMD="$SBDADM list-lu"
	run_ksh_cmd "$CMD"
	get_cmd_stderr | grep "Failed to load" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		get_cmd_stderr | awk '{print $1}' | \
			while read guid
		do
			typeset CMD="$SBDADM delete-lu $guid"
			run_ksh_cmd "$CMD"
			cti_report "cleaning by : $CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi
		done
	fi		
	if [ $ret_code -ne 0 ];then
		cti_report "WARNING - sbd environment cleanup failed."
	fi
	return ret_code
}
#
# NAME
#	env_stmf_cleanup
#
# DESCRIPTION
# 	Delete all the existing elements relating to comstar framework
#	The objects are including hostgroup, target group and view
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function env_stmf_cleanup
{
	typeset ret_code=0
	
	# clean up the stmf smf data
	stmf_smf_disable
	(( ret_code+=$? ))
	
	typeset CMD="$STMFADM list-lu"
	run_ksh_cmd "$CMD"
        get_cmd_stdout | grep "LU Name:" >/dev/null 2>&1
        if [ $? -eq 0 ];then
                get_cmd_stdout | awk '{print $NF}' | while read guid
                do
			CMD="$STMFADM list-lu -v $guid"
			run_ksh_cmd "$CMD"
                        typeset count=`get_cmd_stdout | \
                                grep "View Entry Count" | awk '{print $NF}'`
                        if [ $count -ne 0 ];then
                                typeset -l l_guid=$guid
				CMD="$STMFADM remove-view -l $l_guid -a"
				cti_report "cleaning by : $CMD"
				run_ksh_cmd "$CMD"
				if [ `get_cmd_retval` -ne 0 ];then
					(( ret_code+=`get_cmd_retval` ))
					report_err "$CMD"
				fi
                        fi
                done
        fi

	typeset CMD="$STMFADM list-hg"
	run_ksh_cmd "$CMD"
        get_cmd_stdout | grep "Host Group:" >/dev/null 2>&1
        if [ $? -eq 0 ];then
                get_cmd_stdout | awk '{print $NF}' | while read hostgroup
                do
			typeset CMD="$STMFADM list-hg -v $hostgroup"
			run_ksh_cmd "$CMD"
                        get_cmd_stdout | grep "Member:" | awk '{print $NF}' | \
                                while read member
                        do
				typeset CMD="$STMFADM remove-hg-member"
				CMD="$CMD -g $hostgroup $member"
				cti_report "cleaning by : $CMD"
				run_ksh_cmd "$CMD"
				if [ `get_cmd_retval` -ne 0 ];then
					(( ret_code+=`get_cmd_retval` ))
					report_err "$CMD"
				fi
                        done
			typeset CMD="$STMFADM delete-hg $hostgroup"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi
                done
        fi

	typeset CMD="$STMFADM list-tg"
	run_ksh_cmd "$CMD"
        get_cmd_stdout | grep "Target Group:" >/dev/null 2>&1
        if [ $? -eq 0 ];then
                get_cmd_stdout | awk '{print $NF}' | while read targetgroup
                do
			typeset CMD="$STMFADM list-hg -v $targetgroup"
			run_ksh_cmd "$CMD"
                        get_cmd_stdout | grep "Member:" | awk '{print $NF}' | \
                                while read member
                        do
				typeset CMD="$STMFADM remove-tg-member"
				CMD="$CMD -g $targetgroup $member"
				cti_report "cleaning by : $CMD"
				run_ksh_cmd "$CMD"
				if [ `get_cmd_retval` -ne 0 ];then
					(( ret_code+=`get_cmd_retval` ))
					report_err "$CMD"
				fi
                        done
			typeset CMD="$STMFADM delete-tg $targetgroup"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi
                done
        fi
        
	stmf_smf_enable
	(( ret_code+=$? ))

        if [ $ret_code -ne 0 ];then
                cti_report "WARNING - stmf environment cleanup failed."
        fi

	return ret_code
}
#
# NAME
#	env_iscsi_cleanup
#
# DESCRIPTION
# 	Delete all the existing elements relating to iscsi targets
#	The objects are including target, tpgt and initiaotr
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function env_iscsi_cleanup
{
	typeset ret_code=0
	# clean up the persistent data 

	typeset CMD="$ITADM list-target"
	run_ksh_cmd "$CMD"
	get_cmd_stdout | grep "TARGET NAME" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		get_cmd_stdout | sed -n '2,$p' | awk '{print $1}' | \
			while read node_name
		do
			typeset CMD="$ITADM delete-target -f $node_name"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi	
		done
	fi	
	typeset CMD="$ITADM list-tpg"
	run_ksh_cmd "$CMD"
	get_cmd_stdout | grep "TARGET PORTAL GROUP" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		get_cmd_stdout | sed -n '2,$p' | awk '{print $1}' | \
			while read tpg_tag
		do
			typeset CMD="$ITADM delete-tpg $tpg_tag"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi	
		done
	fi	
	typeset CMD="$ITADM list-initiator"
	run_ksh_cmd "$CMD"
	get_cmd_stdout | grep "INITIATOR NAME" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		get_cmd_stdout | sed -n '2,$p' | awk '{print $1}' | \
			while read node_name
		do
			typeset CMD="$ITADM delete-initiator $node_name"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ];then
				(( ret_code+=`get_cmd_retval` ))
				report_err "$CMD"
			fi	
		done
	fi	

        if [ $ret_code -ne 0 ];then
                cti_report "WARNING - iscsit environment cleanup failed."
        fi

	return ret_code
}
#
# NAME
#	env_iscsi_defaults_cleanup
#
# DESCRIPTION
# 	Delete all the existing default settings
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function env_iscsi_defaults_cleanup
{
	typeset ret_code=0

	typeset CMD="$ITADM modify-defaults -a none"
	cti_report "cleaning by : $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		(( ret_code+=`get_cmd_retval` ))
		report_err "$CMD"
	fi	
	typeset CMD="$ITADM modify-defaults -r none"
	cti_report "cleaning by : $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		(( ret_code+=`get_cmd_retval` ))
		report_err "$CMD"
	fi	
	typeset CMD="$ITADM modify-defaults -i disable"
	cti_report "cleaning by : $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		(( ret_code+=`get_cmd_retval` ))
		report_err "$CMD"
	fi	
	typeset CMD="$ITADM modify-defaults -I none"
	cti_report "cleaning by : $CMD"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		(( ret_code+=`get_cmd_retval` ))
		report_err "$CMD"
	fi	
        if [ $ret_code -ne 0 ];then
                cti_report "WARNING - iscsit default environment cleanup failed."
        fi

	return ret_code

}
#
# NAME
#	tp_iscsi_cleanup
#
# DESCRIPTION
# 	Delete all the existing elements relating to iscsi targets
#	Check whether there is core file dumped after tp ends
#
# RETURN
#	0 - environment is cleaned successfully
#	!0 - environment is not cleaned successfully
#
function tp_iscsi_cleanup
{
	cti_report "-----------------------------"
	cti_report "iscsi test purpose is cleaning up itself"
	typeset cfc_retval=0

	env_iscsi_cleanup
	(( cfc_retval+=$? ))
	env_iscsi_defaults_cleanup
	(( cfc_retval+=$? ))
	env_stmf_cleanup
	(( cfc_retval+=$? ))
	env_sbd_cleanup
	(( cfc_retval+=$? ))

	core_check_and_save
	(( cfc_retval+=$? ))

	if [ $cfc_retval -ne 0 ];then
		cti_unresolved "UNRESOLVED - iscsi cleanup return value : $cfc_retval"
		cfc_retval=1
	fi
	return cfc_retval
}

