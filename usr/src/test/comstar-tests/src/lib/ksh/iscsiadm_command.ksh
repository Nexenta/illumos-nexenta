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
#	iscsiadm_add
#
# SYNOPSIS
#	iscsiadm_add [POS or NEG] <initiator_host> <object> 
#	[options for 'iscsiadm add' command]
#
# DESCRIPTION
#	Execute 'iscsiadm add' command on <initiator_host> and keep the <object>
#	information in memory
#
# RETURN VALUE
#	This function return the return value of the 'iscsiadm add'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function iscsiadm_add 
{
	typeset pos_neg="${1}"
	if [[ "${1}" == "NEG" || "${1}" == "POS" ]] ; then
		shift 1
	else
		typeset pos_neg="POS"
	fi

	typeset host="${1}"
	typeset object="${2}"
	shift 2	
	typeset options="${*}"

	# If object is discovery-address then get the portal right
	if [ $object = "discovery-address" ]; then
		# Use the ones other than host
		portal_list=`get_portal_list ${ISCSI_THOST}`
		options=$portal_list
	fi
				
	# Build the add command.
	typeset cmd="${ISCSIADM} add ${object} ${options}"

	cti_report "Executing: ${cmd} on ${host}"

	run_rsh_cmd "${host}" "${cmd}"
	typeset -i retval=`get_cmd_retval`
	
	if [[ ${retval} == 0 ]] ; then
		iscsiadm_add_info "${host}" "${object}" "${options}"
	else
		report_err "${cmd}"
	fi
	if [[ "${pos_neg}" == "POS" ]] ; then
		POS_result ${retval} "${cmd}"
	else
		NEG_result ${retval} "${cmd}"
	fi
	return ${retval}
}

#
# NAME
#	iscsiadm_remove
#
# SYNOPSIS
#	iscsiadm_remove [POS or NEG] <initiator_host> <object> 
#	[options for 'iscsiadm add' command]
#
# DESCRIPTION
#	Execute 'iscsiadm remove' command on <initiator_host> and keep the <object>
#	information in memory
#
# RETURN VALUE
#	This function return the return value of the 'iscsiadm remove'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function iscsiadm_remove 
{
	typeset pos_neg="${1}"
	if [[ "${1}" == "NEG" || "${1}" == "POS" ]] ; then
		shift 1
	else
		typeset pos_neg="POS"
	fi

	typeset host="${1}"
	typeset object="${2}"
	shift 2	
	typeset options="${*}"
				
	# Build the add command.
	typeset cmd="${ISCSIADM} remove ${object} ${options}"

	cti_report "Executing: ${cmd} on ${host}"

	run_rsh_cmd "${host}" "${cmd}"
	typeset -i retval=`get_cmd_retval`
	
	if [[ ${retval} == 0 ]] ; then
		iscsiadm_remove_info "${host}" "${object}" "${options}"
	else
		report_err "${cmd}"
	fi
	if [[ "${pos_neg}" == "POS" ]] ; then
		POS_result ${retval} "${cmd}"
	else
		NEG_result ${retval} "${cmd}"
	fi
	return ${retval}
}

#
# NAME
#	iscsiadm_modify
#
# SYNOPSIS
#	iscsiadm_modify [POS or NEG] <initiator_host> <object> 
#	[options for 'iscsiadm modify' command]
#
# DESCRIPTION
#	Execute 'iscsiadm modify' command on <initiator_host> and keep the 
#	<object> information in memory
#
# RETURN VALUE
#	This function return the return value of the 'iscsiadm modify'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function iscsiadm_modify
{
	typeset pos_neg="${1}"
	if [[ "${1}" == "NEG" || "${1}" == "POS" ]] ; then
		shift 1
	else
		typeset pos_neg="POS"
	fi

	typeset host="${1}"
	typeset object="${2}"
	shift 2	
	typeset options="${*}"
				
	# Build the modify command.
	typeset secret_found=1
	typeset usage=":" 
	usage="${usage}C:(CHAP-secret)"
	while getopts "${usage}" option 
	do
		case ${option} in
		"C")
			typeset secret_string=$OPTARG
			secret_found=0
			;;
		"?")
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done
	if [[ ${secret_found} == 0 ]] ; then
		typeset n_options=$(echo ${options} | \
				sed -e "s/\<${secret_string}\>//g")
		typeset cmd="${ISCSIADM} modify $object $n_options"
		typeset message="Executing: ${cmd} with secret"
		message="${message} [${secret_string}] on ${host}"
		cti_report "${message}"
		run_ksh_cmd "${SETCHAPSECRET_rsh} \"${cmd}\" ${secret_string} \
				${host}"
		get_cmd_stdout | grep 'ret=0' >/dev/null 2>&1
                echo $? > ${CMD_RETVAL}
	else
		typeset cmd="${ISCSIADM} modify $object $options"
		cti_report "Executing: ${cmd} on ${host}"
		run_rsh_cmd "${host}" "${cmd}"
	fi

	typeset -i retval=`get_cmd_retval`
	
	if [[ ${retval} == 0 ]] ; then
		iscsiadm_modify_info "${host}" "${object}" "${options}"
	else
		report_err "${cmd}"
	fi
	if [[ "${pos_neg}" == "POS" ]] ; then
		POS_result ${retval} "${cmd}"
	else
		NEG_result ${retval} "${cmd}"
	fi
	return ${retval}
}

#
# NAME
#	initiator_node_cleanup
#
# DESCRIPTION
#	Reset all initiator node's attributes to default value
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN VALUE
#
#
function initiator_node_cleanup
{
	typeset host="${1}"
	typeset ret=0
	run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -A ''"
	(( ret= ${ret} + ${?} )) 
	run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -h none"
	(( ret= ${ret} + ${?} )) 
	run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -d none"
	(( ret= ${ret} + ${?} )) 
	# Not supported by iscsiadm command
	# run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -C ''"
	
	# Need to set radius server first
	# run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -R disable"

	# Not supported by iscsiadm command
	# run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -r ''"
	
	# Not supported by iscsiadm command
	# run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -P ''"

	run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -H ''"
	(( ret= ${ret} + ${?} )) 
	run_rsh_cmd "${host}" "${ISCSIADM} modify initiator-node -c 1"
	(( ret= ${ret} + ${?} )) 

	return ${ret}
}

#
# NAME
#	initiator_discovery_cleanup
#
# DESCRIPTION
#	Disable all discovery method and remove their all configuration
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN VALUE
#	
function initiator_discovery_cleanup
{
	typeset host="${1}"
	typeset cmd
	typeset ret=0

	# SendTargets
	cmd="${ISCSIADM} list discovery-address | cut -d: -f2-"
	run_rsh_cmd "${host}" "${cmd}"

	if [ -s $CMD_STDOUT ]; then
	   addrs=`get_cmd_stdout`
	   run_rsh_cmd "${host}" "${ISCSIADM} modify discovery -t disable"

	   for line in $addrs; do
	      run_rsh_cmd "${host}" "${ISCSIADM} remove discovery-address \
				${line}"
	   done
	fi

	#
	# iSNS is not supported hence removed
	#

	# Static
	cmd="${ISCSIADM} list static-config | cut -d: -f2-"
	run_rsh_cmd "${host}" "${cmd}"

	if [ -s $CMD_STDOUT ];then
	   portals=`get_cmd_stdout`
	   run_rsh_cmd "${host}" "${ISCSIADM} modify discovery -s disable"

	   for line in $portals; do
	      run_rsh_cmd "${host}" "${ISCSIADM} remove static-config \
			${line}"
	   done
	fi
}

#
# NAME
#	initiator_target_param_cleanup
#
# DESCRIPTION
#	Remove all configured target-param
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN VALUE
#	
function initiator_target_param_cleanup
{
	typeset host="${1}"
	typeset cmd 
	typeset ret=0 

	cmd="${ISCSIADM} list target-param |grep Target: | cut -d: -f2-"
	run_rsh_cmd "${host}" "${cmd}"
	(( ret= ${ret} + ${?} )) 
	
	get_cmd_stdout | while read line
	do
		run_rsh_cmd "${host}" "${ISCSIADM} modify target-param -a none ${line}"
		run_rsh_cmd "${host}" "${ISCSIADM} modify target-param -B disable ${line}"
		run_rsh_cmd "${host}" "${ISCSIADM} modify target-param -d none ${line}"
		run_rsh_cmd "${host}" "${ISCSIADM} modify target-param -h none ${line}"
		run_rsh_cmd "${host}" "${ISCSIADM} remove target-param ${line}"
		(( ret= ${ret} + ${?} )) 
	done		

	return ${ret}
}

#
# NAME
#	initiator_cleanup
#
# DESCRIPTION
#	Remove all objects configed on the initiator 
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN VALUE
#	0 - Success
#	1 - Fail
#
function initiator_cleanup
{
	typeset host="${1}"
	typeset ret=0
	cti_report "iscsi initiator host [$host] is cleaning up itself"
	initiator_node_cleanup "${host}"
	(( ret= ${ret} + ${?} )) 
	initiator_target_param_cleanup "${host}" 
	(( ret= ${ret} + ${?} )) 
	initiator_discovery_cleanup "${host}"
	(( ret= ${ret} + ${?} )) 

	return ${ret}
}

function iscsiadm_setup_static {

	targs=`itadm list-target|grep iqn|nawk '{print $1}'`
	eval set -A portal $(get_portal_list ${ISCSI_THOST})
	eval set -A t $targs
	iscsiadm_modify POS $ISCSI_IHOST discovery -s disable

	check_enable_mpxio
	if [ $? -ne 0 ]; then
		iscsiadm_add POS $ISCSI_IHOST static-config "${t[0]},${portal[0]}"
	else
		#
		# Multi-pathing with two portals
		#
		iscsiadm_add POS $ISCSI_IHOST static-config "${t[0]},${portal[0]}"
		iscsiadm_add POS $ISCSI_IHOST static-config "${t[1]},${portal[1]}"
	fi
}
