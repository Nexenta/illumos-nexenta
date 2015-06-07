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

# NAME
#	fcoe_create_ports
# DESCRIPTION
#	create fcoe ports by fcadm
#
# RETURN
#	!0 failed
#	0  successful
#
function fcoe_create_ports
{
	cti_report "create fcoe ports."
	#Check for the existing fcoe ports
	CMD="$FCADM list-fcoe-ports"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout |grep "No FCOE Ports Found" \
			>/dev/null 2>&1
		if [ $? -ne 0 ];then
			cti_report "FCOE ports exist already, clean them up before creating"
			fcoe_stmf_offline_target	
			sleep 10
			fcoe_delete_ports	
		fi

		for interface in $G_INTERFACE
		do
			create_fcoe_port_startup -t $interface
		done
		#for double check the fcoe port status after creating them
		CMD="$FCADM list-fcoe-ports"
		run_ksh_cmd "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			get_cmd_stdout |grep "HBA Port WWN:"|$AWK '{print $4}' | while read port_wwn
			do
				check_fcoe_port -node 0 -port $port_wwn -t 0
			done
		fi
	else
		report_err "$CMD"
		cti_uninitiated "fcoe_create_ports:fcoe target port can not be listed."
		cti_deleteall "fcoe_create_ports failed"
		return 1
	fi	
	
	return 0

}

#
# NAME
#	fcoe_delete_ports
# DESCRIPTION
#	delete fcoe ports by fcadm
#
# RETURN
#	!0 failed
#	0  successful
#
function fcoe_delete_ports
{
	cti_report "delete fcoe ports."
	CMD="$FCADM list-fcoe-ports"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout |grep "No FCOE Ports Found" \
			>/dev/null 2>&1
		if [ $? -ne 0 ];then
			get_cmd_stdout |grep "MAC Name:"|$AWK '{print $3}' | while read fcoe_interface
			do
				delete_fcoe_port $fcoe_interface
			done
		fi
	else
		report_err "$CMD"
		cti_fail "Can't list fcoe ports"		
		return 1
	fi	
	
	return 0
}

#
# NAME
#	create_fcoe_port_startup
# DESCRIPTION
#	create fcoe port based on interface when fcoe startup
#
# RETURN
#	!0 failed
#	0  successful
#
function create_fcoe_port_startup
{
	typeset option=$1
	typeset interface=$2	
	create_fcoe_port $option $interface
	if [ $? -ne 0 ];then
		cti_fail "aborting: create FCoE port with $interface failed"
		return 1
	else
		cti_report "FCoE port with $interface been created"
		return 0
	fi	

}

#
# NAME
#	create_fcoe_port
# DESCRIPTION
#	create fcoe port based on interface
#	Example : -n $node_wwn -p $port_wwn -f -t $mac_interface
#	Note: this function would not cti_fail when create-fcoe-port fail, 
#	      So the caller need to do this part itself! 	
#
# RETURN
#	!0 failed
#	0  successful
#
function create_fcoe_port
{
	typeset option1=$1
	typeset val1=$2
	typeset option2=$3
	typeset val2=$4
	typeset option3=$5
	typeset option4=$6
	typeset val4=$7
	cti_report "$FCADM create-fcoe-port $option1 $val1 $option2 $val2 $option3 $option4 $val4"
	CMD="$FCADM create-fcoe-port $option1 $val1 $option2 $val2 $option3 $option4 $val4"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -ne 0 ];then
	  	cti_report "returned 1"
		return 1
	fi
	cti_report "returned 0"
	return 0	
}

#
# NAME
#	delete_fcoe_port
# DESCRIPTION
#	delete fcoe port based on interface
#
# RETURN
#	!0 failed
#	0  successful
#
function delete_fcoe_port
{
	typeset mac_interface=$1
	CMD="$FCADM delete-fcoe-port $mac_interface"
	cti_report "$FCADM delete-fcoe-port $mac_interface"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -ne 0 ];then
		cti_fail "Can't delete fcoe port $mac_interface"	
		return 1
	fi
	cti_report "delete fcoe port $mac_interface success"
	return 0	
}

#
# NAME
#	check_fcoe_port		
# DESCRIPTION
#	check fcoe port status: list-fcoe-ports & fcinfo
#	Example : -n $node_wwn -p $port_wwn -t $mac_interface
#
# RETURN
#	!0 failed
#	0  successful
#
function check_fcoe_port
{
	typeset ret_code=0
	typeset check_succ=1
	fcoe_target_offline=0

	if [ "$1" == "-node" ];then		
		node_wwn=$2
	fi		
	if [ "$3" == "-port" ];then		
		port_wwn=$4
	fi		
	if [ "$5" == "-t" ];then		
		mac_interface=$6
	fi

	if [ "$port_wwn" == 0 ];then 
		cti_fail "fcoe port wwn is required"
		return 1
	fi	
	
	#Sometimes makes new FCoE port online takes time, so wait 10s here
	sleep 10	
	cti_report "check_fcoe_port node_wwn: $node_wwn port_wwn: $port_wwn mac_interface: $mac_interface"	
	CMD="$FCINFO hba-port $port_wwn"
	cti_report "$CMD"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		# check port mode : target
		get_cmd_stdout | grep -i "Port Mode: Target" >/dev/null 2>&1
		ret_code=$?	
		# check state(online)
		get_cmd_stdout | grep -i "State: online" >/dev/null 2>&1
		(( ret_code+=$? ))
		# check port ID gt 0
		get_cmd_stdout | grep -i "Port ID:"|$AWK '{print $3}' | read port_id 
		(( ret_code+=$? ))
		if [ "${port_id}" == "0" ];then
			fcoe_target_offline=1
		fi
		# check Manufacturer:
		get_cmd_stdout | grep -i "Manufacturer: Sun Microsystems, Inc" >/dev/null 2>&1
		(( ret_code+=$? ))
		# check Model
		get_cmd_stdout | grep -i "Model: FCoE Virtual FC HBA" >/dev/null 2>&1
		(( ret_code+=$? ))
		# check driver name
		get_cmd_stdout | grep -i "Driver Name: COMSTAR FCOET" >/dev/null 2>&1
		(( ret_code+=$? ))
		# check Supported Speeds
		get_cmd_stdout | grep -i "Current Speed: 10Gb" >/dev/null 2>&1
		(( ret_code+=$? ))
		# check node wwn with input node_wwn
		if [ "${node_wwn}" != 0 ];then 
			get_cmd_stdout | grep -i "Node WWN:"|$AWK '{print $3}' | read n_wwn
			if [ "$n_wwn" == "$node_wwn" ];then
				check_succ=1
			else
				check_succ=0
			fi
		fi
	else
		report_err "$CMD run ERROR"
		cti_fail "fcinfo hba-port $port_wwn fail"	
		return 1
	fi

	if [ $fcoe_target_offline -eq 1 ];then
		cti_fail "fcoe target port $port_wwn is offline."
		return 1
	else 
		cti_report "fcoe target port $port_wwn is online."
	fi	

	if [ $check_succ -eq 0 ];then
		cti_fail "Node WWN $node_wwn is not same as $n_wwn"
		return 1
	fi

	if [ $ret_code != 0 ];then
		cti_fail "check_fcoe_port failed: $node_wwn $port_wwn $mac_interface with ret_code $ret_code"
		return 1
	fi	
	return 0
}

#
# NAME
#	fcoe_cleanup_target
# DESCRIPTION
#	cleanup fcoe targets which created by fcadm
#
# RETURN
#	void
#
function fcoe_cleanup_target
{
	cti_report "fcoe cleanup target"
	#remove mapping
	cleanup_mapping
	#cleanup lun
        FCOE_DOIO=${FCOE_DOIO:-${FCOEDOIO}}
	if [ $FCOE_DOIO -ne 0 ];then	
		cleanup_default_lun
	fi		

	#delete fcoe ports
	fcoe_cleanup_ports
}

#
# NAME
#	fcoe_cleanup_ports
# DESCRIPTION
#	cleanup fcoe ports 
#
# RETURN
#	void
#
function fcoe_cleanup_ports
{
	cti_report "fcoe cleanup ports"
	fcoe_stmf_offline_target	
	sleep 10
	fcoe_delete_ports	
	cti_report "cleanup fcoe ports success"
}

#
# NAME
#	fcoe_stmf_offline_target	
# DESCRIPTION
#	fcoe stmfadm offline all of targets
#
# RETURN
#	!0 failed
#	0  successful
#
function fcoe_stmf_offline_target
{
	cti_report "fcoe_stmf_offline_target"
	CMD="$STMFADM list-target"
	run_ksh_cmd "$CMD"
	if  [ `get_cmd_retval` -eq 0 ];then
		get_cmd_stdout | grep "Target:"|$AWK '{print $2}' | while read t_portwwn
		do
			typeset cmd="$STMFADM offline-target $t_portwwn"
			cti_report "$cmd"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				report_err "$cmd"
				cti_fail "Can not offline fcoe target port $t_portwwn"
				return 1	
			fi
		done
	fi
	cti_report "fcoe_stmf_offline_target success"
	return 0	
}

