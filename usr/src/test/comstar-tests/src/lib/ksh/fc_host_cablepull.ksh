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
#       create_random_sleep() 
# DESCRIPTION
#       The create_random_sleep() function is used to create random values with 
#	the range between $UPPERBNDRY, and $LOWERBNDRY
#
# RETURN	
#	void
#
function create_random_sleep
{
    RANVAL=`expr $RANDOM % $MODVAL`
    
    if (( $RANVAL > $UPPERBNDRY )); then
        create_random_sleep
    elif (( $RANVAL < $LOWERBNDRY )); then
        create_random_sleep
    else
        SLEEPVAL=$RANVAL
    fi
}


#
# NAME
#       luxadm_forcelip()
# DESCRIPTION
#       luxadm -e forcelip from hostside
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       1 failed
#       0 successful
#
function luxadm_forcelip
{
	typeset hostname=$1
	cti_report "Start host side cable pull with "\
		"luxadm forcelip tests on host $hostname."
	
	MODVAL=$LIP_MODVAL
	UPPERBNDRY=$LIP_UPPERBNDRY
	LOWERBNDRY=$LIP_LOWERBNDRY
	typeset max_iter=$LIP_MAX_ITER
	typeset iter=1
	typeset retcode=0
	
	while [ $iter -le $max_iter ]
	do
		cti_report "Executing: running host side forcelip "\
			"to verify failover with $iter round"
		typeset host_name=`format_shellvar $hostname`
		eval initiator_list="\$HOST_${host_name}_INITIATOR"
		for i_portWWN in $initiator_list
		do
			port=`format_shellvar $i_portWWN`
			eval typeset cfg="\$INITIATOR_${port}_CFG"
			if [ -n "$cfg" ];then
				typeset cmd="$LUXADM -e forcelip $cfg"
				cti_report "$cmd"
				run_rsh_cmd $hostname "$cmd"
				if [ `get_cmd_retval` -ne 0 ];then
					cti_fail "$LUXADM on initiator host"\
						"$hostname failed."
					(( retcode+=1 ))
				fi
				create_random_sleep				
				cti_report "sleep $SLEEPVAL intervals"
				sleep $SLEEPVAL
				verify_forcelip "$hostname"
			fi
		done
		(( iter+=1 ))
	done
	cti_report "End host side cable pull with luxadm forcelip "\
		"tests on host $hostname."
	if [ $retcode -eq 0 ];then
		return 0	
	else
		cti_fail "FAIL - Host side cable pull with luxadm "\
			"forcelip tests failed."
		return 1
	fi
}

#
# NAME
#       verify_forcelip()
# DESCRIPTION
#       host side should mpathadm show target
#       target side should list-tareget -v show initiator
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       1 failed
#       0 successful
#
function verify_forcelip
{
	typeset hostname=$1
	typeset retcode=0
	typeset host_name=`format_shellvar $hostname`
	eval typeset initiator_list="\$HOST_${host_name}_INITIATOR"
	typeset i_portWWN
	for i_portWWN in $initiator_list
	do
		typeset port=`format_shellvar $i_portWWN`
		eval typeset online="\$INITIATOR_${port}_ONLINE"
		if [ "$online" = "Y" ];then
			typeset cmd="$STMFADM list-target -v |grep -i $i_portWWN"
			run_ksh_cmd "$cmd"
			if [ `get_cmd_retval` -ne 0 ];then
				cti_report "WARNING: $i_portWWN can not be"\
					"listed in target host"
				(( retcode+=1 ))
			fi
		fi
	done

	if [ $retcode -eq 0 ];then
		return 0	
	else
		cti_fail "FAIL - Luxadm -e forcelip failed on host $hostname."
		return 1
	fi
}

