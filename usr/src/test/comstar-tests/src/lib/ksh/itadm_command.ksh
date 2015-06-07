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
#	itadm_create
#
# SYNOPSIS
#	itadm_create [POS or NEG] <object> 
#	[options for 'itadm create-target/tpg' command]
#
# DESCRIPTION
#	Execute 'itadm create-target/tpg' command and verify if the object was 
#	created and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'itadm create-target/tpg'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function itadm_create
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
	typeset s_found=1
	typeset S_found=1
	typeset usage=":"
	usage="${usage}s:(chap-secret)"
	usage="${usage}S:(chap-secret-file)"

	while getopts "$usage" option
	do
		case $option in
		s)
			typeset secret_string=$OPTARG
			s_found=0			
			;;
		S)
			typeset secret_string=$OPTARG
			S_found=0			
			;;
		?)
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done
	if [ $s_found -eq 0 ];then
		typeset n_options=$(echo $options | sed -e "s/\<$secret_string\>//g")
		typeset cmd="${ITADM} create-$object $n_options"
		cti_report "Executing: $cmd with secret [$secret_string]"
		run_ksh_cmd "$SETCHAPSECRET_ksh $cmd $secret_string"
		get_cmd_stdout | grep 'ret=0' >/dev/null 2>&1
                echo $? > $CMD_RETVAL
	elif [ $S_found -eq 0 ];then
		echo "$secret_string" > /tmp/chapsecret
		typeset n_options=$(echo $options | sed -e "s/\<$secret_string\>/\/tmp\/chapsecret/g")
		typeset cmd="${ITADM} create-$object $n_options"
		cti_report "Executing: $cmd with secret [$secret_string]"
		run_ksh_cmd "$cmd"
	else
		typeset cmd="${ITADM} create-$object $options"
		cti_report "Executing: $cmd"
		run_ksh_cmd "$cmd"
	fi
	
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		itadm_create_info $object $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		itadm_verify $object
	else
		NEG_result $retval "$cmd"
		itadm_verify $object
	fi
	return $retval
}

#
# NAME
#	itadm_delete
#
# SYNOPSIS
#	itadm_delete [POS or NEG] <object> 
#	[options for 'itadm delete-target/tpg' command]
#
# DESCRIPTION
#	Execute 'itadm delete-target/tpg' command and verify if the object was 
#	deleted and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'itadm delete-target/tpg'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function itadm_delete
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
	typeset cmd="${ITADM} delete-$object $options"
	cti_report "Executing: $cmd"

	run_ksh_cmd "$cmd"
	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		itadm_delete_info $object $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		itadm_verify $object
	else
		NEG_result $retval "$cmd"
		itadm_verify $object
	fi
	return $retval
}

#
# NAME
#	itadm_modify
#
# SYNOPSIS
#	itadm_modify [POS or NEG] <object> 
#	[options for 'itadm modify-target, modify-initiator, modify-defaults']
#
# DESCRIPTION
#	Execute 'itadm modify-target, modify-initiator, modify-defaults' 
#	command and verify if the object was added
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'itadm modify-target, modify-initiator, modify-defaults'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function itadm_modify
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
				
	# Build the modify command.
	typeset s_found=1
	typeset S_found=1
	typeset d_found=1

	typeset usage=":"
	usage="${usage}s:(chap-secret)"
	usage="${usage}S:(chap-secret-file)"
	usage="${usage}d:(radius-server)"
	usage="${usage}D:(radius-secret-file)"

	while getopts "$usage" option
	do
		case $option in
		s)
			typeset secret_string=$OPTARG
			s_found=0
			;;
		d)
			typeset secret_string=$OPTARG
			d_found=0
			;;
		S|D)
			typeset secret_string=$OPTARG
			S_found=0
			;;
		?)
			(( OPTIND = ${OPTIND} + 1 ))
			;;
		esac
	done
	if [ $s_found -eq 0 ];then
		typeset n_options=$(echo $options | sed -e "s/\<$secret_string\>//g")
		typeset cmd="${ITADM} modify-$object $n_options"
		cti_report "Executing: $cmd with secret [$secret_string]"
		run_ksh_cmd "$SETCHAPSECRET_ksh $cmd $secret_string"
		get_cmd_stdout | grep 'ret=0' >/dev/null 2>&1
                echo $? > $CMD_RETVAL
	elif [ $d_found -eq 0 ];then
		typeset n_options=$(echo $options | sed -e "s/\<$secret_string\>//g")
		typeset cmd="${ITADM} modify-$object $n_options"
		cti_report "Executing: $cmd with secret [$secret_string]"
		run_ksh_cmd "$SETRADIUSSECRET_ksh $cmd $secret_string"
		get_cmd_stdout | grep 'ret=0' >/dev/null 2>&1
                echo $? > $CMD_RETVAL
	elif [ $S_found -eq 0 ];then
		echo "$secret_string" > /tmp/chapsecret
		typeset n_options=$(echo $options | sed -e "s/\<$secret_string\>/\/tmp\/chapsecret/g")
		typeset cmd="${ITADM} modify-$object $n_options"
		cti_report "Executing: $cmd with secret [$secret_string]"
		run_ksh_cmd "$cmd"
	else
		typeset cmd="${ITADM} modify-$object $options"
		cti_report "Executing: $cmd"
		run_ksh_cmd "$cmd"
	fi

	typeset -i retval=`get_cmd_retval`
	
	if [ $retval -eq 0 ];then
		itadm_modify_info $object $options
	else
		report_err "$cmd"
	fi
	if [ "$pos_neg" = "POS" ];then
		POS_result $retval "$cmd"
		itadm_verify $object
	else
		NEG_result $retval "$cmd"
		itadm_verify $object
	fi
	return $retval
}
#
# NAME
#	itadm_list
#
# SYNOPSIS
#	itadm_list [POS or NEG] <object> 
#	[options for 'itadm list-target, list-tpg, list-defaults, list-initiator']
#
# DESCRIPTION
#	Execute 'itadm list-target, list-tpg, list-defaults, list-initiator' command and verify 
#	if the object was listd and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 
#	'itadm list-target, list-tpg, list-defaults, list-initiator'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function itadm_list
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
				
	# Build the list command.
	typeset cmd="${ITADM} list-$object $options"
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

