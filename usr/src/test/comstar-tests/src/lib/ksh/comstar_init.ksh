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
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

# NAME
#       comstar_startup_fcoe_target()
# DESCRIPTION
#       generic startup processes of fcoe target for comstar
#	Following steps are I/O related only
#	zfs create (Note: the fcoet test machine prerequisite is mount / on
#	zfs filesystem, so skip the create zfs pool step)
#	sbdadm create-lu
#	stmfadm mapping
#	fcadm create-fcoe-port
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_fcoe_target
{
	comstar_startup
	if [ $? -ne 0 ];then
		cti_uninitiated "comstar framework is not ready, aborting"
		cti_deleteall "comstar framework missed!"
		return 1
	fi	
	typeset sorted_modules="stmf_sbd stmf"
	cti_report "check for $sorted_modules modules"
	for module in $sorted_modules
	do
		typeset real_module=$($MODINFO | $AWK '{if($6=="'"$module"'") print $6}')
		if [ "$real_module" != "$module" ];then
			cti_uninitiated "modules $module is not loaded, aborting"
			cti_deleteall "$sorted_modules missed!"
			return 1
		fi		
	done

	#build available NIC interface which are FCoE supported
	if [ "X$G_INTERFACE" = "X" ];then
		build_g_fcoe_netinterface
	fi		

	#if FCOE_DOIO IS 1, then fcoe port involved I/O operation	
        FCOE_DOIO=${FCOE_DOIO:-${FCOEDOIO}}
	if [ $FCOE_DOIO -ne 0 ];then	
		# Enable stmf smf service
		stmf_smf_enable
		# Prepare for I/O 
		FCOE_VISIBLE=${FCOE_VISIBLE:-${FCOEVISIBLE}}
		if [ $FCOE_VISIBLE -ne 0 ];then
			create_default_lun
			build_full_mapping
		fi
		fcoe_create_ports

		sleep 5
		online_target_found=0
		cti_report "check available fcoe ports on fcoe target."
		CMD="$FCINFO hba-port -e | grep -c -i online"
		run_ksh_cmd "$CMD"
		if [ `get_cmd_stdout` -eq 0 ];then
			report_err "$CMD"		
			cti_uninitiated "target host has no online fcoe port, aborting"
			cti_deleteall "fcoe target no online port!"
			return 1
		fi
		CMD="$FCINFO hba-port -e"
		run_ksh_cmd "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			get_cmd_stdout | grep "HBA Port WWN" | awk '{print $NF}' | \
				while read portWWN
			do
				build_g_fc_target $portWWN
			done
		else
			report_err "$CMD"		
			cti_uninitiated "target host can not iterate "\
				"the fc hba port, aborting"
			cti_deleteall "$CMD err!"
			return 1
		fi			
		comstar_startup_fcoe_initiator $FC_IHOST
		if [ $? -eq 1 ]; then 
			cti_report "warning: INITIATOR HOST $FC_IHOST"\
			    "initialized with errors"
			cti_uninitiated "there is no available initiator host,"\
			    "try to check the configuration file."
			cti_deleteall "no online initiator port!"
			return 1
		fi		
	fi
	
	return 0
}

#
# NAME
#       build_g_fcoe_netinterface()
# DESCRIPTION
#       build the global NIC interface list and check NIC interface status for FCoE target
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function build_g_fcoe_netinterface
{
	INTERFACE=/var/tmp/interface

	online_interface=0
	count=0

	CMD="$DLADM show-link | grep -v down |grep -v LINK"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ];then
		count=`get_cmd_stdout | awk '$3 >= 2500 {print $1}'|wc -l`
		if [ $count -ge 2 ]; then
			get_cmd_stdout | awk '$3 >= 2500 {print $1}' | \
				while read temp_interface
			do
				build_interface $temp_interface
			done
		else
			cti_uninitiated "Please check MTU(>=2500) of NIC interface"
			cti_deleteall "No FCoE supported NIC interface."
			return 1
		fi
	else
		report_err "$CMD"		
		cti_uninitiated "No FCoE supporting NIC interface on FCoE target host"\
			"Please check MTU(>=2500) Or STATE."
		cti_deleteall "$CMD err!"
		return 1
	fi			
	if [ $online_interface -lt 2 ]; then
		cti_uninitiated "At least two available NIC interface needed for FCoE target."
		cti_deleteall "No FCoE supported NIC interface."
		return 1
	fi
	
	#For libfcoe 
	echo $G_INTERFACE >$INTERFACE
	return 0
}

#
# NAME
#       build_interface()
# DESCRIPTION
#       build the global NIC interface list 
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function build_interface
{
	typeset interface=$1
	SPEED=0

	CMD="$DLADM show-phys $interface | grep -v LINK"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]; then
		SPEED=`get_cmd_stdout | awk '{print $4}'`
		STATUS=`get_cmd_stdout | awk '{print $3}'`

		if [[ "${SPEED}" == 10000 && "${STATUS}" == "up" ]]; then
			G_INTERFACE="$interface $G_INTERFACE"
			(( online_interface += 1 ))
			return 0	
		elif [[ "${SPEED}" == 0 && "${STATUS}" == "unknown" ]]; then
			# status is unknown, try to plumb 
			CMD="$IFCONFIG $interface plumb"
			run_ksh_cmd "$CMD"
			sleep 5
			CMD="$DLADM show-phys $interface | grep -v LINK"
			run_ksh_cmd "$CMD"

			SPEED=`get_cmd_stdout | awk '{print $4}'`
			STATUS=`get_cmd_stdout | awk '{print $3}'`

			# have to unplumb afterwards, otherwise FCoE cannot use this interface
			CMD="$IFCONFIG $interface unplumb"
			run_ksh_cmd "$CMD"
			if [[ "${SPEED}" == 10000  && "${STATUS}" == "up" ]]; then
				G_INTERFACE="$interface $G_INTERFACE"
				(( online_interface += 1 ))
				return 0	
			else 
				cti_report "$interface does not support FCoE"
				return 1
			fi
		else
			cti_report "$interface does not support FCoE"
			return 1
		fi
	else
		cti_report "$interface does not support FCoE"
		return 1
	fi

	return 0
}

#
# NAME
#       comstar_startup_fc_target()
# DESCRIPTION
#       generic startup processes of fc target for comstar
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_fc_target
{
	targ_typ=$1
	comstar_startup
	if [ $? -ne 0 ];then
		cti_uninitiated "comstar framework is not ready, aborting"
		cti_deleteall "comstar framework missed!"
		return 1
	fi	

	typeset sorted_modules="stmf_sbd stmf"
	cti_report "check for $sorted_modules modules"
	for module in $sorted_modules
	do
		typeset real_module=$($MODINFO | awk '{if($6=="'"$module"'") print $6}')
		if [ "$real_module" != "$module" ];then
			cti_uninitiated "modules $module is not loaded, aborting"
			cti_deleteall "$sorted_modules missed!"
			return 1
		fi		
	done

	#
	# Return here if we are not dealing with FC
	# otherwise continue startup for FC
	#
	if [ "$targ_typ" != "fc" ]; then
		return 0
	fi

	typeset fc_loaded=0
	typeset fc_modules="fct qlt emlxs"
	cti_report "check for fc related modules $fc_modules"
	for module in $fc_modules
	do
		typeset real_module=$($MODINFO | awk '{if($6=="'"$module"'") print $6}')
		if [ "$real_module" = "$module" ];then
			fc_loaded=1
			break
		fi
	done
	if [ $fc_loaded -eq 0 ];then
		cti_uninitiated "none of fc modules $fc_modules is not loaded, aborting"
		cti_deleteall "$fc_modules missed!"
		return 1
	fi		
	online_target_found=0
	cti_report "check available fc hba port on target "
	CMD="$FCINFO hba-port | grep -c -i online"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_stdout` -eq 0 ];then
		report_err "$CMD"		
		cti_uninitiated "target host has no online fc hba port, aborting"
		cti_deleteall "no online port!"
		return 1
	fi
	CMD="$FCINFO hba-port"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout | grep "HBA Port WWN" | awk '{print $NF}' | \
			while read portWWN
		do
			build_g_fc_target $portWWN
		done
	else
		report_err "$CMD"		
		cti_uninitiated "target host can not iterate "\
			"the fc hba port, aborting"
		cti_deleteall "$CMD err!"
		return 1
	fi			
	if [ $online_target_found -eq 0 ];then
		cti_uninitiated "there is no fc hba target port"\
			"found with online state."
		cti_deleteall "no online target port!"
		return 1
	fi
	
	# STAND_ALONE is 0, only stmfadm/sbdadm syntax testing on target host is needed
        STAND_ALONE=${STAND_ALONE:-${STANDALONE}}
        if [ $STAND_ALONE -ne 0 ];then
		comstar_startup_fc_initiator $FC_IHOST
		if [ $? -eq 1 ]; then 
			cti_report "warning: INITIATOR HOST $FC_IHOST"\
			    "initialized with errors"
			cti_uninitiated "there is no available initiator host,"\
			    "try to check the configuration file."
			cti_deleteall "no online initiator port!"
			return 1
		fi		
	fi
	
	return 0

	
}
#
# NAME
#       build_g_fc_target()
# DESCRIPTION
#       build the global fc target port list and check the target port state
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function build_g_fc_target
{
	typeset -u portWWN=$1		
	typeset stmf_port=wwn.$portWWN
	CMD="$FCINFO hba-port $portWWN"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout |grep "Port Mode: Target" \
			>/dev/null 2>&1
		if [ $? -eq 0 ];then
			echo "${G_TARGET}" |grep -w $portWWN \
				>/dev/null 2>&1
			if [ $? -ne 0 ]; then
				G_TARGET="$stmf_port $G_TARGET"
			fi				
			get_cmd_stdout |grep "State: online" \
				>/dev/null 2>&1
			if [ $? -eq 0 ];then
				eval TARGET_wwn_${portWWN}_ONLINE=Y
				cti_report "FC HBA Target Port"\
					"$portWWN is online"
				(( online_target_found += 1 ))
			else
				eval \
				TARGET_wwn_${portWWN}_ONLINE=N
				cti_report "FC HBA Target Port"\
					"$portWWN is offline"
			fi
		else
			cti_report "FC HBA Port $portWWN "\
				"is not target port"
		fi
		return 0
	else
		report_err "$CMD"
		cti_uninitiated "$CMD run with unexpected "\
			"error, skip port $portWWN"
		cti_deleteall "$CMD err!"
		return 1
	fi
}

#
# NAME
#       comstar_cleanup_fcoe_target()
# DESCRIPTION
#       generic cleanup processes of comstar fcoe target test suite
#
# RETURN
#       void
#
function comstar_cleanup_fcoe_target
{
	fcoe_cleanup_target 
	comstar_cleanup_target
	
}
#
# NAME
#       comstar_cleanup_fc_target()
# DESCRIPTION
#       generic cleanup processes of comstar fc target test suite
#
# RETURN
#       void
#
function comstar_cleanup_fc_target
{
	comstar_cleanup_target
	
}

#
# NAME
#       comstar_startup_fcoe_initiator()
# DESCRIPTION
#       generic startup processes of fcoe initiator for FCoE	
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_fcoe_initiator
{
	typeset FC_INITIATOR_HOST=$1
	# Begin to check the FC INITIATOR configuration enviroment
	online_initiator_found=0
	cti_report "check initiator host [$FC_INITIATOR_HOST] fc port state"
	typeset CMD="$FCINFO hba-port | grep -c -i online"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	if [ `get_cmd_stdout` -eq 0 ];then
		report_err "$CMD"		
		cti_uninitiated "initiator host $FC_INITIATOR_HOST "\
			"has no online fc hba port, aborting"
		cti_deleteall "no online port!"
		return 1
	fi
	CMD="$FCINFO hba-port"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	if [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout | grep "HBA Port WWN" | awk '{print $NF}' | \
			while read portWWN
		do
			build_g_fc_initiator $portWWN $FC_INITIATOR_HOST
		done
	else
		report_err "$CMD"		
		cti_uninitiated "initiator host $FC_INITIATOR_HOST "\
			"can not iterate the fc hba port, aborting"
		cti_deleteall "$CMD err!"
		return 1
	fi			
	if [ $online_initiator_found -eq 0 ];then
		cti_uninitiated "there is no fc hba initiator port found "\
			"with online state."
		cti_deleteall "no online initiator port "\
			"on host $FC_INITIATOR_HOST!"
		return 1
	fi
	# End to check the FC INITIATOR configuration enviroment	

	return 0
		
}

#
# NAME
#       comstar_startup_fc_initiator()
# DESCRIPTION
#       generic startup processes of fc initiator for comstar
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_fc_initiator
{
	typeset FC_INITIATOR_HOST=$1
	# Begin to check the FC INITIATOR configuration enviroment
	online_initiator_found=0
	cti_report "check initiator host [$FC_INITIATOR_HOST] fc port state"
	typeset CMD="$FCINFO hba-port | grep -c -i online"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	if [ `get_cmd_stdout` -eq 0 ];then
		report_err "$CMD"		
		cti_uninitiated "initiator host $FC_INITIATOR_HOST "\
			"has no online fc hba port, aborting"
		cti_deleteall "no online port!"
		return 1
	fi
	CMD="$FCINFO hba-port"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	if [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout | grep "HBA Port WWN" | awk '{print $NF}' | \
			while read portWWN
		do
			build_g_fc_initiator $portWWN $FC_INITIATOR_HOST
		done
	else
		report_err "$CMD"		
		cti_uninitiated "initiator host $FC_INITIATOR_HOST "\
			"can not iterate the fc hba port, aborting"
		cti_deleteall "$CMD err!"
		return 1
	fi			
	if [ $online_initiator_found -eq 0 ];then
		cti_uninitiated "there is no fc hba initiator port found "\
			"with online state."
		cti_deleteall "no online initiator port "\
			"on host $FC_INITIATOR_HOST!"
		return 1
	fi

	leadville_bug_trigger $FC_INITIATOR_HOST
	cti_report "check the initiator host [$FC_INITIATOR_HOST] "\
		"for invalid existing lun"
	CMD="$FCINFO lu"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	get_cmd_stdout | grep -i "OS Device Name" >/dev/null 2>&1
	if [ $? -eq 0 ];then
		report_err "$CMD"		
		cti_uninitiated "initiator host $FC_INITIATOR_HOST "\
			"has invalid existing lun, aborting"
		cti_deleteall "initiator host $FC_INITIATOR_HOST "\
			"is not clean and clear!"
		return 1
	fi

	# End to check the FC INITIATOR configuration enviroment	

	return 0
		
}
#
# NAME
#       build_g_fc_initiator()
# DESCRIPTION
#       build the global fc target port list and check the target port state
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#

function build_g_fc_initiator
{
	typeset -u portWWN=$1	
	typeset FC_INITIATOR_HOST=$2

	typeset stmf_port=wwn.$portWWN
	CMD="$FCINFO hba-port $portWWN"
	run_rsh_cmd $FC_INITIATOR_HOST "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout |grep "Port Mode: Initiator" >/dev/null 2>&1
		if [ $? -eq 0 ];then
			typeset hostname=`format_shellvar $FC_INITIATOR_HOST`
			eval HOST_${hostname}_INITIATOR="\${HOST_${hostname}_INITIATOR:=''}"	
			eval initiator_list="\$HOST_${hostname}_INITIATOR"
			echo $initiator_list |grep -w $stmf_port >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				eval HOST_${hostname}_INITIATOR=\"$stmf_port $initiator_list\"
			fi	
			get_cmd_stdout |grep "State: online" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				typeset ping=1
				for targetWWN in $G_TARGET
				do
					targetWWN=`echo $targetWWN | \
						cut -d. -f2-` 
					typeset cmd="$FCINFO remote-port"
					cmd="$cmd -p $portWWN -s $targetWWN"
					get_cmd_stdout | \
						grep "reason: ILLEGAL WWN" \
						>/dev/null 2>&1
					if [ $? -eq 0 ];then
						ping=0
					else
						break
					fi
				done
				if [ $ping -eq 1 ];then
					eval INITIATOR_wwn_${portWWN}_ONLINE=Y
					cti_report "FC HBA Initiator Port "\
						"$portWWN is online"
					(( online_initiator_found += 1 ))
				else
					eval INITIATOR_wwn_${portWWN}_ONLINE=N
					cti_report "FC HBA Initiator Port "\
						"$portWWN is treated as "\
						"offline due to un-accessed "\
						"by all targets"
				fi
			else
				eval INITIATOR_wwn_${portWWN}_ONLINE=N
				cti_report "FC HBA Initiator Port "\
					"$portWWN is offline"
			fi
		else
			cti_report "FC HBA Port $portWWN is not initiator port"
		fi
		return 0
	else
		report_err "$CMD"
		cti_uninitiated "$CMD run with unexpected error, "\
			"skip port $portWWN"
		cti_deleteall "$CMD err!"
		return 1
	fi
}
#
# NAME
#       comstar_startup_iscsi_target()
# DESCRIPTION
#       generic startup processes of iscsi target for comstar
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_iscsi_target
{
	comstar_startup
	if [ $? -ne 0 ];then
		cti_uninitiated "comstar framework is not ready, aborting"
		cti_deleteall "comstar framework missed!"
		return 1
	fi

	cti_report "check for $ISCSITGT_TARGET_SMF smf service"
	iscsitgt_target_smf_disable

	cti_report "check for $ISCSI_TARGET_SMF smf service"
	iscsi_target_smf_enable

	typeset sorted_modules="iscsit idm stmf_sbd stmf"
	cti_report "check for $sorted_modules modules"
	for module in $sorted_modules
	do
		typeset real_module=$($MODINFO | awk '{if($6=="'"$module"'") print $6}')
		if [ "$real_module" != "$module" ];then
			cti_uninitiated "modules $module is not loaded, aborting"
			cti_deleteall "$sorted_modules missed!"
			return 1
		fi		
	done

	cti_report "check target node for environmental database"
        CMD="$ITADM list-target"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep "TARGET NAME" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the target node database"
                env_iscsi_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "iscsi target node exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "check target portal group for environmental database"
        CMD="$ITADM list-tpg"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep "TARGET PORTAL GROUP" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the target portal group database"
                env_iscsi_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "iscsi target portal group exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi
	
	cti_report "check initiator node for environmental database"
        CMD="$ITADM list-initiator"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep "INITIATOR NAME" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the initiator node database"
                env_iscsi_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "iscsi initiator node exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "reset the default settings"
	env_iscsi_defaults_cleanup
	if [ $? -ne 0 ];then
		cti_uninitiated "default setting can not be reset"
		cti_deleteall "modify-defaults not reset!"
		return 1
	fi

	itadm_load_defaults

	# STAND_ALONE is 0, only itadm syntax testing on target host is needed
	STAND_ALONE=${STAND_ALONE:-${STANDALONE}}
	if [ $STAND_ALONE -ne 0 ];then
		cti_report "check for at least 2 target portals existing"
		discover_portal_info $ISCSI_THOST
		typeset portals=$(get_portal_number $ISCSI_THOST)
		if [ $portals -lt 2 ];then
			cti_uninitiated "transportation type is $TRANSPORT"\
		    	    "iscsi target host should have at least"\
		    	    "2 valid portals existing but with only $portals, aborting"
			cti_deleteall "target portals not enough!"
			return 1		
		fi

		comstar_startup_iscsi_initiator $ISCSI_IHOST
		if [ $? -eq 1 ]; then 
			cti_report "warning: INITIATOR HOST $ISCSI_IHOST"\
			    "initialized with errors"
			cti_uninitiated "there is no available iscsi initiator host, "\
			    "try to check the configuration file."
			cti_deleteall "no available iscsi initiator host!"
			return 1
		fi		

		# NS does not support iSNS
		#comstar_startup_isns_server $ISNS_HOST
		#if [ $? -eq 1 ]; then 
		#	cti_report "warning: ISNS SERVER HOST $ISNS_IHOST"\
		#	    "initialized with errors"
		#	cti_uninitiated "there is no available isns server host, "\
		#	    "try to check the configuration file."
		#	cti_deleteall "no available isns server host!"
		#	return 1
		#fi		
	fi

	return 0
}

#
# NAME
#       comstar_startup_iscsi_initiator()
# DESCRIPTION
#       generic startup processes of iscsi initiator for comstar
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_iscsi_initiator
{
	typeset ISCSI_INITIATOR_HOST=$1
	# Begin to check the ISCSI INITIATOR configuration enviroment
	online_initiator_found=0
	cti_report "check initiator host [$ISCSI_INITIATOR_HOST]"

	cti_report "check for $ISCSI_INITIATOR_SMF smf service [$ISCSI_INITIATOR_HOST]"
	iscsi_initiator_smf_enable $ISCSI_INITIATOR_HOST
	if [ $? -eq 1 ];then
		cti_uninitiated "smf $ISCSI_INITIATOR_SMF is not ready properly, aborting"
		cti_deleteall "$ISCSI_INITIATOR_SMF smf service missed!"
		return 1
	fi

	cti_report "attempt to clean up the initiator environment"\
	    " [$ISCSI_INITIATOR_HOST]"
	initiator_cleanup $ISCSI_INITIATOR_HOST
	if [ $? -ne 0 ];then
		cti_uninitiated "iscsi initiator cleanup is incomplete"
		cti_deleteall "iscsi initiator is not clear"
		return 1
	fi

	typeset CMD="$ISCSIADM list target"
        run_rsh_cmd $ISCSI_INITIATOR_HOST "$CMD"
        typeset target=$(get_cmd_stdout | grep -c -i target)
        if [ $target -ne 0 ];then
		cti_report "$CMD still discovery the invalid targets"\
		    " [$ISCSI_INITIATOR_HOST]"
		cti_uninitiated "iscsi initiator needs a reboot to cleanup"
		cti_deleteall "iscsi initiator is not clear"
		return 1
        fi

	cti_report "check for at least 2 initiator portals existing [$ISCSI_INITIATOR_HOST]"
	discover_portal_info $ISCSI_INITIATOR_HOST
	typeset portals=$(get_portal_number $ISCSI_INITIATOR_HOST)
	if [ $portals -lt 2 ];then
		cti_uninitiated "transportation type is $TRANSPORT"\
		    "iscsi initiator host should have at least"\
		    "2 valid portals existing but with only $portals, aborting"
		cti_deleteall "initiator portals not enough!"
		return 1		
	fi
	cti_report "check for initiator node name [$ISCSI_INITIATOR_HOST]"
	iscsiadm_info_init $ISCSI_INITIATOR_HOST
	
	typeset hostname=`format_shellvar $ISCSI_INITIATOR_HOST`
	eval HOST_${hostname}_INITIATOR="\${HOST_${hostname}_INITIATOR:=''}"	
	eval initiator_list="\$HOST_${hostname}_INITIATOR"
	typeset initiator_node=$(iscsiadm_i_node_name_get $ISCSI_INITIATOR_HOST)
	echo "$initiator_list" |grep -w $initiator_node >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		eval HOST_${hostname}_INITIATOR=\"$initiator_node $initiator_list\"
	fi
	typeset i_port=$(format_shellvar $initiator_node)
	eval INITIATOR_${i_port}_ONLINE=Y

	# End to check the ISCSI INITIATOR configuration enviroment	
	return 0
		
}
#
# NAME
#       comstar_startup_isns_server()
# DESCRIPTION
#       generic startup processes of iscsi initiator for comstar
#
# ARGUMENT
#	  
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup_isns_server
{
	typeset ISNS_SERVER_HOST=$1

	cti_report "check for $ISNS_SMF smf service [$ISNS_SERVER_HOST]"
	isns_smf_enable $ISNS_SERVER_HOST
	if [ $? -eq 1 ];then
		cti_uninitiated "smf $ISNS_SMF is not ready properly, aborting"
		cti_deleteall "$ISNS_SMF smf service missed!"
		return 1
	fi
	return 0
}

#
# NAME
#       comstar_cleanup_iscsi_target()
# DESCRIPTION
#       generic cleanup processes of comstar iscsi target test suite
#
# RETURN
#       void
#
function comstar_cleanup_iscsi_target
{
	comstar_cleanup_target
	
}
#
# NAME
#       comstar_startup()
# DESCRIPTION
#       generic startup processes of comstar framework
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function comstar_startup
{
	create_comstar_logdir
	# Begin to check the FC TARGET configuration enviroment
	
	cti_report "setup coreadm pattern"
	CMD="/usr/bin/coreadm -e global -g /core"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"		
		cti_report "WARNING: can not setup the core dump path, aborting"
	fi
	
	cti_report "check for stmfadm utility"
	CMD="$LS $STMFADM"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "$CMD"		
		cti_uninitiated "$STMFADM is not installed, aborting"
		cti_deleteall "$STMFADM missed!"
		return 1
	fi

	cti_report "check for $STMF_SMF smf service"
	stmf_smf_enable
	if [ $? -eq 1 ];then
		cti_uninitiated "smf $STMF_SMF is not ready properly, aborting"
		cti_deleteall "$STMF_SMF smf service missed!"
		return 1
	fi
	
	cti_report "check for sbd existing LUs"
        CMD="$SBDADM list-lu"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep "Found 0 LU(s)" > /dev/null 2>&1
        if [ $? -ne 0 ]
        then
		cti_report "attempt to clean up the existing LUs"
                env_sbd_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "sbd database exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "check for sbd failed LUs"
        CMD="$SBDADM list-lu"
        run_ksh_cmd  "$CMD"     
        get_cmd_stderr | grep "Failed to load" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the failed LUs"
                env_sbd_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "sbd database exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "check for target group"
        CMD="$STMFADM list-tg"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep -i "Target Group" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the target group"
                env_stmf_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "stmf database exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "check for host group"
        CMD="$STMFADM list-hg"
        run_ksh_cmd  "$CMD"     
        get_cmd_stdout | grep -i "Host Group" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
		cti_report "attempt to clean up the host group"
                env_stmf_cleanup
		if [ $? -ne 0 ];then
			cti_uninitiated "stmf database exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi

	cti_report "check for mount point $MP"
	typeset cf_mp=`$DF $MP 2>/dev/null | $AWK '{ print $1 }' | \
	    $AWK -F"(" '{print $1}'`
	if [ "$cf_mp" = "$MP" ]; then
		CMD="$UMOUNT $MP"
		cti_report "cleaning by : $CMD"
		run_ksh_cmd "$CMD"
		if [ `get_cmd_retval` -ne 0 ]; then
			CMD="$UMOUNT -f $MP"
			cti_report "cleaning by : $CMD"
			run_ksh_cmd "$CMD"
			if [ `get_cmd_retval` -ne 0 ]; then
				cti_uninitiated "forced umount $MP failed, aborting"
				cti_deleteall "data storing not clear enough"
				return 1
			fi
		fi
	fi

	cti_report "check for zfs/zpool existing"
	CMD="$ZPOOL list $ZP"
	run_ksh_cmd "$CMD"
	if [ `get_cmd_retval` -eq 0 ]
	then
		cti_report "attempt to destroy the existing zpool $ZP"
		CMD="$UMOUNT /$ZP"
		cti_report "cleaning by : $CMD"
		run_ksh_cmd "$CMD"
		CMD="$ZPOOL destroy -f $ZP"
		cti_report "cleaning by : $CMD"
		run_ksh_cmd "$CMD"
		if [ `get_cmd_retval` -ne 0 ]
		then
			cti_uninitiated "zpool $ZP exists, aborting"
			cti_deleteall "environment not clear enough!"
			return 1
		fi
	fi
}
#
# NAME
#       comstar_cleanup_target()
# DESCRIPTION
#       generic cleanup processes of comstar test suite
#
# RETURN
#       void
#
function comstar_cleanup_target
{
	cti_report "comstar cleanup target"
	if [ -d $LOGDIR ];then
		rm -rf $LOGDIR/*
	fi
	
}

#
# NAME
#       create_comstar_logdir()
# DESCRIPTION
#       create the log directory for function temporary usage.
#
# RETURN
#       0 successful
#	1 failed
#
function create_comstar_logdir
{
	if [ ! -d $LOGDIR ]; then
		$MKDIR -p $LOGDIR >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			cti_uninitiated "LOGDIR is not created"
			cti_deleteall "$MKDIR -p $LOGDIR err!"
			return 1
		fi
	else
		$RM -rf $LOGDIR >/dev/null 2>&1
		$MKDIR -p $LOGDIR >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			cti_uninitiated "LOGDIR is not re-created"
			cti_deleteall "$MKDIR -p $LOGDIR err!"
			return 1
		fi
	fi
	return 0

}
# NAME
#	itadm_load_defaults
# DESCRIPTION
#	Load the default settings since there is no option to 
#	delete the defautl settings by itadm
#
# RETURN
#	Sets the result code
#	void
#
function itadm_load_defaults
{
	cti_report "load the default settings of itadm"
	itadm_modify defaults -d "ab1234567890" 
	itadm_list defaults
	
	typeset alias=$(get_cmd_stdout | awk '{if($1~/alias:/) print $NF}')
	DEFAULTS_ALIAS=$(echo $alias | sed -e "s/<none>//g" -e "s/none//g" -e "s/unset//g")

	typeset auth=$(get_cmd_stdout | awk '{if($1~/auth:/) print $NF}')
	DEFAULTS_AUTH=$(echo $auth | sed -e "s/<none>//g" -e "s/none//g" -e "s/unset//g")
	
	typeset rserver=$(get_cmd_stdout | awk '{if($1~/radiusserver:/) print $NF}')
	rserver=$(unique_list "$rserver" "," " ")
	DEFAULTS_RADIUS_SERVER=$(echo $rserver | sed -e "s/<none>//g" -e "s/none//g" -e "s/unset//g")
	typeset server
        typeset server_list=''
        if [[ "$( echo "$DEFAULTS_RADIUS_SERVER" | egrep none)" == "" ]];then
                for server in $DEFAULTS_RADIUS_SERVER
                do
                        server=$(supply_default_port "$server" "radius")
                        server_list="$server $server_list"
                done
                DEFAULTS_RADIUS_SERVER=$(unique_list "$server_list" " " " ")
        fi



	typeset ienable=$(get_cmd_stdout | awk '{if($1~/isns:/) print $NF}')
	DEFAULTS_ISNS_ENABLE=$ienable

	typeset iserver=$(get_cmd_stdout | awk '{if($1~/isnsserver:/) print $NF}')
	iserver=$(unique_list "$iserver" "," " ")
	DEFAULTS_ISNS_SERVER=$(echo $iserver | sed -e "s/<none>//g" -e "s/none//g" -e "s/unset//g")
        typeset server_list=''
        if [[ "$( echo "$DEFAULTS_ISNS_SERVER" | egrep none)" == "" ]];then
                for server in $DEFAULTS_ISNS_SERVER
                do
                        server=$(supply_default_port "$server" "isns")
                        server_list="$server $server_list"
                done
                DEFAULTS_ISNS_SERVER=$(unique_list "$server_list" " " " ")
        fi

	# load the previous radius secret set by other tp and stored in system
	typeset radius_secret=$(get_cmd_stdout | awk '{if($1~/radiussecret:/) print $NF}')
	if [ "$radius_secret" != "unset" ];then
		# since there is no interface to empty the secret by itadm, 
		# the secret value is marked with "SetButUnknown"
		DEFAULTS_RADIUS_SECRET=${DEFAULTS_RADIUS_SECRET:="SetButUnkown"}
	else
		DEFAULTS_RADIUS_SECRET=$(echo $radius_secret | sed -e "s/<none>//g" -e "s/none//g" -e "s/unset//g")
	fi
}

#
# NAME
#	itadm_store_defaults
# DESCRIPTION
#	restore the default settings since there is no option to 
#	delete the defautl settings by itadm
#
# RETURN
#	Sets the result code
#	void
#
function itadm_store_defaults
{
	cti_report "store the default settings of itadm"

	tp_export_tc \
	DEFAULTS_ALIAS \
	DEFAULTS_AUTH \
	DEFAULTS_RADIUS_SERVER\
	DEFAULTS_RADIUS_SECRET\
	DEFAULTS_ISNS_ENABLE\
	DEFAULTS_ISNS_SERVER
}

