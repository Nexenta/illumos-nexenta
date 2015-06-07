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
#	sbdadm_create_lu
#
# SYNOPSIS
#	sbdadm_create_lu [POS or NEG] <object> 
#	[options for 'sbdadm create-lu' command]
#
# DESCRIPTION
#	Execute 'sbdadm create-lu' command and verify if the object was created
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sbdadm create-lu'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function sbdadm_create_lu
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

	typeset options="$*"
	eval typeset object=\${$#}
				
	# Build the create command.
	typeset cmd="${SBDADM} create-lu $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		sbdadm_create_info $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	else
		NEG_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	fi
	return $retval
}

#
# NAME
#	sbdadm_delete_lu
#
# SYNOPSIS
#	sbdadm_delete_lu [POS or NEG] <object> 
#	[options for 'sbdadm delete-lu' command]
#
# DESCRIPTION
#	Execute 'sbdadm delete-lu' command and verify if the object was deleted
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sbdadm delete-lu'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function sbdadm_delete_lu
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

	typeset options="$*"
			
	# Build the delete command.
	typeset cmd="${SBDADM} delete-lu $options"
	cti_report "Executing: $cmd"
	
	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		sbdadm_delete_info $options
	else
		report_err "$cmd"
	fi
		
	if [ "$pos_neg" = "POS" ]
	then
		POS_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	else
		NEG_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	fi
	return $retval
}

#
# NAME
#	sbdadm_modify_lu
#
# SYNOPSIS
#	sbdadm_modify_lu [POS or NEG] <object> 
#	[options for 'sbdadm modify-lu' command]
#
# DESCRIPTION
#	Execute 'sbdadm modify-lu' command and verify if the object was modifyd
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sbdadm modify-lu'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function sbdadm_modify_lu
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

	typeset options="$*"
				
	# Build the modify command.
	typeset cmd="${SBDADM} modify-lu $options"
	cti_report "Executing: $cmd"
	
	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`	

	if [ $retval -eq 0 ];then
		sbdadm_modify_info $options
	else
		report_err "$cmd"
	fi		
		
	if [ "$pos_neg" = "POS" ]
	then
		POS_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	else
		NEG_result $retval "$cmd"
		sbdadm_verify_lu
		stmfadm_verify_lu
	fi
	return $retval
}

#
# NAME
#	sbdadm_import_lu
#
# SYNOPSIS
#	sbdadm_import_lu [POS or NEG] <object> 
#	[options for 'sbdadm import-lu' command]
#
# DESCRIPTION
#	Execute 'sbdadm import-lu' command and verify if the object was importd
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sbdadm import-lu'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function sbdadm_import_lu
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

	typeset options="$*"
				
	# Build the import command.
	typeset cmd="${SBDADM} import-lu $options"
	cti_report "Executing: $cmd"
	
	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		sbdadm_import_info $options
	else
		report_err "$cmd"
	fi		

	if [ "$pos_neg" = "POS" ]
	then
		POS_result $retval "$cmd"
		sbdadm_verify_im
		stmfadm_verify_lu
	else
		NEG_result $retval "$cmd"
		sbdadm_verify_im
		stmfadm_verify_lu
	fi
	return $retval
}

#
# NAME
#	sbdadm_list_lu
#
# SYNOPSIS
#	sbdadm_list_lu [POS or NEG] <object> 
#	[options for 'sbdadm list-lu' command]
#
# DESCRIPTION
#	Execute 'sbdadm list-lu' command and verify if the object was listd
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sbdadm list-lu'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function sbdadm_list_lu 
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
				
	# Build the list command.
	typeset cmd="${SBDADM} list-lu"
	cti_report "Executing: $cmd"
	
	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -ne 0 ];then
		report_err "$cmd"
	fi		
	
	if [ "$pos_neg" = "POS" ]
	then
		POS_result $retval "$cmd"
	else
		NEG_result $retval "$cmd"
	fi
	return $retval
}



