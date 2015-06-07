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

# This script define following type of global variables
#	D_I_${i_node}_T   --- Expected Target
#	E_I_${i_node}_T   --- Existing Target
#	D_I_${i_node}_T_${t_node}_L   --- Expected Luns
#	E_I_${i_node}_T_{t_node}_L    --- Expected Luns
#

# NAME
#	iscsiadm_verify
# DESCRIPTION
#	Compare the actual object list to what the test suite 
#	thinks the object list should be.
#
# ARGUMENT
#	$1 - iscsi initiator host name
#	$2 - object to be verify
#
# RETURN
#	Sets the result code
#	void
#
function iscsiadm_verify
{
	typeset host="${1}"
	typeset object="${2}"

	case ${object} in
		"target")
			iscsiadm_verify_target "${host}"
			;;
		"lun")
			iscsiadm_verify_lun "${host}"
			;;
		*)
			cti_report "iscsiadm_vefiy: unkown option - ${object}"
		;;
	esac
}


#
# NAME
#	expected_target_lun_list
#
# DESCRIPTION
#	Calculate expected targets and luns which can be visited by
#	initiator
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function expected_target_lun_list
{
	typeset host="${1}"
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"

	expected_target_list "${host}"

	typeset target_list
	eval target_list="\"\${D_I_${i_node}_T}\""

	typeset target
	for target in ${target_list}
	do
		expected_lun_list "${host}" "${target}" 
	done
}

#
# NAME
#	is_isns_matched
#
# DESCRIPTION
#	Check whether isns discovery method is enabled on both initiator and 
#	target host and their configured isns servers contains a same one
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	"yes" - if matched
#	""    - if not matched
#
function is_isns_matched
{
	typeset host="${1}"
	typeset isns_status_i isns_param_i  var_name
	typeset isns_status_t isns_param_t 	
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"

	var_name="INITIATOR_${i_node}_DISCOVERY_isns_STATUS"
	eval isns_status_i="\"\${${var_name}:=disable}\""
	var_name="INITIATOR_${i_node}_DISCOVERY_isns_PARAM"
	eval isns_param_i="\"\${${var_name}:=}\""

	eval isns_status_t="\"\${DEFAULTS_ISNS_ENABLE:=disable}\""
	eval isns_param_t="\"\${DEFAULTS_ISNS_SERVER:=}\""

	if [[ "${isns_status_i}" == "enable" &&
	    "${isns_status_t}" == "enabled" ]] ; then
		# If isns_param_t and isns_param_i contains a same
		# isns server, then we think initiator can discovery
		# the targets through the isns server 
		typeset server
		for server in ${isns_param_i}
		do
			if [[ "$(echo ${isns_param_t} | \
			    egrep ${server})" != "" ]] ; then
				echo "yes"
				return
			fi	
		done
	fi
	cti_report "info: isns does not match" 
}

#
# NAME
#	is_sendTargets_matched
#
# DESCRIPTION
#	Check whether sendTargets discovery method is enabled on initiator and 
#	its discovery address contains one active portal
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	"yes" - if matched
#	""    - if not matched
#
function is_sendTargets_matched
{
	typeset host="${1}"
	typeset st_status_i st_param_i var_name
	typeset i_n="$(iscsiadm_i_node_name_formatted ${host})"

	var_name="INITIATOR_${i_n}_DISCOVERY_sendTargets_STATUS"
	eval st_status_i="\"\${${var_name}:=disable}\""
	var_name="INITIATOR_${i_n}_DISCOVERY_sendTargets_PARAM"
	eval st_param_i="\"\${${var_name}:=}\""

	if [[ "${st_status_i}" == "enable" ]] ; then 
		# If the sendtargets discovery address catains any portal
		# which is included in any defined target portal group,
		# then we think the initiator can discovery all targets
		# through sendtargets method. 
		typeset tpg
		for tpg in ${G_TPG} 
		do
			typeset portal portal_group
			eval portal_group="\"\${TPG_${tpg}_PORTAL}\""
			for portal in ${portal_group}
			do
				if [[ "$(echo "${st_param_i}" | \
				    egrep ${portal})" != "" ]] ; then
					echo "yes"
					return
				fi	
			done
		done
	fi
	cti_report "info: sendTargets does not  match" 
}

#
# NAME
#	static_target_list
#
# DESCRIPTION
#	Output the static configured target info
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function static_target_list
{
	typeset host="${1}"
	typeset target_list target_name portal tpgt
	typeset static_param
	typeset t_node
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"

	eval static_param="\"\${INITIATOR_${i_node}_DISCOVERY_STATIC_PARAM}\""

	typeset item
	for item in ${static_param}	
	do
		# For static configured target, we only support
		# one tpgt for each target currently.
		target_name="$( echo ${item} | cut -d, -f1 )"	
		portal="$( echo ${item} | cut -d, -f2 )"	
		tpgt="$( echo ${item} | cut -d, -f3 )"	
		
		target_list="${target_list} ${target_name}"
		t_node="$(format_shellvar ${target_name})"
		set_tmp_global_variable "D_I_${i_node}_T_${t_node}_DIS" \
					"static" 	
		set_tmp_global_variable "D_I_${i_node}_T_${t_node}_DIS_PORTAL" \
					"${portal}" 	
		set_tmp_global_variable "D_I_${i_node}_T_${t_node}_DIS_TPGT" \
					"${tpgt}" 	

	done
	
	echo "${target_list}"
}
#
# NAME
#	expected_target_list
#
# DESCRIPTION
#	Calculate expected targets which can be visited by
#	initiator
#	Set the global variables
#		D_I_${i_node}_T
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function expected_target_list
{
	typeset host="${1}"
	typeset list=""
	typeset static_list=""
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset static_discovery var_name

	if [[ "$(is_isns_matched ${host})" == "yes" || 
	    "$(is_sendTargets_matched ${host})" == "yes" ]] ; then
		eval list="\"${G_TARGET:=}\""
	fi

	# Loop the G_TARGET to find the TPGT attribute for target. 
	typeset target t_node tpgt
	for target in ${list}
	do
		t_node="$(format_shellvar ${target})"
		eval tpgt="\"\$TARGET_${t_node}_TPG_VAL\""
		set_tmp_global_variable \
			"D_I_${i_node}_T_${t_node}_DIS_TPGT" "${tpgt}"	
		
	done
	
	var_name="INITIATOR_${i_node}_DISCOVERY_static_STATUS"
	eval static_discovery="\"\${${var_name}}\""
	
	# TGPT attribute for static added target already be set 
	# at function static_target_list()
	[[ "${static_discovery}" == enable ]] &&
		list="${list} $(static_target_list ${host} )"

	set_tmp_global_variable "D_I_${i_node}_T" "${list}"
}

#
# NAME
#	target_verify_initiator
#
# DESCRIPTION
#	Check whether target can authenticate initiator successfully
#
# INPUT
#	${1} - auth_i: Authenticate method on initiator side
#	${2} - name_i: Chap name of initiator on initiator side
#	${3} - secret_i: Chap secret of initiator on initiator side
#	${4} - auth_t: Authenticate method on target side
#	${5} - name_t_i: Chap name of initiator on target side
#	${6} - secret_t_i: Chap secret of initiator on target side
#
# RETURN
#	"pass" - If authenticated successfully
#	""     - If authenticated failed
#
function target_verify_initiator
{
	typeset auth_i="${1}" name_i="${2}" secret_i="${3}"
	typeset auth_t="${4}" name_t_i="${5}" secret_t_i="${6}"

	#if [[ "${auth_t}" == "none" && "${auth_i}" == "none" ]] ; then
	if [[ "${auth_t}" == "none" ]] ; then
		# No Auth
		echo "pass"
		return 
	#elif [[ "${auth_t}" == "chap" && "${auth_i}" == "chap" ]] ; then
	elif [[ "${auth_t}" == "chap" ]] ; then
		# Chap Auth: Compare the name and secret
		if [[ "${name_i}" == "${name_t_i}" &&
		    "${secret_i}" == "${secret_t_i}" ]] ; then
			echo "pass"
			return
		fi

	elif [[ "${auth_t}" == "radius" ]] ; then
		# Not support radius currently
		echo ""
		return
	fi
	
	cti_report "info: target verify intiator failed" 
}

#
# NAME
#	initiator_verify_target
#
# DESCRIPTION
#	Check whether initiator can authenticate target successfully
#
# INPUT
#	${1} - auth_i_t: Target authenticate method on initiator side
#	${2} - name_i_t: Chap name of target on initiator side
#	${3} - secret_i_t: Chap secret of target on initiator side
#	${4} - bi_i_t: Bi-directional-authentication of target on initiator side
#	${5} - r_access_i: Radius enable/disable on initiator side
#	${6} - name_t: Chap name of target on target side
#	${7} - secret_t: Chap secret of target on target side
#
# RETURN
#	"pass" - If authenticated successfully
#	""     - If authenticated failed
#
function initiator_verify_target
{
	typeset auth_i_t="${1}"	name_i_t="${2}"	secret_i_t="${3}"
	typeset bi_i_t="${4}"	r_access_i="${5}"
	typeset name_t="${6}"   secret_t="${7}"		

	if [[ "${auth_i_t}" == "none" || 
	    ${bi_i_t} == "disable" ]] ; then
		# No Bi-auth required
		echo "pass"
		return
	elif [[ "${auth_i_t}" == "CHAP" && 
	    "${r_access_i}" == "disable" ]] ; then
		# Bi-auth: Compare the name and secret
		if [[ "${name_t}" == "${name_i_t}" &&
		    "${secret_t}" == "${secret_i_t}" ]] ; then
			echo pass
			return
		fi

	elif [[ "${auth_i_t}" == "CHAP" &&
	    "${r_access_i}" == "enable" ]] ; then
		# Not support radius currently
		echo ""
		return 
	fi

	cti_report "info: initiator verify target failed" 
}

#
# NAME
#	verify_secret
#
# DESCRIPTION
#	If bi-directional-authentication is required, check whether the secrets
#	of initiator and target are identical. It's illegal if they are 
#	idnetical.
#
# INPUT
#	${1} - bi_i_t: Bi-directional-authentication of target on initiator side
#	${2} - secret_i: Chap secret of initiator 
#	${3} - secret_t: Chap secret of 
#
# RETURN
#	"pass" - If authenticated successfully
#	""     - If authenticated failed
#
function verify_secret
{
	typeset bi_i_t="${1}" secret_i="${2}" secret_t="${3}"
	
	case "${bi_i_t}" in

		"disable")
			echo "pass"
			return
			;;
		"enable")
			# These two secret should not equal
			if [[ "${secret_i}" != "${secret_t}" ]] ; then 
				echo "pass"
				return
			fi
			;;	
		"*")
			;;
	esac
	cti_report "info: verify secret failed" 
}

#
# NAME
#	is_auth_matched
#
# DESCRIPTION
#	Check to see whethe initiator and target can authenticate each other 
#	successfully
#
# INPUT
#	${1} - Host name of initiator
#	${2} - Target node name
#
# RETURN
#	"pass" - If authenticated successfully
#	""     - If authenticated failed
#
function is_auth_matched
{
	typeset host="${1}"
	typeset target="${2}"
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset t_node="$(format_shellvar ${target})"

	typeset auth_i secret_i name_i auth_i_t secret_i_t name_i_t bi_i_t
	typeset auth_t secret_t name_t secret_t_i name_t_i
	typeset var_name
	
	eval auth_i="\"\${INITIATOR_${i_node}_AUTH:=none}\""
	eval name_i="\"\${INITIATOR_${i_node}_CHAP_NAME:=}\""
	eval secret_i="\"\${INITIATOR_${i_node}_CHAP_SECRET:=}\""

	eval auth_i_t="\"\${INITIATOR_${i_node}_T_${t_node}_AUTH:=none}\""
	eval name_i_t="\"\${INITIATOR_${i_node}_T_${t_node}_CHAP_NAME:=}\""
	var_name="INITIATOR_${i_node}_T_${t_node}_CHAP_SECRET"
	eval secret_i_t="\"\${${var_name}:=}\""
	eval bi_i_t="\"\${INITIATOR_${i_node}_T_${t_node}_BI:=disable}\""

	eval r_access_i="\"\${INITIATOR_${i_node}_R_ACCESS:=disable}\""

	eval auth_t="\"\${TARGET_${t_node}_AUTH_VAL:=none}\""
	[[ -n "$(echo ${auth_t} | grep default)" ]] &&
		eval auth_t="\"\${DEFAULTS_AUTH:=none}\""

	eval name_t="\"\${TARGET_${t_node}_USER:=}\""
	eval secret_t="\"\${TARGET_${t_node}_SECRET:=}\""

	eval name_t_i="\"\${TARGET_AUTH_INITIATOR_${i_node}_USER:=}\""
	eval secret_t_i="\"\${TARGET_AUTH_INITIATOR_${i_node}_SECRET:=}\""

	# target verify initiator
	
	if [[ $(target_verify_initiator \
		"${auth_i}" "${name_i}" "${secret_i}" \
		"${auth_t}" "${name_t_i}" "${secret_t_i}") == "pass"  && 
	      $(initiator_verify_target \
		"${auth_i_t}" "${name_i_t}" "${secret_i_t}" "${bi_i_t}" \
		"${r_access_i}" "${name_t}" "${secret_t}") == "pass" &&
	      $(verify_secret "${bi_i_t}" "${secret_i}" \
		"${secret_t}") == "pass" ]] ;
	then
		echo "yes"
	fi
}

#
# NAME
#	is_target_actived
#
# DESCRIPTION
#	Check whether a target is a static configured. If it is a static 
#	configured target, then its portal should be one active portal 
#	on target host, otherewise this target is not actived. If it is not
#	a static configured target, then it is actived by default
#
# INPUT
#	${1} - Host name of initiator 
#	${2} - Target nond node
#
# RETURN
#	"yes" - If the target is actived
#
function is_target_actived
{
	typeset host="${1}"
	typeset target="${2}"
	typeset list=""
	typeset discovery_method portal
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset t_node="$(format_shellvar ${target})"

	eval discovery_method="\"\${D_I_${i_node}_T_${t_node}_DIS:=}\""
	eval portal="\"\${D_I_${i_node}_T_${t_node}_DIS_PORTAL:=}\""

	if [[ ${discovery_method} == "" ]] ; then
		echo "yes"
		return 
	elif  [[ ${discovery_method} == "static" ]] ; then

		# If the static configured portal is contained by one target
		# portal group of the target, then we consider the target is 
		# actived on initiator side
		typeset tpg tpg_list
		eval tpg_list="\"\${TARGET_${target}_TPG}\""
		for tpg in ${tpg_list} 
		do
			eval typeset portal_group="\${TPG_${tpg}_PORTAL}"	
			if [[ "$(echo "${portal_group}" | \
			    egrep ${portal})" != "" ]] ; then
				echo "yes"
				return
			fi	
		done
	fi
	cti_report "info: taget is not active on host[${host}]" 
}	
#
# NAME
#	expected_lun_list
#
# DESCRIPTION
#	Calculate expected luns which can be visited by
#	initiator through a specific target
# 	Set the global variable 
#		"D_I_${i_node}_T_${target_name}_L"
#
# INPUT
#	${1} - Host name of initiator 
#	${2} - Target nond node
#
# RETURN
#	void
#
function expected_lun_list
{
	typeset host="${1}"
	typeset target="${2}"
	typeset list=""
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset t_node="$(format_shellvar ${target})"

	if [[ "$(is_auth_matched ${host} ${target})" == "yes" &&
	    "$(is_target_actived ${host} ${target})" == "yes" ]] ; then
		eval list="\"\${VISIBLE_${i_node}_${t_node}_GUID:=}\""
	fi

	set_tmp_global_variable "D_I_${i_node}_T_${t_node}_L" "${list}"
}

#
# NAME
#	existing_target_lun_list
#
# DESCRIPTION
#	Collect targets and luns listed on initiator host
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function existing_target_lun_list
{
	# Before run iscsiadm list target, we should remove all static 
	# configed targets 
	typeset host="${1}"
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"

	existing_target_list "${host}"

	typeset target target_list
	eval target_list="\"\${E_I_${i_node}_T}\""

	for target in ${target_list}
	do
		existing_lun_list "${host}" "${target}" 
	done
}

#
# NAME
#	existing_target_list
#
# DESCRIPTION
#	Collect targets listed on initiator host
#	Set the global variables
#		E_I_${i_node}_T
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function existing_target_list
{
	typeset host="${1}"
	typeset list=""
	typeset cmd

	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"

	cmd="${ISCSIADM} list target |grep Target: |sort -u"
	
	cti_report "Executing: ${cmd} on ${host}"
	run_rsh_cmd "${host}" "${cmd}"

	get_cmd_stdout | while read line
	do
		typeset t_name="$(echo ${line} | cut -d' ' -f2)"
		list="${list} ${t_name}"	
	done

	# Following for loop to get TPGT attribute for each target
	typeset target t_node
	for target in ${list}
	do
		typeset tpgt=""
		cmd="${ISCSIADM} list target ${target} | grep TPGT"
		cti_report "Executing: ${cmd} on ${host}"
		run_rsh_cmd "${host}" "${cmd}"

		get_cmd_stdout | while read line
		do
			typeset tpg_number			
			tpg_number="$(echo ${line} | cut -d: -f2)"
			tpgt="${tpgt} $(echo ${tpg_number})"
		done
		
		# sort the tpgt here
		tpgt="$(echo $tpgt | tr ' ' '\n' | sort -nb +0 | tr '\n' ' ')"
		t_node="$(format_shellvar ${target})"
		set_tmp_global_variable \
			"E_I_${i_node}_T_${t_node}_DIS_TPGT" "${tpgt}"	
	done

	set_tmp_global_variable "E_I_${i_node}_T" "${list}"
}

#
# NAME
#	existing_lun_list
#
# DESCRIPTION
#	Collect luns connected throuth a specified target on initiator host
#	Set the global variables
#		E_I_${i_node}_T_${t_node}_L
#
# INPUT
#	${1} - Host name of initiator 
#	${2} - Target node name
#
# RETURN
#	void
#
function existing_lun_list
{
	typeset host="${1}"
	typeset target="${2}"
	typeset list=""

	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	typeset t_node="$(format_shellvar ${target})"

	if [[ "$(is_target_actived ${host} ${target})" == "yes" ]] ; then
		# If the target is not active, we should not collect its 
		# lun list. Because any lun connected through a unactive target
		# is not created on target host

		# force system to update LUN information
		typeset CMD="$DEVFSADM -Ci iscsi"
		cti_report "Executing: $CMD on ${host}"
		run_rsh_cmd "${host}" "$CMD"

		typeset cmd="${ISCSIADM} list target -S ${target}| \
			grep \"OS Device Name:\" |sort -u"
		cti_report "Executing: ${cmd} on ${host}"
		run_rsh_cmd "${host}" "${cmd}"

		get_cmd_stdout | while read line
		do
			typeset t_name="$(echo ${line} | cut -d':' -f2)"
			# Following two command covert t_name form
			#    /dev/rdsk/c0t600144F00003BA48C1D348BF7BFD0009d0s2
			# to
			# 600144F00003BA48C1D348BF7BFD0009
			t_name="${t_name#*t}"
			t_name="${t_name%d*}"
			list="${list} $(echo ${t_name})"	
		done
	fi

	set_tmp_global_variable \
		"E_I_${i_node}_T_${t_node}_L" "${list}"
}

#
# NAME
#	iscsiadm_compare_target
#
# DESCRIPTION
#	Compare expeceted target with existing on initiator host. Report fail
#	if these two target list are mismatch.
#	
#		Compare D_I_${i_node}_T with E_I_${i_node}_T
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function iscsiadm_compare_target
{
	typeset host="${1}"
	typeset -u expected_list existing_list 
	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	
	eval expected_list="\"\${D_I_${i_node}_T:=}\""
	eval existing_list="\"\${E_I_${i_node}_T:=}\""

	expected_list="$(echo ${expected_list}|tr ' ' '\n'|sort|tr '\n' ' ')"
	existing_list="$(echo ${existing_list}|tr ' ' '\n'|sort|tr '\n' ' ')"
        cti_report "Expected Target:  ${expected_list}"
        cti_report "Existing Target:  ${existing_list}"

	if [[ "${expected_list}" != "${existing_list}" ]] ; then
		cti_fail "FAIL - Target mismatch " \
			"Stored:[${expected_list}] vs Output:[${existing_list}]"
		return 1
	fi

	# Compare TPGT attribute here 
	typeset list item
	eval list="\"\${E_I_${i_node}_T:=}\""
	for item in ${list}
	do
		typeset t_node d_tpgt e_tpgt
		t_node="$(format_shellvar ${item})"
		eval d_tpgt="\"\${D_I_${i_node}_T_${t_node}_DIS_TPGT}\""
		eval e_tpgt="\"\${E_I_${i_node}_T_${t_node}_DIS_TPGT}"
		
		if [[ "${d_tpgt}" != "${e_tpgt}" ]] ; then
			cti_fail "FAIL - TPGT of Target ${item} is not match" \
			"Stored: [${d_tpgt}] vs Output: [${e_tpgt}]"
			return 1
		fi
	done

	return 0
}

#
# NAME
#	iscsiadm_compare_target_lun
#
# DESCRIPTION
#	Compare expeceted target and lun with what's existting on initiator host.
# 	Report fail if they  are mismatch.
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	void
#
function iscsiadm_compare_target_lun
{
	typeset host="${1}"
	typeset existing_list

	typeset i_node="$(iscsiadm_i_node_name_formatted ${host})"
	
	iscsiadm_compare_target "${host}"
	[[ ${?} -ne 0 ]] && return 1 

	eval existing_list="\"\${E_I_${i_node}_T:=}\""
	
	typeset target
	for target in ${existing_list}
	do
		iscsiadm_compare_lun "${host}"	"${target}"
		[[ ${?} -ne 0 ]] && return 1
	done
	
	return 0
}

#
# NAME
#	iscsiadm_compare_lun
#
# DESCRIPTION
#	Compare expeceted lun connected through a specific target  with existing
#	lun on initiator host. Report fail if these two lun list are mismatch.
#	
#		Compare D_I_${i_node}_T_${t_node}_L with 
#		        E_I_${i_node}_T_${t_node}_L 
#
# INPUT
#	${1} - Host name of initiator 
#	${2} - Target node name
#
# RETURN
#	void
#
function iscsiadm_compare_lun
{
	typeset host="${1}"
	typeset target="${2}"
	typeset i_node t_node 
	typeset -u expected_list existing_list list

	i_node="$(iscsiadm_i_node_name_formatted ${host})"
	t_node="$(format_shellvar ${target})"
	
	eval expected_list="\"\${D_I_${i_node}_T_${t_node}_L:=}\""
	eval existing_list="\"\${E_I_${i_node}_T_${t_node}_L:=}\""
        cti_report "Expected Lun of Target [${target}]: ${expected_list}"
        cti_report "Existing Lun of Target [${target}]: ${existing_list}"
	
	typeset item
	for item in ${existing_list}
	do
		typeset replace="echo ${expected_list} | sed 's/\<${item}\>//g'"
		list="$( eval ${replace} )"
		
		if [[ ${expected_list} == "" || \
			"${list}" == "${expected_list}" ]] ; then
			#This item is not match, report fail
			cti_report "FAIL - Expect: Initiator can not see Lun" \
				"${item} through target ${target} " \
			cti_report "       Actual: Initiator see Lun " \
				"${item} through target ${target} " \
				"by iscsiadm list target -S ${target}"
			cti_fail
			return 1
		else 
			expected_list="${list}"
		fi
	done
	
	# Remove leading and ending white space
	expected_list="$(echo ${expected_list})"

	if [[ ${expected_list} != "" ]] ; then
		cti_report "FAIL - Expect: Initiator can see Lun" \
			"${expected_list} through target ${target} " \
		cti_report "       Actual: Initiator do not see Lun " \
			"${expected_list} through target ${target} " \
			"by iscsiadm list target -S ${target}"
		cti_fail
		return 1
	fi
	return 0
}


#
# NAME
#	iscsiadm_verify_target
# DESCRIPTION
#	Compare the actual target node list to what the test suite 
#	thinks the target node list should be.
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	Sets the result code
#	void
#
function iscsiadm_verify_target
{
	typeset host="${1}"

	cti_report "Executing: iscsiadm_verify_target start"
	
	unset_all_tmp_global_variable

	# Calculate expected targets and its properities 
	expected_target_list "${host}"

	# iscsiadm list targets and its properities 
	existing_target_list "${host}"

	# compare targets and their properities as required base on the
	# the global variables set by "expected_target_list" and 
	# "existing_target_list" functions
	iscsiadm_compare_target "${host}"

	[[ ${?} != 0 ]] && log_debug_info "${host}"
	
	cti_report "Executing: iscsiadm_verify_target stop"
}

#
# NAME
#	iscsiadm_verify_lun
# DESCRIPTION
#	Compare the actual lun list to what the test suite 
#	thinks the lun list should be.
#
# INPUT
#	${1} - Host name of initiator 
#
# RETURN
#	Sets the result code
#	void
#
function iscsiadm_verify_lun
{
	typeset host="${1}"

	cti_report "Executing: iscsiadm_verify_lun start"
	
	unset_all_tmp_global_variable

	stmfadm_visible_info
	# Calculate expected lun/targets and its properities 
	expected_target_lun_list "${host}"

	# iscsiadm list targets and its properities 
	#
	existing_target_lun_list "${host}"

	# compare targets and their properities as required base on the
	# the global variables set by "expected_target_lun_list" and 
	# "existing_target_lun_list" functions
	iscsiadm_compare_target_lun "${host}"

	[[ ${?} != 0 ]] && log_debug_info "${host}"

	cti_report "Executing: iscsiadm_verify_lun stop"
}

