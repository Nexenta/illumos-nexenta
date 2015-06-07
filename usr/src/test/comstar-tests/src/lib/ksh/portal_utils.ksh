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
#	discover_portal_info
# DESCRIPTION
#	discovery the portal information on the specified host
#	to be utilized on startup checking and track the changes dynamically
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	return the available portal number
#
function discover_portal_info 
{
	typeset host_name=$1

	typeset iscsi_host=$(format_shellvar $host_name)
	eval HOST_${iscsi_host}_PORTAL="\${HOST_${iscsi_host}_PORTAL:=''}"	
	typeset CMD="$IFCONFIG -a | egrep -v 'ether|inet|ipib|lo0' | cut -d: -f1 \
	    | sort -u"
	run_rsh_cmd $host_name "$CMD"
	if [ `get_cmd_retval` -ne 0 ];then
		report_err "rsh $host_name $CMD"
	fi
	
	nif=`get_cmd_stdout`
	for interface in $nif
	do
		typeset cmd="$IFCONFIG $interface"
		eval typeset port_list="\${HOST_${iscsi_host}_PORTAL}"
		run_rsh_cmd $host_name "$cmd"
		typeset ip_addr=`get_cmd_stdout | awk '/inet/{print $2}'`
		typeset ip_state
		get_cmd_stdout | grep "UP,BROADCAST" >/dev/null 2>&1 
		if [ $? -eq 0 ];then
			ip_state="up"
		else
			ip_state="down"
		fi

		#
		# Now get ip_phy
		#
		typeset cmd="dladm show-phys $interface"
		run_rsh_cmd $host_name "$cmd"
		typeset ip_phy=`get_cmd_stdout | sed -n "2p"|awk '{print $2}'`

		# Host IP address can not be used for iscsi test address
		if [ "$ip_addr" = "$host_name" ];then
			continue
		fi
		echo "$port_list" | grep -w "$ip_addr" >/dev/null 2>&1
		typeset retval=$?
		if [ $retval -ne 0 -a "$ip_addr" != "0.0.0.0" ];then
			typeset new_portal="$interface:$ip_addr:$ip_state:$ip_phy"
			eval HOST_${iscsi_host}_PORTAL=\"$new_portal $port_list\"
		elif [ $retval -eq 0 -a "$ip_addr" != "0.0.0.0" ];then
			port_list=$(echo $port_list | awk '{for(i=1;i<=NF;i++) \
			    if (! $i~/'"$ip_addr"'/) printf("%s ",$i)} \
			    END{print}')
			typeset new_portal="$interface:$ip_addr:$ip_state:$ip_phy"
			eval HOST_${iscsi_host}_PORTAL=\"$new_portal $port_list\"
		else
			cti_report "WARNING - $interface is configured with $ip_addr"
			cti_report "WARNING - $(get_cmd_stdout)"			
		fi

	done
	eval set -A a_portal \${HOST_${iscsi_host}_PORTAL}
	return ${#a_portal[@]}
}


#
# NAME
#	get_portal_list
# DESCRIPTION
#	discovery the portal list on the specified host
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	void
#
function get_portal_list 
{
	typeset host_name=$1

	typeset iscsi_host=$(format_shellvar $host_name)
	eval HOST_${iscsi_host}_PORTAL="\${HOST_${iscsi_host}_PORTAL:=''}"	
	eval typeset port_list="\${HOST_${iscsi_host}_PORTAL}"
	typeset ip_list=''
	for portal_info in $port_list
	do
		typeset phy=`echo "$portal_info" | cut -d: -f4`
		if [ "$TRANSPORT" = "ISER" -a "$phy" != "ipib" ];then
			continue	
		elif [ "$TRANSPORT" = "SOCKETS" -a "$phy" != "Ethernet" ];then
			continue
		else
			:
		fi
		typeset ip=$(echo $portal_info | cut -d: -f2)
		ip_list="$ip $ip_list"
	done
	typeset -L ip_list=$ip_list
	typeset -R ip_list=$ip_list

	echo $ip_list
}

#
# NAME
#	get_portal_number
# DESCRIPTION
#	discovery the portal number on the specified host
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	Sets the result code
#	void
#
function get_portal_number 
{
	typeset host_name=$1

	set -A a_portal $(get_portal_list $host_name)
	echo ${#a_portal[@]}
}
#
# NAME
#	get_portal_state
# DESCRIPTION
#	get the portal state of plumb or un-plumb on the specified ip address 
#	on the specified host
#
# ARGUMENT
#	$1 - host name
#	$2 - the specified ip address
#
# RETURN
#	Sets the result code
#	0 - state is marked
#	1 - ip is not found 
#
function get_portal_state 
{
	typeset host_name=$1
	typeset ip_addr=$2

	typeset iscsi_host=$(format_shellvar $host_name)
	eval typeset port_list="\${HOST_${iscsi_host}_PORTAL}"

	typeset port_state=$(echo $port_list | awk '{for(i=1;i<=NF;i++) \
			    if ( $i~/'"$ip_addr"'/) print  $i}'|cut -d: -f3)
	if [ -n "$port_state" ];then
		echo $port_state
		return 0
	else
		cti_report "WARNING - attempt to get the portal state of"\
		    "specified ip $ip_addr failed, reason: NOT FOUND"
		return 1
	fi
}

#
# NAME
#	ifconfig_up_portal
# DESCRIPTION
#	ifconfig plumb the specified ip address on the specified host to ensure 
#	the portal is online
#
# ARGUMENT
#	$1 - host name
#	$2 - the specified ip address
#
# RETURN
#	Sets the result code
#	void
#
function ifconfig_up_portal 
{
	typeset host_name=$1
	typeset ip_addr=$2

	typeset state=$(get_portal_state $host_name $ip_addr)
	if [ $? -eq 1 -o -z "$state" ];then
		return
	else
		typeset iscsi_host=$(format_shellvar $host_name)
		eval typeset port_list="\${HOST_${iscsi_host}_PORTAL}"

		typeset interface=$(echo $port_list | awk '{for(i=1;i<=NF;i++)\
		    if ( $i~/'"$ip_addr"'/) print  $i}'|cut -d: -f1)		

		typeset CMD="$IFCONFIG $interface up"
		cti_report "$CMD [$ip_addr]"
		run_rsh_cmd $host_name "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			discover_portal_info $host_name
		else
			report_err "$CMD"
			cti_unresolved "WARNING - on $host_name attempt to "\
			    "plumb the interface $interface failed"
		fi
	fi
}
#
# NAME
#	ifconfig_down_portal
# DESCRIPTION
#	ifconfig unplumb the specified ip address on the specified host to ensure
#	the portal is offline
#
# ARGUMENT
#	$1 - host name
#	$2 - the specified ip address
#
# RETURN
#	Sets the result code
#	void
#
function ifconfig_down_portal 
{
	typeset host_name=$1
	typeset ip_addr=$2

	typeset state=$(get_portal_state $host_name $ip_addr)
	if [ $? -eq 1 -o -z "$state" ];then
		return
	else
		typeset iscsi_host=$(format_shellvar $host_name)
		eval typeset port_list="\${HOST_${iscsi_host}_PORTAL}"

		typeset interface=$(echo $port_list | awk '{for(i=1;i<=NF;i++)\
		    if ( $i~/'"$ip_addr"'/) print  $i}'|cut -d: -f1)
		
		typeset CMD="$IFCONFIG $interface down"
		cti_report "$CMD [$ip_addr]"
		run_rsh_cmd $host_name "$CMD"
		if [ `get_cmd_retval` -eq 0 ];then
			discover_portal_info $host_name
		else
			report_err "$CMD"
			cti_unresolved "WARNING - on $host_name attempt to "\
			    "unplumb the interface $interface failed"
		fi
	fi
}

