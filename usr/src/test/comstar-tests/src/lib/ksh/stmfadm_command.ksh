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
#	stmfadm_create
#
# SYNOPSIS
#	stmfadm_create [POS or NEG] <object> 
#	[options for 'stmfadm create-hg/tg' command]
#
# DESCRIPTION
#	Execute 'stmfadm create-hg/tg' command and verify if the object was 
#	created	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'stmfadm create-hg/tg'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_create
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the create command.
	typeset cmd="${STMFADM} create-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_create_info $object $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		stmfadm_verify $object
	fi
	return $retval
}

#
# NAME
#	stmfadm_delete
#
# SYNOPSIS
#	stmfadm_delete [POS or NEG] <object> 
#	[options for 'stmfadm delete-hg/tg' command]
#
# DESCRIPTION
#	Execute 'stmfadm delete-hg/tg' command and verify if the object was 
#	deleted and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'stmfadm delete-hg/tg'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_delete
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the delete command.
	typeset cmd="${STMFADM} delete-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_delete_info $object $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		stmfadm_verify $object
	fi
	return $retval
}

#
# NAME
#	stmfadm_add
#
# SYNOPSIS
#	stmfadm_add [POS or NEG] <object> 
#	[options for 'stmfadm add-hg-member, add-tg-member, add-view command']
#
# DESCRIPTION
#	Execute 'stmfadm add-hg-member, add-tg-member, add-view ' 
#	command and verify if the object was added
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'stmfadm add-hg-member, add-tg-member, add-view '
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_add
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the add command.
	typeset cmd="${STMFADM} add-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_add_info $object $options
	else
		stmfadm_add_info $object $options	
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		stmfadm_verify $object
	fi
	return $retval
}

#
# NAME
#	stmfadm_remove
#
# SYNOPSIS
#	stmfadm_remove [POS or NEG] <object> 
#	[options for 'stmfadm remove-hg-member, remove-tg-member, 
#	remove-view command']
#
# DESCRIPTION
#	Execute 'stmfadm remove-hg-member, remove-tg-member, 
#	remove-view ' command and verify if the object was removed
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'stmfadm remove-hg-member, remove-tg-member, remove-view '
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_remove
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the delete command.
	typeset cmd="${STMFADM} remove-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_remove_info $object $options
	else
		stmfadm_remove_info $object $options	
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		stmfadm_verify $object
	fi
	return $retval
}
#
# NAME
#	stmfadm_online
#
# SYNOPSIS
#	stmfadm_online [POS or NEG] <object> 
#	[options for 'stmfadm online-lu, online-target' ]
#
# DESCRIPTION
#	Execute 'stmfadm stmfadm online-lu, online-target' 
#	command and verify if the object was onlined
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'stmfadm online-lu, online-target'
#	command.  So, even if called with 'NEG', a failure 
#	by the command will result in non-zero status being returned.
#
function stmfadm_online
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the delete command.
	typeset cmd="${STMFADM} online-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	sleep 5
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_online_info $object $options
	else
		stmfadm_online_info $object $options	
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		eval stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		eval stmfadm_verify $object
	fi
	return $retval
}


#
# NAME
#	stmfadm_offline
#
# SYNOPSIS
#	stmfadm_offline [POS or NEG] <object> 
#	[options for 'stmfadm offline-lu, offline-target']
#
# DESCRIPTION
#	Execute 'stmfadm offline-lu, offline-target' command 
#	and verify if the object was offlined
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'stmfadm offline-lu, offline-target'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_offline
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the delete command.
	typeset cmd="${STMFADM} offline-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	sleep 5
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		stmfadm_offline_info $object $options
	else
		stmfadm_offline_info $object $options	
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		eval stmfadm_verify $object
	else
		NEG_result $retval "$cmd"
		eval stmfadm_verify $object
	fi
	return $retval
}

#
# NAME
#	stmfadm_list
#
# SYNOPSIS
#	stmfadm_list [POS or NEG] <object> 
#	[options for 'stmfadm list-hg, list-lu, list-state, 
#	list-target, list-tg, list-view']
#
# DESCRIPTION
#	Execute 'stmfadm list-hg, list-lu, list-state, 
#	list-target, list-tg, list-view ' command and verify 
#	if the object was listd	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'list-hg, list-lu, list-state, list-target, list-tg, list-view'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function stmfadm_list
{
	if [ "$1" = "NEG" ]
	then
		typeset pos_neg=$1
		shift
	else
		typeset pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	typeset object="$1"
	if [ "$object" ] ;then
		shift 1
	fi
	typeset options="$*"
				
	# Build the delete command.
	typeset cmd="${STMFADM} list-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -ne 0 ];then
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
	else
		NEG_result $retval "$cmd"
	fi
	return $retval
}

