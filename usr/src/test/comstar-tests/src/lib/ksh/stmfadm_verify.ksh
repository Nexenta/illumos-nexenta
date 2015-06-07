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
# This file contains common functions and is meant to be sourced into
# the test case files.  These functions are used to verify the 
# configuration and state of the resources in use.
#
#
# NAME
#	stmfadm_verify
# DESCRIPTION
#	Compare the actual object list to what the test suite 
#	thinks the object list should be.
#	It works like the factory method pattern.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify
{
	typeset object=$1
	case $object in
		"hg")
			stmfadm_verify_hg
		;;
		"tg")
			stmfadm_verify_tg
		;;
		"hg-member")
			stmfadm_verify_hg
		;;
		"tg-member")
			stmfadm_verify_tg
		;;
		"view")
			stmfadm_verify_view
		;;
		"lu")
			stmfadm_verify_lu
		;;
		"target")
			stmfadm_verify_target
		;;
		"initiator")
			stmfadm_verify_initiator
		;;
		*)
			cti_report "stmfadm_vefiy: unkown option - $object"
		;;
	esac
}

#
# NAME
#	stmfadm_verify_hg
# DESCRIPTION
#	Compare the actual host group list to what the test suite 
#	thinks the host group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_hg
{
	cti_report "Executing: stmfadm_verify_hg start"
	
	compare_hg
	
	for hg in $G_HG
	do
		compare_hg_member $hg
	done
	cti_report "Executing: stmfadm_verify_hg stop"
}

#
# NAME
#	compare_hg
# DESCRIPTION
#	Compare the actual host group list of specified host group to 
#	what the test suite thinks the 
#	host group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_hg
{
	typeset cmd="${STMFADM} list-hg"
	typeset HG_fnd=0	
	typeset chk_HGS=$G_HG
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		echo $line | grep "Host Group:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			HG_fnd=0
			chk_HG=`echo $line | awk '{print $NF}'`
			unset HG_list
			for chk_hg in $chk_HGS
			do 
				if [ "$chk_hg" = "$chk_HG" ];then
					HG_fnd=1
				else
					HG_list="$HG_list $chk_hg"
				fi
			done
			if [ $HG_fnd -eq 0 ];then
				cti_fail "WARNING: HG $chk_HG is in "\
					"listed output but not in stored info."
			fi
			chk_HGS="$HG_list"
		fi
	done

	if [ "$chk_HGS" ];then
		cti_fail "WARNING: HGS $chk_HGS are in "\
			"stored info but not in listed output."
	fi
}	

#
# NAME
#	compare_hg_member
# DESCRIPTION
#	Compare the actual host group member list of specified 
#	host group member to what the test suite thinks the 
#	host group member list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_hg_member
{
	typeset hg=$1
	typeset cmd="${STMFADM} list-hg -v $hg"
	typeset HG_fnd=0	
	typeset MEMBER_fnd=0
	eval chk_MEMBERS=\"\$HG_${hg}_member\"
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $HG_fnd -eq 0 ];then
			echo $line | grep "Host Group: $hg" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				HG_fnd=1
			fi
			continue
		fi
		echo $line | grep "Member:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			MEMBER_fnd=0
			chk_MEMBER=`echo $line | awk '{print $NF}'`
			unset MEMBER_list
			for chk_member in $chk_MEMBERS
			do 
				if [ "$chk_member" = "$chk_MEMBER" ];then
					MEMBER_fnd=1
				else
					MEMBER_list="$MEMBER_list $chk_member"
				fi
			done
			if [ $MEMBER_fnd -eq 0 ];then
				cti_fail "WARNING: HG-MEMBER $chk_MEMBER is in"\
					" listed output but not in stored info."
			fi
			chk_MEMBERS="$MEMBER_list"
		fi
	done

	if [ "$chk_MEMBERS" ];then
		cti_fail "WARNING: HG-MEMBERS $chk_MEMBERS are "\
			"in stored info but not in listed output."
	fi
}
			
#
# NAME
#	stmfadm_verify_tg
# DESCRIPTION
#	Compare the actual target group list to what the test suite 
#	thinks the target group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_tg
{
	cti_report "Executing: stmfadm_verify_tg start"
	
	compare_tg
	
	for tg in $G_TG
	do
		compare_tg_member $tg
	done
	cti_report "Executing: stmfadm_verify_tg stop"
}
#
# NAME
#	compare_tg
# DESCRIPTION
#	Compare the actual target group list of specified target group to 
#	what the test suite thinks the 
#	target group list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_tg
{
	typeset cmd="${STMFADM} list-tg"
	typeset TG_fnd=0	
	typeset chk_TGS=$G_TG
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		echo $line | grep "Target Group:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			TG_fnd=0
			chk_TG=`echo $line | awk '{print $NF}'`
			unset TG_list
			for chk_tg in $chk_TGS
			do 
				if [ "$chk_tg" = "$chk_TG" ];then
					TG_fnd=1
				else
					TG_list="$TG_list $chk_tg"
				fi
			done
			if [ $TG_fnd -eq 0 ];then
				cti_fail "WARNING: TG $chk_TG is in "\
					"listed output but not in stored info."
			fi
			chk_TGS="$TG_list"
		fi
	done

	if [ "$chk_TGS" ];then
		cti_fail "WARNING: TGS $chk_TGS are in stored info "\
			"but not in listed output."
	fi
}	

#
# NAME
#	compare_tg_member
# DESCRIPTION
#	Compare the actual target group member list of specified target group 
#	member to what the test suite thinks the 
#	target group member list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_tg_member
{
	typeset tg=$1
	typeset cmd="${STMFADM} list-tg -v $tg"
	typeset TG_fnd=0	
	typeset MEMBER_fnd=0
	eval chk_MEMBERS=\"\$TG_${tg}_member\"
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $TG_fnd -eq 0 ];then
			echo $line | grep "Target Group: $tg" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				TG_fnd=1
			fi
			continue
		fi
		echo $line | grep "Member:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			MEMBER_fnd=0
			chk_MEMBER=`echo $line | awk '{print $NF}'`
			unset MEMBER_list
			for chk_member in $chk_MEMBERS
			do 
				if [ "$chk_member" = "$chk_MEMBER" ];then
					MEMBER_fnd=1
				else
					MEMBER_list="$MEMBER_list $chk_member"
				fi
			done
			if [ $MEMBER_fnd -eq 0 ];then
				cti_fail "WARNING: TG-MEMBER $chk_MEMBER is in"\
					" listed output but not in stored info."
			fi
			chk_MEMBERS="$MEMBER_list"
		fi
	done

	if [ "$chk_MEMBERS" ];then
		cti_fail "WARNING: TG-MEMBERS $chk_MEMBERS are in stored info"\
			"but not in listed output."
	fi
}

#
# NAME
#	stmfadm_verify_view
# DESCRIPTION
#	Compare the actual logical unit list to what the test suite 
#	thinks the logical unit list should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_view
{
	cti_report "Executing: stmfadm_verify_view start"
	for vol in $G_VOL
	do
		eval compare_lu_view \$LU_${vol}_GUID
	done
	cti_report "Executing: stmfadm_verify_view stop"
}


#
# NAME
#	compare_lu_view
# DESCRIPTION
#	Compare the actual view list of specified logical unit to 
#	what the test suite thinks the 
#	view list should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_lu_view
{
	typeset guid=$1
	typeset cmd="${STMFADM} list-view -l $guid"
	typeset LU_fnd=0	
	typeset VIEW_fnd=0
	typeset FAIL=0
	eval chk_ENTRIES=\"\$VIEW_${guid}_entry\"
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | awk '{print $NF}' |\
		awk '{if (NR%4==0) printf("%s\n",$0);else printf("%s:",$0);}' |\
		while read line
	do
		VIEW_fnd=0
		chk_VIEW=`echo $line | awk '{print $NF}'`
		unset VIEW_list
		for chk_view in $chk_ENTRIES
		do 
			if [ "$chk_view" = "$chk_VIEW" ];then
				VIEW_fnd=1
			else
				VIEW_list="$VIEW_list $chk_view"
			fi
		done
		if [ $VIEW_fnd -eq 0 ];then
			cti_fail "WARNING: VIEW-ENTRY $chk_VIEW is "\
				"in listed output but not in stored info."
			(( FAIL+=1 ))
		fi
		chk_ENTRIES="$VIEW_list"
	done

	if [ "$chk_ENTRIES" ];then
		cti_fail "WARNING: VIEW-ENTRIES $chk_ENTRIES are "\
			"in stored info but not in listed output."
		(( FAIL+=1 ))
	fi
	if [ $FAIL -ne 0 ];then
		cti_report "LU view comparison encountered unexpected output, "\
		    "the detailed output is below:"
		report_err "$cmd"
	fi
}
#
# NAME
#	stmfadm_verify_target
# DESCRIPTION
#	Compare the actual target online/offline state to 
#	what the test suite thinks the target online/offline should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_target
{
	cti_report "Executing: stmfadm_verify_target start"
	for target in $G_TARGET
	do
		compare_target_state $target
	done
	cti_report "Executing: stmfadm_verify_target stop"
}

#
# NAME
#	compare_target_state
# DESCRIPTION
#	Compare the actual online/offline state of specified target to 
#	what the test suite thinks the 
#	target state should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_target_state
{
	typeset target=$1
	typeset cmd="${STMFADM} list-target -v $target"
	typeset TARGET_fnd=0	
	typeset MEMBER_fnd=0
	typeset FAIL=0
	unset chk_MEMBERS
	for portWWN in $G_TARGET
	do
                typeset t_portWWN=$(format_shellvar $portWWN)
                eval online=\$TARGET_${t_portWWN}_ONLINE
		if [ "$online" = "Y" -a "$target" = "$portWWN" ];then
			chk_MEMBERS="$portWWN"
			break
		fi
	done
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $TARGET_fnd -eq 0 ];then
			echo $line | grep "Target:" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				TARGET_fnd=1
			fi
			continue
		fi
		echo $line | grep "Operational Status:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			MEMBER_fnd=0
			echo $line | grep -i online >/dev/null 2>&1
			if [ $? -eq 0 ];then
				chk_MEMBER=$target
			else
				break
			fi
			unset MEMBER_list
			for chk_member in $chk_MEMBERS
			do 
				typeset -u chk_member=$chk_member
				typeset -u chk_MEMBER=$chk_MEMBER
				if [ "$chk_member" = "$chk_MEMBER" ];then
					MEMBER_fnd=1
				else
					MEMBER_list="$MEMBER_list $chk_member"
				fi
			done
			if [ $MEMBER_fnd -eq 0 ];then
				cti_fail "WARNING: ONLINE-TARGET $chk_MEMBER "\
					"is in listed output "\
					"but not in stored info."
				(( FAIL+= 1))
			fi
			chk_MEMBERS="$MEMBER_list"
		fi
	done

	if [ "$chk_MEMBERS" ];then
		cti_fail "WARNING: ONLINE-TARGET $chk_MEMBERS are "\
			"in stored info but not in listed output."
		(( FAIL+= 1))
	fi
	if [ $FAIL -ne 0 ];then
		cti_report "target online/offline state comparison encountered unexpected "\
		    "output, the detailed output is below:"
		report_err "$cmd"
	fi
}
#
# NAME
#	stmfadm_verify_lu
# DESCRIPTION
#	Compare the actual logical unit online/offline state to 
#	what the test suite thinks the logical unit online/offline should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_lu
{
	cti_report "Executing: stmfadm_verify_lu start"
	for vol in $G_VOL
	do
		#GUID is not case sensitive
		eval compare_lu_state \$LU_${vol}_GUID
	done
	cti_report "Executing: stmfadm_verify_lu stop"
}
#
# NAME
#	compare_lu_state
# DESCRIPTION
#	Compare the actual online/offline state of specified logical unit 
#	to what the test suite thinks the 
#	logical unit state should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_lu_state
{
	typeset guid=$1
	typeset cmd="${STMFADM} list-lu -v $guid"
	typeset LU_fnd=0	
	typeset MEMBER_fnd=0
	unset chk_MEMBERS
	for vol in $G_VOL
	do
		eval typeset t_guid=\$LU_${vol}_GUID
		eval typeset -u u_guid=$t_guid	
		eval online=\$LU_${u_guid}_ONLINE
		if [ "$online" = "Y" -a "$guid" = "$t_guid" ];then
			chk_MEMBERS="$t_guid"
			break
		fi
	done
	run_ksh_cmd "$cmd" 
	get_cmd_stdout | while read line
	do
		if [ $LU_fnd -eq 0 ];then
			echo $line | grep "LU Name:" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				LU_fnd=1
			fi
			continue
		fi
		echo $line | grep "Operational Status:" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			MEMBER_fnd=0
			echo $line | grep -i online >/dev/null 2>&1
			if [ $? -eq 0 ];then
				chk_MEMBER=$guid
			else
				break
			fi
			unset MEMBER_list
			for chk_member in $chk_MEMBERS
			do 
				typeset -l chk_member=$chk_member
				typeset -l chk_MEMBER=$chk_MEMBER
				if [ "$chk_member" = "$chk_MEMBER" ];then
					MEMBER_fnd=1
				else
					MEMBER_list="$MEMBER_list $chk_member"
				fi
			done
			if [ $MEMBER_fnd -eq 0 ];then
				cti_fail "WARNING: ONLINE-LU $chk_MEMBER is in"\
					" listed output but not in stored info."
			fi
			chk_MEMBERS="$MEMBER_list"
		fi
	done

	if [ "$chk_MEMBERS" ];then
		cti_fail "WARNING: ONLINE-LU $chk_MEMBERS are in stored info "\
			"but not in listed output."
	fi
}

#
# NAME
#	stmfadm_verify_initiator
# DESCRIPTION
#	Compare the actual logical unit online/offline state to 
#	what the test suite thinks the logical unit online/offline should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_initiator
{
	if [ "$TARGET_TYPE" = "FC" ];then
		stmfadm_verify_fc_initiator $FC_IHOST
	elif [ "$TARGET_TYPE" = "FCOE" ];then
		stmfadm_verify_fc_initiator $FC_IHOST
	elif [ "$TARGET_TYPE" = "ISCSI" ];then
		stmfadm_verify_iscsi_initiator $ISCSI_IHOST
	else
		cti_unresolved "WARNING - un-defined variable TARGET_TYPE:"\
		    "$TARGET_TYPE. Please re-configure the configuration file"
	fi
}


#
# NAME
#	stmfadm_verify_fc_initiator
# DESCRIPTION
#	Compare the actual logical unit online/offline state to 
#	what the test suite thinks the logical unit online/offline should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_fc_initiator
{
	typeset INITIATOR_HOST=$1
	cti_report "Executing: stmfadm_verify_fc_initiator start"
	stmfadm_visible_info

	check_enable_mpxio $INITIATOR_HOST
	if [ $? -eq 0 ];then
		host_reboot $FC_IHOST -r
	else
		stmsboot_enable_mpxio $INITIATOR_HOST
	fi
	
	leadville_bug_trigger $INITIATOR_HOST
		
	typeset hostname=`format_shellvar $INITIATOR_HOST`
	eval typeset initiator_list="\$HOST_${hostname}_INITIATOR"		

	search_valid_i_port $INITIATOR_HOST "$initiator_list"
	cti_report "Executing: stmfadm_verify_fc_initiator stop"
}

#
# NAME
#	stmfadm_verify_iscsi_initiator
# DESCRIPTION
#	Compare the actual logical unit online/offline state to 
#	what the test suite thinks the logical unit online/offline should be.
#
# RETURN
#	Sets the result code
#	void
#
function stmfadm_verify_iscsi_initiator
{
	typeset INITIATOR_HOST=$1
	cti_report "Executing: stmfadm_verify_iscsi_initiator start"
	stmfadm_visible_info

	iscsiadm_verify $ISCSI_IHOST lun
	
	cti_report "Executing: stmfadm_verify_iscsi_initiator stop"
}

#
# NAME
#	search_valid_i_port
# DESCRIPTION
#	Search for the valid initiator port to compare the 
#	the LU visibility only on fc configuration.
#
# RETURN
#	Sets the result code
#	void
#
function search_valid_i_port
{
	typeset INITIATOR_HOST=$1
	typeset initiator_list="$2"
	typeset i_portWWN

	for i_portWWN in $initiator_list
	do
		typeset iport=`format_shellvar $i_portWWN`
		eval typeset i_state="\$INITIATOR_${iport}_ONLINE"
		if [ "$i_state" = "Y" ];then
			search_valid_t_port $INITIATOR_HOST $i_portWWN
		fi
	done
}
#
# NAME
#	search_valid_t_port
# DESCRIPTION
#	Search for the valid target port to compare the 
#	the LU visibility only on fc configuration.
#
# RETURN
#	Sets the result code
#	void
#
function search_valid_t_port
{
	typeset INITIATOR_HOST=$1
	typeset i_portWWN=$2
	typeset t_portWWN
	for t_portWWN in $G_TARGET
	do
		typeset tport=`format_shellvar $t_portWWN`			
		eval typeset t_state="\$TARGET_${tport}_ONLINE"
		if [ "$t_state" = "Y" ];then
			compare_fc_initiator_lu $INITIATOR_HOST $i_portWWN $t_portWWN
		fi
	done
}
#
# NAME
#	leadville_bug_trigger
# DESCRIPTION
#	Due to leadville bug, test suite has to trigger the 
#	fcinfo -p -s twice to discovery the LU creation
#
# RETURN
#	Sets the result code
#	void
#
function leadville_bug_trigger
{
	typeset FC_IHOST=$1
	cti_report "Executing: leadville_bug_trigger start on $FC_IHOST"
	typeset hostname=`format_shellvar $FC_IHOST`
	eval typeset initiator_list="\$HOST_${hostname}_INITIATOR"
	
	# leadville bug to trigger the discovery start
	typeset cmd="$LUXADM -e port | awk '{print \$1}' | while read device;"
	cmd="$cmd do $LUXADM -e forcelip \$device; done"
	run_rsh_cmd $FC_IHOST "$cmd" 		
	sleep 3
	for i_portWWN in $initiator_list
	do
		typeset iport=`format_shellvar $i_portWWN`
		eval typeset i_state="\$INITIATOR_${iport}_ONLINE"
		if [ "$i_state" = "Y" ];then
			# leadville bug to trigger the discovery start
			typeset f_iport=`echo $i_portWWN | cut -d. -f2-`
			typeset cmd="$FCINFO remote-port -p $f_iport -s"
			run_rsh_cmd $FC_IHOST "$cmd" 
			sleep 3
			typeset cmd="$FCINFO remote-port -p $f_iport -s"
			run_rsh_cmd $FC_IHOST "$cmd" 
			sleep 3
			# trigger end
		fi
	done
	cti_report "Executing: leadville_bug_trigger stop on $FC_IHOST"
}

#
# NAME
#	compare_fc_initiator_lu
# DESCRIPTION
#	Compare the logical unit from the initiator host side to 
#	what the test suite thinks the 
#	logical unit state should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_fc_initiator_lu
{
	typeset hostname=$1
	typeset iport=$2
	typeset tport=$3
	typeset TG_fnd=0	
	typeset MEMBER_fnd=0
	typeset i_port=`format_shellvar $iport`
	typeset t_port=`format_shellvar $tport`	
	eval chk_MEMBERS=\"\$VISIBLE_${i_port}_${t_port}_GUID\"

	iport=`echo $iport | cut -d. -f2-`
	tport=`echo $tport | cut -d. -f2-`
	cti_report "Verify the visibility by FC INITIATOR HOST: $hostname "\
		"Initiator PORT: $iport Target PORT: $tport"
	cmd="$FCINFO remote-port -p $iport -s $tport"
	run_rsh_cmd $hostname "$cmd" 
	report_err "$cmd"	
	get_cmd_stdout | while read line
	do
		if [ $TG_fnd -eq 0 ];then
			echo $line | grep "Remote Port WWN:" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				TG_fnd=1
			fi
			continue
		fi
		echo $line | grep "OS Device Name: \/dev" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			MEMBER_fnd=0
			chk_MEMBER=`echo $line | awk -F/ '{print $NF}'`
			unset MEMBER_list
			for chk_member in $chk_MEMBERS
			do 
				echo $chk_MEMBER | grep -i $chk_member \
					>/dev/null 2>&1				
				if [ $? -eq 0 ];then
					MEMBER_fnd=1
				else
					MEMBER_list="$MEMBER_list $chk_member"
				fi
			done
			if [ $MEMBER_fnd -eq 0 ];then
				cti_fail "WARNING: Device $chk_MEMBER is in "\
					"listed output on FC Initiator "\
					"but not masked in FC Target."
			fi
			chk_MEMBERS="$MEMBER_list"
		fi
	done

	if [ "$chk_MEMBERS" ];then
		cti_fail "WARNING: Devices $chk_MEMBERS are masked "\
			"in FC Target but not in listed output on FC Initiator."
	fi
}
#
# NAME
#	compare_iscsi_initiator_lu
# DESCRIPTION
#	Compare the logical unit from the initiator host side to 
#	what the test suite thinks the 
#	logical unit state should be.
#
# RETURN
#	Sets the result code
#	void
#
function compare_iscsi_initiator_lu
{
	:
}
#
# NAME
#	stmfadm_visible_info
# DESCRIPTION
# 	Store information about initiator-lu association based on information
# 	passed to the function as arguments.
#
# RETURN
#	void
#
function stmfadm_visible_info
{
	# this round is to build which GUIDs can be accessed by TG and HG 
	# combination with LU online condition
	for tg in $G_TG All
	do
		for hg in $G_HG All
		do
			# make sure to rebuild the visiblity 
			eval unset VISIBLE_${hg}_${tg}_GUID
			
			eval tg_guid_list="\$TG_${tg}_guid"
			eval hg_guid_list="\$HG_${hg}_guid"
			for tg_guid_iter in $tg_guid_list
			do
				for hg_guid_iter in $hg_guid_list
				do
					build_group_guid $tg $hg \
						$tg_guid_iter $hg_guid_iter
				done
			done
		done
	done
	# this round is to build which GUIDs can be accessed by 
	# INITIATOR and TARGET combination with both port online condition

	for tg in $G_TG All
	do
		for hg in $G_HG All
		do			
			if [ "$TARGET_TYPE" = "FC" ];then
				build_port_guid $FC_IHOST $hg $tg
			elif [ "$TARGET_TYPE" = "FCOE" ];then
				build_port_guid $FC_IHOST $hg $tg
			elif [ "$TARGET_TYPE" = "ISCSI" ];then
				build_port_guid $ISCSI_IHOST $hg $tg
			else
				cti_unresolved "WARNING - un-defined variable TARGET_TYPE:"\
				    "$TARGET_TYPE. Please re-configure the configuration file"
			fi		
		done
	done
			
}
#
# NAME
#	build_group_guid
# DESCRIPTION
# 	build the visible guid list under 
#	the specified host group and target group.
#
# RETURN
#	void
#
function build_group_guid
{
	typeset tg=$1
	typeset hg=$2
	typeset tg_guid_iter=$3
	typeset hg_guid_iter=$4
	if [ "$tg_guid_iter" = "$hg_guid_iter" ];then
		#all the initiator
		typeset -u t_tg_guid_iter=$tg_guid_iter
		eval guid_online="\$LU_${t_tg_guid_iter}_ONLINE"
		if [ "$guid_online" = "N" ];then
			return
		fi
		eval VISIBLE_${hg}_${tg}_GUID="\${VISIBLE_${hg}_${tg}_GUID:=''}"
		eval guid_list="\$VISIBLE_${hg}_${tg}_GUID"
		guid_list=`trunc_space "$guid_list"`
		echo $guid_list | grep -w $tg_guid_iter > /dev/null 2>&1
		if [ $? -ne 0 ];then
			eval VISIBLE_${hg}_${tg}_GUID=\"$tg_guid_iter $guid_list\"
		fi
	fi
}
#
# NAME
#	build_port_guid
# DESCRIPTION
# 	build the visible guid list under 
#	the specified initiator port and target port.
#
# RETURN
#	void
#

function build_port_guid
{
	typeset HOSTNAME="$1"
	typeset hg="$2"
	typeset tg="$3"
	eval guid_list="\$VISIBLE_${hg}_${tg}_GUID"
	if [ -n "$guid_list" ];then			
		eval tg_member_list="\$TG_${tg}_member"
		eval hg_member_list="\$HG_${hg}_member"
		if [ "$hg" = "All" ];then
			unset hg_member_list
			typeset hostname=`format_shellvar $HOSTNAME`
			eval initiators="\$HOST_${hostname}_INITIATOR"
			hg_member_list="$initiators $hg_member_list"
		fi
		if [ "$tg" = "All" ];then
			tg_member_list="$G_TARGET"
		fi
		if [ -z "$tg_member_list" -o -z "$hg_member_list" ];then
			continue
		fi
		build_iport_tport_guid \
			"$hg_member_list" "$tg_member_list" "$guid_list"
	fi
}
# NAME
#	build_iport_tport_guid
# DESCRIPTION
# 	build the visible guid list under the specified 
#	initiator port and target port and write to log file
#
# RETURN
#	void
#
function build_iport_tport_guid
{
	typeset hg_member_list="$1"
	typeset tg_member_list="$2"
	typeset guid_list="$3"

	for tg_member_iter in $tg_member_list
	do			
		for hg_member_iter in $hg_member_list
		do
			typeset tport=`format_shellvar $tg_member_iter`
			typeset hport=`format_shellvar $hg_member_iter`
			eval unset VISIBLE_${hport}_${tport}_GUID

			eval tport_online="\$TARGET_${tport}_ONLINE"
				
			eval iport_online="\$INITIATOR_${hport}_ONLINE"						
			if [ "$tport_online" = "Y" \
				-a "$iport_online" = "Y" ];then
				eval VISIBLE_${hport}_${tport}_GUID="\${VISIBLE_${hport}_${tport}_GUID:=''}"			
				eval t_guid_list="\$VISIBLE_${hport}_${tport}_GUID"
				typeset tmp=`echo $guid_list $t_guid_list | \
					tr ' ' '\n' | sort -u | tr '\n' ' '`
				tmp=`trunc_space "$tmp"`
				eval VISIBLE_${hport}_${tport}_GUID=\"$tmp\"
				eval cti_report \
					"VISIBLE_${hport}_${tport}_GUID=$tmp"
			fi
		done
	done
}
