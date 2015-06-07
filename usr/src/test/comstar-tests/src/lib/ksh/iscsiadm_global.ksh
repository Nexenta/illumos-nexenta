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

typeset TMP_GLOBAL_VARIABLE_NAME=""
typeset GLOBAL_VARIABLE_NAME=""

#
# NAME
#	set_tmp_global_variable
#
# DESCRIPTION
#	Set a temporary global variable.
#
# INPUT
#	${1} - Variable name
#	${2} - Variable value 
#
# RETURN
function set_tmp_global_variable
{
	typeset name="${1}"
	typeset value="${2}"

	eval ${name}="\$( echo ${value} )"

	trace_tmp_global_variable "${name}"
}
#
# NAME
#	trace_tmp_global_variable
#
# DESCRIPTION
#	Store the name of temporary global variable.
#
# INPUT
#	${1} - Variable name
#
# RETURN
#
function trace_tmp_global_variable
{
	typeset name="${1}"
	TMP_GLOBAL_VARIABLE_NAME="${TMP_GLOBAL_VARIABLE_NAME} ${name}"
}

#
# NAME
#	unset_all_tmp_global_variable
# DESCRIPTION
#	Unset all temporary global variables defined in verify process.
#
# INPUT
#
# RETURN
#
function unset_all_tmp_global_variable
{
	typeset name
	for name in ${TMP_GLOBAL_VARIABLE_NAME}
	do
		eval unset "${name}"
	done
	TMP_GLOBAL_VARIABLE_NAME=""	
}

#
# NAME
#	log_tmp_global_variable
# DESCRIPTION
#	Log all temporary global variable and their value into report
#	using cti_report
#
# INPUT
#
# RETURN
#
function log_tmp_global_variable
{
	typeset pair name

	for name in ${TMP_GLOBAL_VARIABLE_NAME}
	do
		eval pair="\"${name}=\${${name}}\""
		cti_report "${pair}"
	done
}

#
# NAME
#	set_global_variable
#
# DESCRIPTION
#	Set a global variable.
#
# INPUT
#	${1} - Variable name
#	${2} - Variable value 
#
# RETURN
function set_global_variable
{
	typeset name="${1}"
	typeset value="${2}"

	#echo ==${name}="\"${value}\""==
	eval ${name}="\"${value}\""
	trace_global_variable "${name}"
}

#
# NAME
#	unset_global_variable
#
# DESCRIPTION
#	Unet a global variable.
#
# INPUT
#	${1} - Variable name
#
# RETURN
function unset_global_variable
{
	typeset name="${1}"
	eval unset "${name}"
	
	untrace_global_variable "${name}"
}
#
# NAME
#	trace_global_variable
#
# DESCRIPTION
#	Store the name of global variable.
#
# INPUT
#	${1} - Variable name
#
# RETURN
#
function trace_global_variable
{
	typeset name="${1}"
	
	[[ "$( echo ${GLOBAL_VARIABLE_NAME} | \
	    egrep ${name} )" != "" ]] &&
		return

	GLOBAL_VARIABLE_NAME="${GLOBAL_VARIABLE_NAME} ${name}"
}

#
# NAME
#	untrace_global_variable
#
# DESCRIPTION
#	Remove the name of global variable.
#
# INPUT
#	${1} - Variable name
#
# RETURN
#
function untrace_global_variable
{
	typeset name old_value new_value replace

	name="${1}"

	old_value="${GLOBAL_VARIABLE_NAME}"
	typeset replace="echo ${old_value} | sed 's/${name}//g'"
	new_value="$( eval ${replace} )"

	GLOBAL_VARIABLE_NAME="${new_value}"
}

#
# NAME
#	unset_all_global_variable
# DESCRIPTION
#	Unset all global variables defined in verify process.
#
# INPUT
#
# RETURN
#
function unset_all_global_variable
{
	typeset name
	for name in ${GLOBAL_VARIABLE_NAME}
	do
		eval unset "${name}"
	done

	GLOBAL_VARIABLE_NAME=""
}

#
# NAME
#	log_global_variable
# DESCRIPTION
#	Log all global variable and their value into report
#	using cti_report
#
# INPUT
#
# RETURN
#
function log_global_variable
{
	typeset pair name

	for name in ${GLOBAL_VARIABLE_NAME}
	do
		eval pair="\"${name}=\${${name}}\""
		cti_report "${pair}"
	done
}

#
# NAME
#	log_command_info 
# DESCRIPTION
#	Log command output into log fine using cti_reportfile
#
# INPUT
#
# RETURN
#
function log_command_output
{
	typeset host="${1}"
	typeset cmd="${2}"
	run_rsh_cmd "${host}" "${cmd}"
	cti_reportfile "${CMD_STDOUT}" "On ${host}-${cmd}"
}
#
# NAME
#	log_initiator_info 
# DESCRIPTION
#	Log serval command output into log fine using cti_report
#
# INPUT
#
# RETURN
#
function log_initiator_info
{
	typeset host="${1}"

	log_command_output "${host}" "${ISCSIADM} list initiator-node"	
	log_command_output "${host}" "${ISCSIADM} list discovery"	
	log_command_output "${host}" "${ISCSIADM} list discovery-address"
	log_command_output "${host}" "${ISCSIADM} list target -S"
	log_command_output "${host}" "${ISCSIADM} list target-param -v"

}

#
# NAME
#	log_target_info 
# DESCRIPTION
#	Log serval command output into log fine using cti_report
#
# INPUT
#
# RETURN
#
function log_target_info
{
	typeset host="${ISCSI_THOST}"

	log_command_output "${host}" "${SBDADM} list-lu"	
	log_command_output "${host}" "${ITADM} list-target -v"
	log_command_output "${host}" "${ITADM} list-tpg -v"
	log_command_output "${host}" "${ITADM} list-defaults"
	log_command_output "${host}" "${ITADM} list-initiator -v"
}

#
# NAME
#	log_debug_info 
# DESCRIPTION
#	Write debug information into log fine
#
# INPUT
#
# RETURN
#
function log_debug_info
{
	typeset host="${1}"

	log_initiator_info "${host}"
	log_target_info 
	log_global_variable
	log_tmp_global_variable
}

