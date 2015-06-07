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

# Global variable used only in this file
typeset _CMD_VAR=""
typeset _CMD_ARR_NAME=""
typeset _INDEX_ARR=""
typeset _TMP_INDEX_ARR=""
typeset _NEW_INDEX_ARR=""

#
# NAME
#       extend
#
# DESCRIPTION
#      	Iterate "${_INDEX_ARR}", parse and extend items in 
#	the command array.
#	
# ARGUMENT
#	Use global variable _INDEX_ARR
#	
# RETURN
#       No return 
#
function extend
{
	typeset -i i
	_NEW_INDEX_ARR=""

	for i in ${_INDEX_ARR}
	do
		#
		# split a command string into three part
		# Example 
		# Split
		#	itadm create ^SET_1 ^SET_2 ^SET_3
		# Into
		#	begin="itadm create"
		#	term="SET_1"
		#	end="^SET_2 ^SET_3"
		#
		typeset part_arr
		typeset begin=""
		typeset term=""
		typeset end=""
		
		#eval "echo \"\${$_CMD_ARR_NAME[\${i}]}\""

		eval begin="\${$_CMD_ARR_NAME[\${i}]%%^*}"
		#echo ${pre}

		eval set -A part_arr \${$_CMD_ARR_NAME[\${i}]#*^}		
		term="${part_arr[0]}"

		typeset -i j=1
		while [[ ${j} -lt ${#part_arr[@]} ]]
		do
			end="${end} ${part_arr[${j}]}"
			(( j+=1 ))
		done
		
		# Call extend_term function
		extend_cmd ${i} "${term}" "${begin}" "${end}"	
		_NEW_INDEX_ARR="${_NEW_INDEX_ARR} ${_TMP_INDEX_ARR}"
	done

	_NEW_INDEX_ARR=`echo ${_NEW_INDEX_ARR}` 
}

# NAME
#	extend_cmd
#
# DESCRIPTION
#	Replace ^SET_* with the string it stand for 
#
# INPUT 
#	$1 - index
#	$2 - term
#	$3 - begin
#	$4 - end
#	
# RETURN
#	void
#
function extend_cmd
{
	typeset index=${1}
	eval "typeset cmd=\"\${${2}}\""	
	typeset begin="${3}"
	typeset end="${4}"
	
	_TMP_INDEX_ARR=""

	typeset -i i=1
	typeset -i len=`echo ${cmd} | awk -F"|" '{print NF }'`
	
	while [[ ${i} -le ${len} ]] 
	do
		field=`echo ${cmd} | cut -d"|" -f${i} | xargs echo`

		#ignore the empty string
		if [[ -z `echo ${field}` ]] ; then
			(( i+=1 ))
			continue
		fi
		if [[ "$( echo ${field} | grep NULL )" != "" ]] ; then
			field=""
		fi

		typeset new_cmd="${begin} ${field} ${end}"
		typeset next

		if [[ ${i} == 1 ]] ; then
			next=${index}
		else
			eval next=\${#$_CMD_ARR_NAME[@]}
		fi
		eval "$_CMD_ARR_NAME[\${next}]=\"${new_cmd}\""

		#echo "${new_cmd}"
		echo "${new_cmd}" | grep "\^" > /dev/null 2>&1
		if [[ ${?} == 0 ]] ; then
			# command line which need to be process further
			_TMP_INDEX_ARR="${_TMP_INDEX_ARR} ${next}"
		fi
		(( i+=1 ))
	done
}

# NAME
#	cmd_genreate
#
# DESCRIPTION
#	Parse the first command line and set up
#	"${_INDEX_ARR}", and start to parse the rest	
#	
# INPUT	
#	$1 - Variable name of the command
#	$2 - Variable name of the command array. Contain
#	     the results
# RETURN
#	void
#
function cmd_generate
{
	_CMD_VAR="${1}"	
	_CMD_ARR_NAME="${2}"

	extend_cmd 0 "${1}" "" ""
	_INDEX_ARR="${_TMP_INDEX_ARR}"

	while [[ -n ${_INDEX_ARR} ]] 
	do
		extend
		_INDEX_ARR=`echo "${_NEW_INDEX_ARR}"`
	done
}

# NAME
#	auto_generate_tp
#
# DESCRIPTION
#	Base on the "CMD" defination, generate value of
#	TET global variable "iclist" for a TC file
# INPUT
#	$1 - Variable name of the command
#	$2 - Variable name of the command array. Contain
#	     the results
#	$3 - Function name to call for each TP
#
# RETURN
#	void
#
function auto_generate_tp
{
	typeset cmd="${1}"
	typeset cmd_arr_name="${2}"
	typeset common_func="${3}"

	typeset -i i=1
	typeset -i len=0

	cmd_generate "${cmd}" "${cmd_arr_name}"				

	eval len=\${#${cmd_arr_name}[@]}

	iclist=""
	while [[ ${i} -le ${len} ]] 
	do
		iclist="${iclist} ic${i}"
		eval "ic${i}=${common_func}"
		(( i+=1 ))
	done
}

