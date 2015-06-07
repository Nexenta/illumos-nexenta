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
#       build_fabric_topo()
# DESCRIPTION
#       build the complete topology information for fault injection tests
#       map each initiator port to /dev/cfg/c$
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       1 failed
#       0 successful
#
function build_fabric_topo
{
	cti_report "build fabric topology info."
	typeset host_name=$1
	typeset retcode=0
	typeset hostname=`format_shellvar $host_name`
	eval initiator_list="\$HOST_${hostname}_INITIATOR"
	for i_portWWN in $initiator_list
	do
		port=`format_shellvar $i_portWWN`
		eval INITIATOR_${port}_CFG="\${INITIATOR_${port}_CFG:=''}"
		iport=`echo $i_portWWN | cut -d. -f2-`
		
		typeset cmd="$FCINFO hba-port $iport | grep \"OS Device Name:\""
		cti_report "EXECUTING: $cmd"
		run_rsh_cmd $host_name "$cmd"
		if [ `get_cmd_retval` -eq 0 ];then
			typeset cfg=`get_cmd_stdout | awk '{print \$NF}'`
			eval INITIATOR_${port}_CFG="$cfg"				
		else
			report_err "$cmd"
			(( retcode+=1 ))
		fi
	done
	if [ $retcode -eq 0 ];then
		return 0	
	else
		cti_fail "FAIL - build fabirc topology info failed."
		return 1
	fi
}
#
# NAME
#       build_random_mapping()
# DESCRIPTION
#       build host group with each initiator port. 
#	  each host group has only one initiator port.
#	  map the created lun into host group randomly .
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       1 failed
#       0 successful
#
function build_random_mapping
{	
	typeset hostname=$1
	if [ $FULL_MAPPING -eq 1 ];then
		build_full_mapping
	else 
		build_1n_mapping $hostname
	fi
}

#
# NAME
#       build_full_mapping()
# DESCRIPTION
#       all the LUs are mapping to all the initator and target ports by default.
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function build_full_mapping
{	
	cti_report "set the default ALL LU Mapping."
	typeset retcode=0
	typeset cmd="$STMFADM list-lu | awk '{print \$NF}'"
	run_ksh_cmd "$cmd"
	get_cmd_stdout | while read lu
	do
		typeset cmd="$STMFADM add-view $lu"
		cti_report "EXECUTING: $cmd"
		run_ksh_cmd "$cmd"
		if [ `get_cmd_retval` -ne 0 ];then
			report_err "$cmd"
			(( retcode+=1 ))
		fi
	done
	if [ $retcode -eq 0 ];then
		return 0	
	else
		cti_fail "FAIL - build full mapping information failed."
		return 1
	fi
	
}

#
# NAME
#       build_1n_mapping()
# DESCRIPTION
#       build host group with each initiator port. 
#	  each host group has only one initiator port.
#	  map the created lun into host group randomly .
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#       1 failed
#       0 successful
#
function build_1n_mapping
{	
	cti_report "set the random LU mapping to initiator port."
	typeset host_name=$1
	typeset hg_count=0
	typeset retcode=0
	typeset hostname=`format_shellvar $host_name`
	eval typeset initiator_list="\$HOST_${hostname}_INITIATOR"
	for i_portWWN in $initiator_list
	do
		typeset index=`/usr/bin/printf "%03s" $hg_count`
		typeset cmd="$STMFADM create-hg hg$index"
		cti_report "EXECUTING: $cmd"
		run_ksh_cmd "$cmd"
		if [ `get_cmd_retval` -ne 0 ];then
			report_err "$cmd"
			(( retcode+=1 ))
		fi			
		typeset cmd="$STMFADM add-hg-member -g hg$index $i_portWWN"
		run_ksh_cmd "$cmd"
		cti_report "EXECUTING: $cmd"
		if [ `get_cmd_retval` -ne 0 ];then
			report_err "$cmd"
			(( retcode+=1 ))
		fi			
		(( hg_count+=1 ))
	done

	typeset cmd="$STMFADM list-lu | awk '{print \$NF}'"
	run_ksh_cmd "$cmd"
	get_cmd_stdout | while read lu
	do
		typeset rdm=`expr $RANDOM % $hg_count`
		typeset index=`/usr/bin/printf "%03s" $rdm`
		typeset cmd="$STMFADM add-view -h hg$index $lu"
		cti_report "EXECUTING: $cmd"
		run_ksh_cmd "$cmd"
		if [ `get_cmd_retval` -ne 0 ];then
			report_err "$cmd"
			(( retcode+=1 ))
		fi
	done
	if [ $retcode -eq 0 ];then
		return 0	
	else
		cti_fail "FAIL - build random mapping information failed."
		return 1
	fi
}
#
# NAME
#       cleanup_mapping()
# DESCRIPTION
#       clean up all the host group, view, and logical unit mapping information.
#	after each fault injection test, the mapping database should be cleaned 
#	up.
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function cleanup_mapping
{	
	typeset retcode=0
	cti_report "clean up the mappming info."
	env_stmf_cleanup
	retcode=$?
	return $retcode
}
#
# NAME
#       create_default_lun()
# DESCRIPTION
#       create the specified number of luns to run I/O tests with diskomizer 
#	the VOL_MAX is defined in the configuration file
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function create_default_lun
{	
	cti_report "create the $VOL_MAX LUNs of variable"\
		"VOL_MAX specified in test_config."
	typeset retcode=0
	build_fs zdsk
	if [ $? -eq 1 ];then
		cti_uninitiated "can not create the default $VOL_MAX LUNs,"\
			"aborting"
		cti_deleteall "LUNs missed!"
		return 1
	fi

	typeset vol_num=0
	while [ $vol_num -lt $VOL_MAX ]
	do
		typeset vol_id=`/usr/bin/printf "%03s" $vol_num`
		typeset vol_name=vol${vol_id}
		
		fs_zfs_create -V $VOL_SIZE $ZP/${vol_name}			
		typeset cmd="$SBDADM create-lu $DEV_ZVOL/$ZP/${vol_name}"
		cti_report "EXECUTING: $cmd"
		run_ksh_cmd "$cmd"
		if [ `get_cmd_retval` -ne 0 ];then
			report_err "$cmd"
			(( retcode+=1 ))
		fi
		(( vol_num+=1 ))
	done
	if [ $retcode -eq 0 ];then
		cti_pass "create the $VOL_MAX LUNs successfully which will be"\
			"existing until deleted apparently"
		return 0	
	else
		cti_fail "FAIL - create $VOL_MAX LUNs failed."
		return 1
	fi
}

#
# NAME
#       cleanup_default_lun()
# DESCRIPTION
#       cleanup the specified number of existing luns 
#
# ARGUMENT
#
# RETURN
#       1 failed
#       0 successful
#
function cleanup_default_lun
{	
	typeset retcode=0
	cti_report "clean up all the existing LUNs."
	env_sbd_cleanup
	(( retcode+=$? ))
        clean_fs zdsk
	(( retcode+=$? ))
        if [ $retcode -ne 0 ];then
                return 1
        fi
	return 0
}
#
# NAME
#	build_tpgt_portals()
# DESCRIPTION
#	add all the target portal into target portal group with specified tag.
#
# ARGUMENT
#	$1 - host name
#	$2 - the specified tpg tag number
#
# RETURN
#	void
#
function build_tpgt_portals
{
	typeset host_name=$1
	typeset tpg=$2

	typeset port_list=$(get_portal_list $host_name)
	itadm_create POS tpg $tpg $port_list
}

#
# NAME
#	build_tpgt_1portal()
# DESCRIPTION
#	each target portal group is consisted of only target portal
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	void
#
function build_tpgt_1portal
{
	typeset host_name=$1

	typeset idx=1
	typeset port_list=$(get_portal_list $host_name)
	for portal in $port_list
	do
		itadm_create POS tpg $idx $portal
		(( idx+=1 ))
	done
}

#
# NAME
#	get_tpgt_list()
# DESCRIPTION
#	get all the tgt tag list with token ','
#
# ARGUMENT
#	$1 - host name
#
# RETURN
#	void
#
function get_tpgt_list
{
	echo $(echo $G_TPG | tr ' ' ',')
}

