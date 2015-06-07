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
#       host_is_alive()
# DESCRIPTION
#       function to test whether the host is alive by ping command
#
# ARGUMENT
#       $1 HOSTNAME
#
# RETURN
#	0 - can be pinged.
#	1 - can not be pinged.
#
function host_is_alive
{
	cti_report "wait for $HOSTNAME up to ping"
	typeset maxRound=30
	typeset HOSTNAME=$1

	indexRound=0	
	run_ksh_cmd "/usr/sbin/ping $HOSTNAME 1"
	while [ `get_cmd_retval` -ne 0 ]
	do
		sleep 10
		run_ksh_cmd "/usr/sbin/ping $HOSTNAME 1"
		(( indexRound+=1 ))
		if [ $indexRound -gt $maxRound ];then
			cti_report "ping alive maximum $maxRound round, "\
				"sys startup failed."
			return 1
		fi
	done
	cti_report "$HOSTNAME is alive"
	return 0
}
#
# NAME
#       host_is_ready()
# DESCRIPTION
#       function to test if the host is ready for rsh or rlogin
#
# ARGUMENT
#       $1 HOSTNAME
#
# RETURN
#	0 - can be rlogin or rsh.
#	1 - can not be rlogin or rsh.
#
function host_is_ready
{
	cti_report "wait for $HOSTNAME ready to rsh"
	typeset maxRound=30
	typeset HOSTNAME=$1

	indexRound=0
	run_rsh_cmd $HOSTNAME "ls"
	while [ `get_cmd_retval` -ne 0 ]
	do
		sleep 10
		run_rsh_cmd $HOSTNAME "ls"
		(( indexRound+=1 ))
		if [ $indexRound -gt $maxRound ];then
			cti_report "attempt rsh maximum $maxRound round, "\
				"rsh service failed."
			return 1
		fi
	done
	cti_report "$HOSTNAME is ready"
	return 0
}

#
# NAME
#	host_is_down
# DESCRIPTION
#	function to test if the host is down
#
# ARGUMENT
#       $1 HOSTNAME
# RETURN
#	Sets the result code
#	0 - if the system shutdown was successful
#	1 - if the system shutdown was not successful
#
# this function is to reboot host with options: -r, -d, etc.
function host_is_down
{
	cti_report "wait for $HOSTNAME down"
	typeset maxRound=30
	typeset HOSTNAME=$1
  
	indexRound=0
	run_ksh_cmd "/usr/sbin/ping $HOSTNAME 1"
	while [ `get_cmd_retval` -eq 0 ]
	do
		sleep 10
		run_ksh_cmd "/usr/sbin/ping $HOSTNAME 1"
		(( indexRound+=1 ))
		if [ $indexRound -gt $maxRound ];then
			cti_report "ping down maximum $maxRound round, "\
				"sys shutdown failed."
			return 1
		fi
	done
  
	cti_report "$HOSTNAME is down"
	return 0
}

#
# NAME
#       host_reconfigure
# DESCRIPTION
#       function to reconfigure device file system
#
# ARGUMENT
#       $1 HOSTNAME
# RETURN
#       Sets the result code
#       0 - if the system is reconfigured successfully
#       1 - if the system was not reconfigured successfully
#
# this function is to reboot host with options: -r, -d, etc.
function host_reconfigure
{
        cti_report "reconfigure $HOSTNAME device filesystem"
        typeset HOSTNAME=$1
 
	typeset cmd="$DEVFSADM -C"
        run_rsh_cmd $HOSTNAME "$cmd"
        if [ `get_cmd_retval` -ne 0 ];then
		cti_report "WARNING - $HOSTNAME : $cmd failed."
		report_err "$cmd"
		return 1
        fi

        cti_report "$HOSTNAME is reconfigured"
        return 0
}


#
# NAME
#	host_reboot
# DESCRIPTION
#	remote command report FAIL not accomplished in specified 
#	timeout duration, or return the result.
#
# ARGUMENT
#       $1 HOSTNAME
# RETURN
#	Sets the result code
#	0 - if the system reboot was successful
#	1 - if the system reboot was not successful
#
# this function is to reboot host with options: -r, -d, etc.
function host_reboot
{
	typeset HOSTNAME=$1
	
	run_rsh_cmd $HOSTNAME "sync"
	# the only way to get the rapid exit of RSH, that's a tip.
	case $2 in
		'-r')
			cti_report "reboot -- \"kmdb -rv\" on host $HOSTNAME"
			# workaround for CR 6764660 on ZFS filesystem
			#rsh -l root $HOSTNAME "reboot -- \"kmdb -rv\"" \
			run_rsh_cmd $HOSTNAME "reboot" \
				>/dev/null 2>&1 &
			;;
		'-d')
			cti_report "reboot -d on host $HOSTNAME"
			run_rsh_cmd $HOSTNAME "reboot -d" \
				>/dev/null 2>&1 &
			;;
		'-w')
			cti_report "waiting host $HOSTNAME DOWN to UP"
			;;
		*)	
			cti_report "reboot on host $HOSTNAME"
			run_rsh_cmd $HOSTNAME "reboot" >/dev/null 2>&1 &
			;;
	esac

	typeset ret_code=0
	
	host_is_down $HOSTNAME
	(( ret_code+=$? ))

	host_is_alive $HOSTNAME	
	(( ret_code+=$? ))

	host_is_ready $HOSTNAME	
	(( ret_code+=$? ))

	host_reconfigure $HOSTNAME
	(( ret_code+=$? ))

	if [ $ret_code -eq 0 ];then
		cti_report "$HOSTNAME is rebooted successfully"
		return 0
	else
		cti_report "$HOSTNAME is rebooted with warnings"
		return 1
	fi
}

