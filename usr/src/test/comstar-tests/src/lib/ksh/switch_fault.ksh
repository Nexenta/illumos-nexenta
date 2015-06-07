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
#
# NAME
#	set_global_switch_var
# DESCRIPTION
#	setup the global SWITCH variables to invoke the specified expect scripts
#
# ARGUMENT
#	$1 - switch information
#
# RETURN
#       0 - switch is supported
#       1 - switch is not supported
#
function set_global_switch_var
{	
	typeset switch_info="$1"

	typeset fields=$(echo "$switch_info" | awk -F: '{print NF}')
	if [ $fields -ne 5 ];then
		cti_report "WARNING - Switch Information is not complete"
		return 1
	fi
	
	SWTDIR="${CTI_SUITE}/bin"
	SWITCH_TYPE=$(echo $switch_info | cut -d: -f1)
	SWITCH_IP=$(echo $switch_info | cut -d: -f2)
	SWITCH_ADM=$(echo $switch_info | cut -d: -f3)
	SWITCH_PASS=$(echo $switch_info | cut -d: -f4)
	SWITCH_PORT=$(echo $switch_info | cut -d: -f5)

	if [ "$TARGET_TYPE" = "FC" ];then
		if [ "$SWITCH_TYPE" = "QLOGIC" ]; then
			SWPORT_OFFLINE_IF="${SWTDIR}/port_offline "
			SWPORT_ONLINE_IF="${SWTDIR}/port_online "
			SWITCH_RESET_IF="${SWTDIR}/switch_reset"
			LINK_RESET_IF="${SWTDIR}/link_reset_port "	
		elif [ "$SWITCH_TYPE" = "BROCADE" ];then
			SWPORT_OFFLINE_IF="${SWTDIR}/br_port_offline "
			SWPORT_ONLINE_IF="${SWTDIR}/br_port_online "
			SWITCH_RESET_IF="${SWTDIR}/br_switch_reset"	
		else
			cti_report "WARNING - TARGET_TYPE [$TARGET_TYPE]"\
			    "SWITCH_TYPE [$1] is not supported"
			return 1
		fi
	elif [ "$TARGET_TYPE" = "ISCSI" ];then
		if [ "$SWITCH_TYPE" = "TOPSPIN" ];then
			SWPORT_OFFLINE_IF="${SWTDIR}/ts_port_offline "
                        SWPORT_ONLINE_IF="${SWTDIR}/ts_port_online "
		else
			cti_report "WARNING - TARGET_TYPE [$TARGET_TYPE]"\
		    	    "SWITCH_TYPE [$1] is not supported"
			return 1
		fi
	elif [ "$TARGET_TYPE" = "FCOE" ];then
		if [ "$SWITCH_TYPE" == "CISCONEXUS" ]; then
			SWPORT_OFFLINE_IF="${SWTDIR}/cn_port_offline "
			SWPORT_ONLINE_IF="${SWTDIR}/cn_port_online "
		else
			cti_report "WARNING - TARGET_TYPE [$TARGET_TYPE]"\
		    	    "SWITCH_TYPE [$1] is not supported"
			return 1
		fi
	else
		cti_report "WARNING - TARGET_TYPE [$FC_TARGET] is not supported"
		return 1
	fi
	return 0
}
#
# NAME
#       switch_port_offline
# DESCRIPTION
#       This routine will change the state of switch port to offline on
#       the specified switch
#
# ARGUMENT
#	$1 - hostname
#       $2 - IP address of switch
#	$3 - Administrator username
#	$4 - Administrator password
#       $5 - port number to turn state offline
#
# RETURN
#       0 - port offline command succeeded.
#       1 - port offline command failed.
#
function switch_port_offline
{
	typeset hostname=$1
	typeset swname=$2
	typeset swadmin=$3
	typeset swpass=$4
	typeset portnum=$5

	cti_report "Changing port state on switch to offline SWITCH: "\
		"$swname PORT: $portnum"
	$SWPORT_OFFLINE_IF "$swname" "$swadmin" "$swpass" "$portnum" > \
		/tmp/${hostname}_portoffline_$$.tmp 2>&1
	if [ $? -ne 0 ]; then
		cti_fail "FAIL: $swname port $portnum OFFLINE"
		cti_reportfile /tmp/${hostname}_portoffline_$$.tmp "EXPECT OUTPUT"
		return 1
	else
		cti_report "PASS: $swname port $portnum OFFLINE"
		return 0
	fi
}
# 
# NAME
#       switch_port_online
# DESCRIPTION
#	This routine will change the state of switch port to online on
#       the specified switch
#
# ARGUMENT
#       $1 - hostname
#       $2 - IP address of switch
#	$3 - Administrator username
#	$4 - Administrator password
#       $5 - port number to turn state online
#
# RETURN
#       0 - port online command succeeded.
#       1 - port online command failed.
#
function switch_port_online
{
	typeset hostname=$1
	typeset swname=$2
	typeset swadmin=$3
	typeset swpass=$4
	typeset portnum=$5

	cti_report "Changing port state on switch to online SWITCH: "\
		"$swname PORT: $portnum"
	$SWPORT_ONLINE_IF "$swname" "$swadmin" "$swpass" "$portnum" > \
		/tmp/${hostname}_portonline_$$.tmp 2>&1 
        if [ $? -ne 0 ]; then
                cti_fail "FAIL: $swname port $portnum ONLINE"
                cti_reportfile /tmp/${hostname}_portonline_$$.tmp "EXPECT OUTPUT"
                return 1
        else
                cti_report "PASS: $swname port $portnum ONLINE"
                return 0
        fi
}
#
# NAME
# 	switch_cable_pull_io
# DESCRIPTION
#	to choose the switch type to penetrate the switch fault injection
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#       $3 - test rounds for switch cable pull
#
# RETURN
#	void
#
function switch_cable_pull_io
{
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	typeset switch_info
	
	case "$TARGET_TYPE" in
	"FC")
		
		for switch_info in $FC_TARGET_SWITCH_PORT
		do
			set_global_switch_var "$switch_info"
			if [ $? -ne 0 ];then
				continue
			fi
			common_switch_cable_pull_io "$hostname" "$intervals" "$max_iter"
		done
	;;
	"ISCSI")
		if [ "$TRANSPORT" == "SOCKETS" ];then
			for switch_info in $ISCSI_TARGET_SWITCH_PORT
			do
				set_global_switch_var "$switch_info"
				if [ $? -ne 0 ];then
					continue
				fi
				common_switch_cable_pull_io "$hostname" "$intervals" "$max_iter"
			done
		elif [ "$TRANSPORT" == "ISER" ];then
                        for switch_info in $ISER_TARGET_SWITCH_PORT
                        do
                                set_global_switch_var "$switch_info"
                                if [ $? -ne 0 ];then
                                        continue
                                fi
                                common_switch_cable_pull_io "$hostname" "$intervals" "$max_iter"
                        done
		elif [ "$TRANSPORT" == "ALL" ];then
                        for switch_info in $ISCSI_TARGET_SWITCH_PORT $ISER_TARGET_SWITCH_PORT
                        do
                                set_global_switch_var "$switch_info"
                                if [ $? -ne 0 ];then
                                        continue
                                fi
                                common_switch_cable_pull_io "$hostname" "$intervals" "$max_iter"
                        done
		else
			cti_report "WARNING - TRANSPORT [$TRANSPORT] is not supported"\
			    "in switch cable pull with I/O running"
			return 1
		fi
	;;
	"FCOE")
		for switch_info in $FC_TARGET_SWITCH_PORT
		do
			set_global_switch_var "$switch_info"
			if [ $? -ne 0 ];then
				continue
			fi
			common_switch_cable_pull_io "$hostname" "$intervals" "$max_iter"
		done
	;;
	*)
		cti_report "WARNING - unsupported TARGET_TYPE [$TARGET_TYPE] with I/O running"
		return 1
	esac
	return 0
}
#
# NAME
# 	common_switch_cable_pull_io
# DESCRIPTION
#	to execute the specified rounds of switch port online/offline
#	on the specified switch
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#       $3 - test rounds for switch cable pull
#
# RETURN
#	void
#
function common_switch_cable_pull_io
{
	if [ $NO_IO = 0 ];then
		return
	fi
	
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	typeset iter=1
	typeset portlist=`echo $SWITCH_PORT | tr -s ',' ' '`
	cti_report "TARGET is connected to SWITCH: $SWITCH_IP PORTS: $portlist"
	while [[ $iter -le $max_iter ]]
	do
		cti_report "Executing: running switch port online - offline"\
			"to verify failover with "\
			"$iter round and $intervals intervals"
		for port in $portlist
		do
			cti_report "switch_port_offline $SWITCH_IP $port"
			switch_port_offline "$hostname" "$SWITCH_IP" "$SWITCH_ADM" \
			    "$SWITCH_PASS" "$port"
			cti_report "sleep $intervals intervals "\
				"after switch_port_offline"
			sleep $intervals
			cti_report "switch_port_online $SWITCH_IP $port"
			switch_port_online "$hostname" "$SWITCH_IP" "$SWITCH_ADM" \
			    "$SWITCH_PASS" "$port"
			cti_report "sleep $intervals intervals "\
				"after switch_port_online"
			sleep $intervals
		done
		((iter+=1))
	done
}
#
# NAME
# 	switch_cable_pull
# DESCRIPTION
#	To execute the specified rounds of switch cable pull tests
#	on only fc target
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#       $3 - test rounds for switch cable pull
#
# RETURN
#	void
#
function switch_cable_pull
{
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	typeset iter=1

	case "$TARGET_TYPE" in
	"FC"|"FCOE")
		while [[ $iter -le $max_iter ]]
		do
			cti_report "Executing: running switch cablepull without I/O"\
			    "with $iter round"
			common_switch_cable_pull "$hostname" "$intervals"
			(( iter+=1 ))
		done
	;;
	*)
		cti_report "WARNING - TARGET_TYPE [$TARGET_TYPE] is not supported in switch cable pull"
		return 1
	;;
	esac
	return 0
	
}
#
# NAME
# 	common_switch_cable_pull
# DESCRIPTION
#	Verify that LU number is 0 when all the target ports are offlined
#	And all the LUs can be visible when all the target ports are re-onlined.
#	It's run on fc target
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#
# RETURN
#	void
#
function common_switch_cable_pull
{
	typeset hostname=$1
	typeset intervals=$2

	leadville_bug_trigger $hostname
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NO_PRE=`get_cmd_stdout  | grep -c "Logical Path"`
        if [ $VOL_MAX -ne $LUN_NO_PRE ]; then
                cti_report "WARNING - There should be $VOL_MAX LUNs"\
                "on initiator host $hostname setup, "\
                "but $LUN_NO_PRE LUNs now"
                report_err "$cmd"
        fi

	# start to offline
	typeset switch_info
	for switch_info in $FC_TARGET_SWITCH_PORT
	do
		set_global_switch_var "$switch_info"
		if [ $? -ne 0 ];then
			continue
		fi
		typeset portlist=`echo $SWITCH_PORT | tr -s ',' ' '`
		cti_report "configuration is connected to SWITCH: $SWITCH_IP PORTS: $portlist"
		for port in $portlist
		do
			cti_report "switch_port_offline $SWITCH_IP $port"
			switch_port_offline "$hostname" "$SWITCH_IP" "$SWITCH_ADM" \
			    "$SWITCH_PASS" "$port"
		done
	done
	cti_report "Executing: sleep $intervals intervals "\
		"after switch_port_offline"
	sleep $intervals

	# start to verify 
	leadville_bug_trigger $hostname
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NOW=`get_cmd_stdout | grep -c "Logical Path"`
	if [ $LUN_NOW -ne 0 ];then
		cti_report "WARNING - There should be 0 LUNs on initiator host "\
			"$hostname after offline-port, but $LUN_NOW LUNs now"
		report_err "$cmd"
	fi
	
	# start to online
	typeset switch_info
	for switch_info in $FC_TARGET_SWITCH_PORT
	do
		set_global_switch_var "$switch_info"
		if [ $? -ne 0 ];then
			continue
		fi
		typeset portlist=`echo $SWITCH_PORT | tr -s ',' ' '`
		cti_report "configuration is connected to SWITCH: $SWITCH_IP PORTS: $portlist"
		for port in $portlist
		do
			cti_report "switch_port_offline $SWITCH_IP $port"
			switch_port_online "$hostname" "$SWITCH_IP" "$SWITCH_ADM" \
			    "$SWITCH_PASS" "$port"
		done
	done
	cti_report "Executing: sleep $intervals intervals "\
		"after switch_port_online"
	sleep $intervals
	leadville_bug_trigger $hostname
	
	# start to verify
	typeset cmd="$LUXADM probe"
	run_rsh_cmd $hostname "$cmd"
	typeset LUN_NOW=`get_cmd_stdout | grep -c "Logical Path"`
	if [ $LUN_NOW -lt $LUN_NO_PRE ];then
		cti_report "WARNING - There should be $LUN_NO_PRE LUNs on "\
		    "initiator host $hostname after online-port, "\
		    "but $LUN_NOW LUNs now"
	fi
}
#
# NAME
#       run_switch_reset
# DESCRIPTION
#       This routine will reset the switch specified as input and return flag
#
# ARGUMENT
#	$1 - hostname
#	$2 - switch name
#	$3 - Administrator username
#       $4 - Administrator password
#
# RETURN
#       0 - switch reset was successful.
#       1 - switch reset failed.
#
function run_switch_reset
{
	typeset hostname=$1
	typeset swname=$2
	typeset swadm=$3
	typeset swpass=$4

	$SWITCH_RESET_IF "$swname" "$swadm" "$swpass" \
	    > /tmp/${hostname}_swreset_$$.tmp 2>&1 

        if [ $? -ne 0 ]; then
                cti_fail "FAIL: $swname switch reset"
                cti_reportfile /tmp/${hostname}_swreset_$$.tmp "EXPECT OUTPUT"
                return 1
        else
                cti_report "PASS: $swname switch reset"
                return 0
        fi
}

#
# NAME
# 	switch_reset
# DESCRIPTION
#       This routine will perform switch resets on specified list
#       of switches
#
# ARGUMENT
#	$1 - hostname
#       $2 - interval between port offline or online in seconds
#       $3 - number of cycles
#
# RETURN
#       void
#
function switch_reset
{
        typeset hostname=$1
        typeset intervals=$2
        typeset max_iter=$3
        typeset switch_info

        case "$TARGET_TYPE" in
        "FC")

                for switch_info in $FC_TARGET_SWITCH_PORT
                do
                        set_global_switch_var "$switch_info"
			if [ $? -ne 0 ];then
				continue
			fi
                        common_switch_reset "$hostname" "$intervals" "$max_iter"
                done
        ;;
        *)
                cti_report "WARNING - unsupported TARGET_TYPE [$TARGET_TYPE]"\
		    "with I/O running and switch reset"
                return 1
        esac
        return 0
}
#
# NAME
#       common_switch_reset
# DESCRIPTION
#       to execute the specified rounds of switch reset
#       on the specified switch
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#       $3 - test rounds for switch cable pull
#
# RETURN
#       void
#
function common_switch_reset
{
	if [ $NO_IO = 0 ];then
		return
	fi
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3

	cti_report "Configuration is connected to SWITCH: $SWITCH_IP"
	typeset iter=1   
	while [[ $iter -le $max_iter ]]
	do
		run_switch_reset "$hostname" "$SWITCH_IP" "$SWITCH_ADM" "$SWITCH_PASS"
		sleep $intervals
		((iter+=1))
	done
}

#
# NAME
#	link_reset
# DESCRIPTION
#       This routine will reset port on the switch specified as arguments
#       and return success or fail flag
#
# ARGUMENT
#	$1 - hostname
#       $2 - IP address of switch
#       $3 - Administrator username
#       $4 - Administrator password
#       $5 - port number on switch to reset link
#
# RETURN
#       0 - link reset was successful
#       1 - link reset failed.
#
function link_reset
{
	typeset hostname=$1
	typeset swname=$2
	typeset swadm=$3
	typeset swpass=$4
	typeset portnum=$5

	$LINK_RESET_IF "$swname" "$swadm" "$swpass" "$portnum" > \
		/tmp/${hostname}_resetlink_$$.tmp 2>&1 

        if [ $? -ne 0 ]; then
                cti_fail "FAIL: $swname port $portnum reset"
                cti_reportfile /tmp/${hostname}_resetlink_$$.tmp "EXPECT OUTPUT"
                return 1
        else
                cti_report "PASS: $swname port $portnum reset"
                return 0
        fi
}
#
# NAME
#	switch_link_reset
# DESCRIPTION
#       Function to perform Link Resets for max number on the specified
#       set of switches and ports
#       This routine will take the list of switches and ports as input
#       and return success or fail flag
#
# ARGUMENT
#	$1 - hostname
#       $2 - interval between port offline or online in seconds
#       $3 - number of cycles
# RETURN
#       void
#
function switch_link_reset
{
	typeset hostname=$1
	typeset intervals=$2
	typeset max_iter=$3
	typeset switch_info

        case "$TARGET_TYPE" in
        "FC")

                for switch_info in $FC_TARGET_SWITCH_PORT
                do
                        set_global_switch_var "$switch_info"
			if [ $? -ne 0 ];then
				continue
			fi
                        common_switch_link_reset "$hostname" "$intervals" "$max_iter"
                done
        ;;
        *)
                cti_report "WARNING - unsupported TARGET_TYPE [$TARGET_TYPE]"\
		    "with I/O running and switch link reset"
                return 1
        esac
        return 0
}
#
# NAME
#       common_switch_link_reset
# DESCRIPTION
#       to execute the specified rounds of switch link reset
#       on the specified switch
#
# ARGUMENT
#       $1 - switch host
#       $2 - the seconds of switch cable pull intervals
#       $3 - test rounds for switch cable pull
#
# RETURN
#       void
#
function common_switch_link_reset
{
        typeset hostname=$1
        typeset intervals=$2
        typeset max_iter=$3

	typeset portlist=`echo $SWITCH_PORT | tr -s ',' ' '`
	cti_report "Configuration is connected to SWITCH: $SWITCH_IP"\
	    "PORTS: $portlist"
	typeset iter=1
	while [[ $iter -le $max_iter ]]
	do
		cti_report "Executing: running switch port link reset to "\
		    "verify failover with $iter round "\
		    "and $intervals intervals"
		for port in $portlist
		do
			cti_report "link_reset $SWITCH_IP $port"
			link_reset "$hostname" "$SWITCH_IP" "$SWITCH_ADM" "$SWITCH_PASS" "$port"
			cti_report "sleep $intervals intervals "\
			    "after switch_port_link_reset"
			sleep $intervals
		done
		((iter+=1))
	done
}

