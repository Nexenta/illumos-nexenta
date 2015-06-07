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

# Global variable defined in this file
#
#	INITIATOR_${node_name}_DISCOVERY_isns_STATUS
#	INITIATOR_${node_name}_DISCOVERY_isns_PARAM
#	
#	INITIATOR_${node_name}_DISCOVERY_sendTargets_STATUS
#	INITIATOR_${node_name}_DISCOVERY_sendTargets_PARAM
#	
#	INITIATOR_${node_name}_DISCOVERY_static_STATUS
#	INITIATOR_${node_name}_DISCOVERY_static_PARAM
#	
#	INITIATOR_${node_name}_CHAP_SECRET
#	INITIATOR_${node_name}_CHAP_NAME
#	INITIATOR_${node_name}_AUTH
#	INITIATOR_${node_name}_R_ACCESS
#	INITIATOR_${node_name}_R_SERVER
#	
#	INITIATOR_${node_name}_T_PARAM  -- For debug only
#
#	INITIATOR_${node_name}_T_${target_name}_AUTH
#	INITIATOR_${node_name}_T_${target_name}_CHAP_SECRET
#	INITIATOR_${node_name}_T_${target_name}_CHAP_NAME
#	INITIATOR_${node_name}_T_${target_name}_BI
#

#
# NAME
#	iscsiadm_info_init
# DESCRIPTION
# 	Initialize global default variables.
#
#		INITIATOR_${ISCSI_IHOST}_NODE_NAME
#		INITIATOR_CONFIGURED_SESSIONS
#
# ARGUMENT
#	void
#
# RETURN
#	void
#
function iscsiadm_info_init
{
	typeset host="${1}"
	typeset cmd node_name host_var	
	cmd="${ISCSIADM} list initiator-node"
	cmd="${cmd} |grep \"Initiator node name:\" | awk '{print \$NF}'"

	run_rsh_cmd "${host}" "${cmd}"
	node_name="$(get_cmd_stdout)"
	host_var="$(format_shellvar ${host})"
	set_global_variable "INITIATOR_${host_var}_NODE_NAME" \
		"${node_name}"

	set_global_variable "INITIATOR_CONFIGURED_SESSIONS" "1"
}

#
# NAME
#	iscsiadm_i_node_name_get
# DESCRIPTION
#	Return initiator node name by "echo"
#
# ARGUMENT
#	$1 - host name of initiator
#
# RETURN
#	
#
function iscsiadm_i_node_name_get
{
	typeset host="${1}"
	typeset host_var="$(format_shellvar ${host})"
	typeset i_node
	
	eval i_node="\"\${INITIATOR_${host_var}_NODE_NAME}\""
	echo "${i_node}"	
}
#
# NAME
#	iscsiadm_i_node_name_formatted
# DESCRIPTION
#	Return the formatted initiator node name by "echo"
#
# ARGUMENT
#	$1 - host name of initiator
#
# RETURN
#	
function iscsiadm_i_node_name_formatted
{
	typeset host="${1}"
	typeset i_node

	i_node="$(iscsiadm_i_node_name_get ${host})"
	i_node="$(format_shellvar ${i_node})"

	echo "${i_node}"	
}

#
# NAME
#	iscsiadm_add_info
# DESCRIPTION
# 	Store information about added objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the initiator host name
#	$2 - the valid object type
#	$3 - the overall command option
#
# RETURN
#	void
#
function iscsiadm_add_info
{
	typeset host="${1}"
	typeset object="${2}"
	typeset options="${3}"

	case "${object}" in
	"discovery-address")
		add_discovery_param "${host}" "sendTargets" "${options}"	
		;;

	"isns-server")
		add_discovery_param "${host}" "isns" "${options}"	
		;;

	"static-config")
		add_discovery_param "${host}" "static" "${options}"	
		;;

	*)
		cti_report "unknow object - ${object}"
		;;
	esac
}

#
# NAME
#	iscsiadm_remove_info
# DESCRIPTION
# 	Delete information about stored objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the initiator host name
#	$2 - the valid object type
#	$3 - the overall command option
#
# RETURN
#	void
#
function iscsiadm_remove_info
{
	typeset host="${1}"
	typeset object="${2}"
	typeset options="${3}"

	case "${object}" in
	"discovery-address")
		remove_discovery_param "${host}" "sendTargets" "${options}"
		;;

	"isns-server")
		remove_discovery_param "${host}" "isns" "${options}"	
		;;

	"static-config")
		remove_discovery_param "${host}" "static" "${options}"	
		;;

	"target-param")
		remove_target_param "${host}" "${options}"	
		;;

	*)
		cti_report "unknow object - ${object}"
		;;
	esac
}


#
# NAME
#	iscsiadm_modify_info
# DESCRIPTION
# 	Modify information about stored objects based on information
# 	passed to the function as arguments.
#
# ARGUMENT
#	$1 - the initiator host name
#	$2 - the valid object type
#	$3 - the overall command option
#
# RETURN
#	void
#
function iscsiadm_modify_info
{
	typeset host="${1}"
	typeset object="${2}"
	typeset options="${3}"

	case "${object}" in
	"discovery")
		modify_discovery_status "${host}" ${options}	
		;;

	"initiator-node")
		modify_initiator "${host}" ${options}
		;;

	"target-param")
		modify_target_param "${host}" ${options}
		;;

	*)
		cti_report "unknow object - ${object}"
		;;
	esac
}
#
# NAME
#	supply_defalut_port
#
# DESCRIPTION
#	Add a defult port to and address if the address do not
#	contain a port
#
# ARGUMENT
#	${1} - address
#	${2} - address type (isns sever, statis discovery address
#		radius server )
#
# RETURN
#	void
#
function supply_default_port
{
	typeset address="${1}"
	typeset type="${2}"

	if [[ "$( echo ${address} | egrep : )" == "" ]] ; then

		case ${type} in
			"isns")
				address="${address}:3205"
				;;
			"radius")
				address="${address}:1812"
				;;
			"static")
				address="${address}:3260"
				;;
			"sendTargets")
				address="${address}:3260"
				;;
		esac
	fi
	echo "${address}"
}
#
# NAME
#	add_discovery_param
#
# DESCRIPTION
#	Set parameter of specified discovery method in memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$* - options 
#	
#	Example:
#	add_discovery_param $host isns 10.10.0.1 10.10.0.2
#	add_discovery_param $host sendTargets 10.10.0.1
#	add_discovery_param $host static \
#			iqn.2004-09.sun.com,192.168.0.0:3260,1
#
# RETURN
#	void
#
function add_discovery_param
{
	typeset host="${1}"
	typeset method="${2}"	
	typeset options="${3}"
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset item item_list
	typeset old_value new_value var_name replace

	var_name="INITIATOR_${i_node}_DISCOVERY_${method}_PARAM"
	eval old_value="\"\${${var_name}:=''}\""
	item_list=""
	for item in ${options} 
	do
		if [[ ${method} == "static" ]] then
			typeset t_and_p tpgt	
			t_and_p="$( echo ${item} | cut -d, -f1-2 )"
			tpgt="$( echo ${item} | cut -d, -f3 )"
			t_and_p="$( supply_default_port ${t_and_p} ${method} )"
			item="${t_and_p},${tpgt}"
		else
			item="$( supply_default_port ${item} ${method} )"
		fi
		replace="echo ${old_value} | sed 's/${item}//g'"
		old_value="$( eval ${replace} )"
		item_list="${item_list} ${item}"
	
	done
	
	new_value="$(echo ${old_value} ${item_list} )"

	set_global_variable "${var_name}" "${new_value}"
}

#
# NAME
#	remove_discovery_param
#
# DESCRIPTION
#	Remove parameter of specified discovery method from memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$* - options 
#	
#	Example:
#	remove_discovery_param $host isns 10.10.0.1 10.10.0.2
#	remove_discovery_param $host sendTargets 10.10.0.1
#
# RETURN
#	void
#
function remove_discovery_param
{
	typeset host="${1}"
	typeset method="${2}"	
	typeset options="${3}"
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset item

	typeset old_value new_value replace var_name

	var_name="INITIATOR_${i_node}_DISCOVERY_${method}_PARAM"
	eval old_value="\"\${${var_name}:=''}\""
	
	for item in ${options} 
	do
		item="$( supply_default_port ${item} ${method} )"
		replace="echo ${old_value} | sed 's/${item}//g'"
		old_value="$( eval ${replace} )"
	done
	
	new_value="${old_value}"
	
	set_global_variable "${var_name}" "${new_value}"
}

#
# NAME
#	modify_discovery_status
#
# DESCRIPTION
#	Update discovery status information in memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$* - options 
#	
#	Example:
#	modify_discovery_status $host -s enable -t disable
#
# RETURN
#	void
#
function modify_discovery_status
{
	typeset host method usage i_node var_name
	host="${1}"
	shift 1

	i_node="$(iscsiadm_i_node_name_formatted ${host})"

	usage=""
	usage="${usage}s:(static)"
	usage="${usage}t:(sendtargets)"
	usage="${usage}i:(iSNS)"
	while getopts "${usage}" option 
	do
		case ${option} in
		"s")
			method="static"
			;;
		"t")
			method="sendTargets"
			;;
		"i")
			method="isns"
			;;
		"?")
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
		
		var_name="INITIATOR_${i_node}_DISCOVERY_${method}_STATUS"
		set_global_variable "${var_name}" "${OPTARG}"
	done
}

#
# NAME
#	modify_initiator
#
# DESCRIPTION
#	Update initiator information in memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$* - options 
#	
#	Example:
#	modify_initiator $host -a CHAP -H chap-name
#
# RETURN
#	void
#
function modify_initiator
{
	typeset host="${1}"
	shift 1

	typeset usage i_node address var_name
	usage=":"
	usage="${usage}a:(authentication)"
	usage="${usage}C:(CHAP-secret)"
	usage="${usage}c:(configured-sessions)"
	usage="${usage}d:(datadigest)"
	usage="${usage}h:(headerdigest)"
	usage="${usage}H:(CHAP-name)"
	usage="${usage}r:(radius-server)"
	usage="${usage}R:(radius-access)"


	i_node="$( iscsiadm_i_node_name_formatted ${host} )"

	while getopts "${usage}" option 
	do
		case ${option} in
		"a")
			var_name="INITIATOR_${i_node}_AUTH"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"C")
			var_name="INITIATOR_${i_node}_CHAP_SECRET"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"c")
			var_name="INITIATOR_${i_node}_SESSIONS"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"d")
			var_name="INITIATOR_${i_node}_DATA_DIGEST"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"h")
			var_name="INITIATOR_${i_node}_HEADER_DIGEST"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"H")
			var_name="INITIATOR_${i_node}_CHAP_NAME"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"r")
			address="$( supply_default_port ${OPTARG} radius)"
			var_name="INITIATOR_${i_node}_R_SERVER"
			set_global_variable "${var_name}" "${address}"
			;;
		"R")
			var_name="INITIATOR_${i_node}_R_ACCESS"
			set_global_variable "${var_name}" "${OPTARG}"
			;;
		"?")
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done
}

#
# NAME
#	modify_target_param
#
# DESCRIPTION
#	Update target parameter information in memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$* - options and target names
#	
#	Example:
#	modify_target_param $host -a CHAP -B enable iqn.2004-04.sun.com \
#		iqn.1986-03.sun.com 
#
# RETURN
#	void
#
function modify_target_param
{
	typeset host i_node target t_node  var_name usage
	typeset auth="" bi="" chap_s="" chap_n="" sessions=""
	typeset data_digest="" header_digest="" 

	host="${1}"
	shift 1

	usage=":"
	usage="${usage}a:(authentication)"
	usage="${usage}B:(bi-directional-authentication)"
	usage="${usage}C:(CHAP-secret)"
	usage="${usage}c:(configured-sessions)"
	usage="${usage}d:(datadigest)"
	usage="${usage}h:(headerdigest)"
	usage="${usage}H:(CHAP-name)"

	i_node="$(iscsiadm_i_node_name_formatted ${host})"

	while getopts "${usage}" option 
	do
		case ${option} in
		"a")
			auth="${OPTARG}"
			;;
		"B")
			bi="${OPTARG}"
			;;
		"C")
			chap_s="${OPTARG}"
			;;
		"c")
			sessions="${OPTARG}"
			;;
		"d")
			data_digest="${OPTARG}"
			;;
		"h")
			header_digest="${OPTARG}"
			;;
		"H")
			chap_n="${OPTARG}"
			;;
		"?")
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done

	# Work aroud for ksh93 bug (CR 6819961) 
	# Just take the last parameter as the target
	# This will not impcat the test case since all
	# case only modify param for one target at one time.

	# shift $(($OPTIND - 1))	
	shift $(($# - 1))	

	for target in ${*}
	do
		t_node="$(format_shellvar ${target})"
		if [[ ${auth} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_AUTH"
			set_global_variable "${var_name}" "${auth}"	
		fi
		if [[ ${chap_s} != "" ]] ; then 
			var_name="INITIATOR_${i_node}_T_${t_node}_CHAP_SECRET"
			set_global_variable "${var_name}" "${chap_s}"
		fi

		if [[ ${chap_n} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_CHAP_NAME"
			set_global_variable "${var_name}" "${chap_n}"
		fi
		
		if [[ ${bi} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_BI"
			set_global_variable "${var_name}" "${bi}"
		fi

		if [[ ${sessions} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_SESSIONS"
			set_global_variable "${var_name}" "${sessions}"
		fi
		if [[ ${data_digest} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_DATA_DIGEST"
			set_global_variable "${var_name}" "${data_digest}"
		fi
		if [[ ${data_digest} != "" ]] ; then
			var_name="INITIATOR_${i_node}_T_${t_node}_HEADER_DIGEST"
			set_global_variable "${var_name}" "${header_digest}"
		fi
		# Following 5 lines is for debug only
		typeset old_value new_value replace
		eval old_value="\${INITIATOR_${i_node}_T_PARAM:=''}"
		replace="echo ${old_value} | sed 's/${target}//g'"
		old_value="$( eval ${replace} )"
		new_value="${old_value} ${target}"
		set_global_variable "INITIATOR_${i_node}_T_PARAM" \
			"${new_value}"
	done
}

#
# NAME
#	remove_target_param
# DESCRIPTION
#	Remove target parameter information from memory
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$2 - target name 
#
# RETURN
#	void
#
function remove_target_param
{
	typeset host="${1}"
	typeset target="${2}"
	typeset i_node t_node

	i_node="$(iscsiadm_i_node_name_formatted ${host})"
	t_node="$(format_shellvar ${target_name})"

	unset_global_variable "INITIATOR_${i_node}_T_${t_node}_AUTH"
	unset_global_variable "INITIATOR_${i_node}_T_${t_node}_CHAP_SECRET"
	unset_global_variable "INITIATOR_${i_node}_T_${t_node}_CHAP_NAME"
	unset_global_variable "INITIATOR_${i_node}_T_${t_node}_BI"

	# Following 4 lines is for debug only
	typeset old_value new_value replace
	eval old_value="\${INITIATOR_${i_node}_T_PARAM:=''}"
	replace="echo ${old_value} | sed 's/${target}//g'"
	new_value="$( eval ${replace} )"

	set_global_variable "INITIATOR_${i_node}_T_PARAM" \
		"${new_value}"
}

