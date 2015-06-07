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
# ident	"@(#)share_common.ksh	1.6	09/08/25 SMI"
#

#
# This file contains common functions and is meant to be sourced into
# the test case files.
#

CHECKENV=${TET_ROOT}/../checkenv/bin/checkenv
[[ -z $TESTDIR ]] && TESTDIR="/SHARE_tests"
set -A MP ${TESTDIR}/td1 ${TESTDIR}/td2 ${TESTDIR}/td3 ${TESTDIR}/td4 ${TESTDIR}/td5

#
# If you need more groups make sure to add them to the TG array!
# and note unless added here or before startup is called the
# new groups will no be tested for in use.
#
set -A TG test_group_1 test_group_2 test_group_3 test_group_4

#
# Output files used to verify information
#
CMD_SUMMARY_FILE=$SHR_TMPDIR/sharemgr_cmd_summary.$$
DFSTAB=/etc/dfs/dfstab
SHARETAB=/etc/dfs/sharetab
LOGDIR=$SHR_TMPDIR/sharemgr_logs
dfs_log=${LOGDIR}/dfsshare
l_log=${LOGDIR}/sharemgr_list
s_log=${LOGDIR}/sharemgr_show
sharectl_orig=${LOGDIR}/sharectl_orig.log

whence -p stc_genutils > /dev/null 2>&1
if (( $? != 0 )); then
	print -u2 "share_common: stc_genutils command not found!"
	exit 1
fi
STC_GENUTILS=$(stc_genutils path)
. $STC_GENUTILS/include/nfs-util.kshlib

. ${TET_SUITE_ROOT}/sharefs-tests/include/commands
. ${TET_SUITE_ROOT}/sharefs-tests/lib/utils_common
. ${TET_SUITE_ROOT}/sharefs-tests/lib/verify_common


#
# NAME
#	print_test_case
#
# DESCRIPTION
#	Print the test case name to the results formated to fit with
#	60 characters.
#
function print_test_case {
	unset ptc_short_info
	ptc_info="Test case $*"

	tet_infoline "======================================================="

	if [ `echo $ptc_info | $WC -c` -gt 60 ]
	then
		#
		# Split the line
		#
		ptc_ltrcnt=0
		for ptc_word in $ptc_info
		do
			ptc_wordsz=`echo $ptc_word | $WC -c`
			ptc_ltrcnt=`$EXPR $ptc_ltrcnt + $ptc_wordsz + 1`
			if [ $ptc_ltrcnt -gt 60 ]
			then
				tet_infoline "$ptc_short_info"
				ptc_short_info=" $ptc_word"
				ptc_ltrcnt=`$EXPR $ptc_wordsz`
			else
				ptc_short_info="$ptc_short_info $ptc_word"
			fi
		done
		if [ $ptc_ltrcnt -gt 0 ]
		then
			tet_infoline "$ptc_short_info"
		fi
	else
		tet_infoline "$ptc_info"
	fi

	tet_infoline "======================================================="
}

#
# NAME
#	remove_group_from_list
#
# SYNOPSIS
#	remove_group_from_list <group>
#
# DESCRIPTION
#	Remove the specified group from the global GROUPS variable.
#
function remove_group_from_list {
	rgfl_rm_group="$1"
	unset rgfl_group_list

	for rgfl_group in $GROUPS
	do
		if [ "$rgfl_rm_group" != "$rgfl_group" ]
		then
			rgfl_group_list="$rgfl_group_list $rgfl_group"
		fi
	done
	GROUPS="$rgfl_group_list"
}

#
# NAME
#	remove_protocol_from_list
#
# SYNOPSIS
#	remove_protocol_from_list protocol group
#
# Description
#	Remove the specified protocol from the global PROTOCOL list for the 
#	specified group.
#
function remove_protocol_from_list {
	rpfl_rm_protocol=$1
	rpfl_group=$2
	unset rpfl_protocol_list

	eval rpfl_list=\"\$PROTOCOLS_${rpfl_group}\"
	for rpfl_protocol in $rpfl_list
	do
		if [ "$rpfl_rm_protocol" != "$rpfl_protocol" ]
		then
			rpfl_protocol_list="$rpfl_protocol_list $rpfl_protocol"
		fi
	done

	eval PROTOCOLS_${rpfl_group}=\"$rpfl_protocol_list\"
}

#
# NAME
#	which_group
#
# DESCRIPTION
#	For a given share, determine which group it currently belongs to.
#
function which_group {
	wg_target_share="$1"
	unset wg_match_group

	#
	# For every group created by this test case, determine if the
	# specified share belongs to that group.
	#
	for wg_group in $GROUPS
	do
		eval wg_shares=\"\$SHARES_${wg_group}\"

		#
		# Step through every share in the current group, looking for
		# a match.
		#
		for wg_share in $wg_shares
		do
			if [ "$wg_share" = "$wg_target_share" ]
			then
				wg_match_group="$wg_group"
				break
			fi
		done

		if [ "$wg_match_group" ]
		then
			break
		fi
	done

	echo $wg_match_group
}

#
# NAME
#	list
#
# DESCRIPTION
#	Execute 'sharemgr list' command and verify output.
#	l_options = options to proved to the list command
#
function list {
	unset l_options
	cmdlvl=0

	while getopts P:v options
	do
		case $options in
		P)      l_options="$l_options -P $OPTARG";;
		v)      l_options="$l_options -v";;
		esac
	done
	shift $((OPTIND - 1))
	if [ "$1" = "NEG" ]
	then
		l_pos_neg=$1
		shift
	else
		l_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	logfile=`get_logfile list ${l_options}`
	if [ -f $logfile ]
	then
		return
	fi
	l_cmd="${cmd_prefix}${SHAREMGR} list $l_options"
	tet_infoline "  - $l_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		eval ${l_cmd}${cmd_postfix} > $logfile 2>&1
		l_retval=$?
	fi
	append_cmd $l_cmd${cmd_postfix}

	if [ $l_pos_neg = "POS" ]
	then
		POS_result $l_retval "$l_cmd"
	else
		NEG_result $l_retval "$l_cmd"
	fi
}


#
# NAME
#	show
#
# DESCRIPTION
#	Execute 'sharemgr show' command
#
function show {
	unset s_options
	cmdlvl=0

	while getopts P:vp options
	do
		case $options in
		P)      s_options="$s_options -P $OPTARG";;
		p)	s_options="$s_options -p";;
		v)      s_options="$s_options -v";;
		esac
	done
	shift $((OPTIND - 1))

	if [ "$1" = "NEG" ]
	then
		s_pos_neg=$1
		shift
	else
		s_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	s_group="$*"

	#
	# This will have to be updated if multiple groups are
	# given to show.
	#
	logfile=`get_logfile show ${s_options} ${s_group}`
	if [ -f $logfile ]
	then
		return
	fi
	s_cmd="${cmd_prefix}${SHAREMGR} show $s_options $s_group"
	tet_infoline " - ${s_cmd}${cmd_postfix}"
	if [ "$report_only" != "TRUE" ]
	then
		eval $s_cmd${cmd_postfix} > $logfile 2>&1
		s_result=$?
	fi
	append_cmd ${s_cmd}${cmd_postfix}

	# o Verify return code is 0"
	if [ $s_pos_neg = "POS" ]
	then
		POS_result $s_result "$s_cmd"
	else
		NEG_result $s_result "$s_cmd"
	fi
}

#
# NAME
#	clear_remembered_info
#
# SYNOPSIS
#	clear_remembered_info <share_group_name> [protocol] [properties]
#
# DESCRIPTION
#	Clear (unset) variables used to remember protocol and property
#	settings for the specified share group.
#
function clear_remembered_info {
	cri_group="$1"
	shift

	for cri_item in $*
	do
		if [ "$cri_item" = "protocol" ]
		then
			eval unset PROTOCOLS_${cri_group}
		elif [ "$cri_item" = "properties" ]
		then
			# Get list of property variables currently defined
			# for this group and unset each of them.
			for cri_property in `set | \
			    $GREP "^PROPERTY_${cri_group}" | $SED 's/=.*//'`
			do
				unset $cri_property
			done
		fi
	done
}

#
# NAME
#	remember_protocol_settings
#
# SYNOPSIS
#	remember_protocol_settings <group> <create or set> <protocol args>
#
# DESCRIPTION
#	When a 'sharemgr create' or 'sharemgr set' command is executed, this
#	function is called to determine if the protocol setting is being
#	modified by the command.  If so, update the global variable used to
#	track what the current protocol value should be for this group.
#
function remember_protocol_settings {
	rps_group="$1"
	rps_op="$2"
	shift 2
	rps_args="$*"
	unset rps_protocol

	#
	# Walk through the arguments for the 'sharemgr create' or
	# 'sharemgr set' command.  If it contains a '-P' option to set
	# the protocol for the group, set the global protocol variable for
	# that group to match.
	#
	unset rps_specific_protocols
	while [ $# -gt 0 ]
	do
		case $1 in
		"-P") 	rps_specific_protocols="yes"
			shift
			rps_protocol="$1"
			if [ "$rps_op" = "create" ]
			then
				if [ "$1" = '""' ]
				then
					# No protocols for group
					eval unset PROTOCOLS_${rps_group}
					$SHARES_${wg_group}
				else
					# Add protocol to group
					eval PROTOCOLS_${rps_group}=\"\$PROTOCOLS_${rps_group} $rps_protocol\"
				fi
			fi;;
		"-S")
			#
			# Treat this like an additional protocol for
			# later checking.
			#
			rps_specific_protocols="yes"
			shift
			rps_protocol_name="${rps_protocol}:$1"
			rps_protocol="${rps_protocol}$1"
			# Add Security mode to group
			if [ "$rps_op" = "unset" ]
			then
				echo "$*" | $GREP "\-p" > /dev/null 2>&1
				if [ $? -ne 0 ]
				then
					remove_protocol_from_list \
					    $rps_protocol_name $rps_group
				fi
			else
				rps_tmp=\"\$PROTOCOLS_${rps_group}\"
				echo "$rps_tmp" | \
				    $GREP "$rps_protocol_name" > /dev/null
				if [ $? -ne 0 ]
				then
					eval PROTOCOLS_${rps_group}=\"\$PROTOCOLS_${rps_group} $rps_protocol_name\"
				fi
			fi
			;;
		"-p")
			#
			# Setting or clearing properties for protocol
			#
			shift
			rps_property="`echo $1 | $SED 's/=.*//'`"
			# rps_value="`echo $1 | $SED s/^.*=//'`"
			rps_value="`echo $1 | $SED s/^.*=//`"
			if [ "$rps_op" = "unset" ]
			then
				eval unset PROPERTY_${rps_group}_${rps_protocol}_${rps_property}
			else
                                #
				# create or set operations will always set a
				# value (even if null).
                                #
				eval PROPERTY_${rps_group}_${rps_protocol}_${rps_property}=\"$rps_value\"
			fi;;
		esac
		shift
	done

	#
	# If this is a 'create' command and no protocols were specified, the
	# default is for the group to have all default protocols.
	#
	if [ ! "$rps_specific_protocols" -a "$rps_op" = "create" ]
	then
		eval PROTOCOLS_${rps_group}=\"$def_protocols\"
	fi
}

#
# NAME
#	compare_protocol_properties
#
# SYNOPSIS
#	compare_protocol_properties group protocol <protocol name=value pairs>
#
# DESCRIPTION
#	This function is provided with a group name, a protocol for that
#	group, and a list of property name/value pairs obtained from the
#	'sharemgr show -p' command for the group/protocol.  Compare all
#	of the properties against those we think should be in place.
#
function compare_protocol_properties {
	cpp_group="$1"
	cpp_protocol="$2"
	shift 2
	cpp_pairs="$*"
	cpp_retval=0

	#
	# First walk through all of the properties that the 'show -p' command
	# indicates are set.
	#
	unset cpp_checked_props
	for cpp_pair in $cpp_pairs
	do
		# Extract the property name
		cpp_prop_name="`echo $cpp_pair | $SED 's/=.*//'`"
		# Extract the property value and eliminate double quotes
		cpp_prop_value="`echo $cpp_pair | $SED 's/.*=//' | \
		    $SED 's/\"//g'`"

		if set | $GREP \
		    "^PROPERTY_${cpp_group}_${cpp_protocol}_${cpp_prop_name}" \
		    >/dev/null 2>&1
		then
			eval cpp_remembered_value=\"\$PROPERTY_${cpp_group}_${cpp_protocol}_${cpp_prop_name}\"
			if [ "$cpp_prop_value" != "$cpp_remembered_value" ]
			then
				tet_infoline "ERR $cpp_protocol property" \
				    "$cpp_prop_name is \"$cpp_prop_value\"," \
				    "expected \"$cpp_remembered_value\""
				cpp_retval=1
			fi
		else
			tet_infoline "ERR $cpp_protocol property" \
			    "$cpp_prop_name should not be set but is shown" \
			    "in 'show -p' output"
			cpp_retval=1
		fi
		cpp_checked_props="$cpp_checked_props $cpp_prop_name"

	done

	#
	# Now make sure that all of the properties that we remember having
	# been set for this protocol were reported by 'show -p'.
	#
	for cpp_remembered_prop in `set | grep "^PROPERTY_${cpp_group}_${cpp_protocol}_" | $SED 's/=.*//'`
	do
		cpp_name=`echo $cpp_remembered_prop | $SED 's/.*_//'`
		unset cpp_prop_name_match
		for cpp_checked_prop in $cpp_checked_props
		do
			if [ "$cpp_name" = "$cpp_checked_prop" ]
			then
				cpp_prop_name_match="yes"
				break
			fi
		done
		if [ ! "$cpp_prop_name_match" ]
		then
			eval cpp_value=\"\$$cpp_remembered_prop\"
			tet_infoline "ERR expected property $cpp_name to be" \
			    "'$cpp_value' but 'show -p' doesn't show that" \
			    "property"
			cpp_retval=1
		fi
	done

	return $cpp_retval
}

#
# NAME
#	protocol_property_verification
#
# SYNOPSIS
#	protocol_property_verification <group>
#
# DESCRIPTION
#	Execute the 'sharemgr show -p' command for the specified group to
#	retrieve the protocols and properties that sharemgr says are set for
#	that group.  Compare all of the protocols/properties reported by
#	'show -p' against those we think should be in place for the specified
#	group.
#
function protocol_property_verification {
	ppv_group="$1"
	ppv_retval=0

	#
	# Execute 'sharemgr show -p' command for the group and extract the
	# line of output that corresponds to the specified group.
	#
	eval debug_var=\"\$PROTOCOLS_${ppv_group}\"
	logfile=`get_logfile show -p`
	ppv_cmd="$SHAREMGR show -p"
	tet_infoline "  - $ppv_cmd"
	$ppv_cmd > $logfile 2>&1
	ppv_group_line="`$AWK ' { if ( $1 == group ) { print } } ' group=$ppv_group $logfile`"

	if [ ! "$ppv_group_line" ]
	then
		POS_result 1 \
		    "Unable to locate group '$ppv_group' in output of '$ppv_cmd'"
		return 1
	fi

	#
	# This is a really ugly sed line used to so that we can break up a
	# line that looks like:
	#	test_group_1 nfs=() nfs:dh=(ro="thistle:cawdor" rw="*")
	# so that we can get at the information for each individual protocol.
	# There's got to be a better way...
	#
	set `echo $ppv_group_line | $SED -e 's/=()//g' -e 's/\" /\"|/g' \
	    -e 's/) / /g' -e 's/)//g' -e 's/=(/|/g'`
	shift
	ppv_tmp_line="$*"

	#
	# Walk through each protocol and associated properties reported by
	# 'show -p'
	#
	eval ppv_remembered_protocols=\"\$PROTOCOLS_${ppv_group}\"
	unset ppv_checked_protocols
	for ppv_show_proto_info in $ppv_tmp_line
	do
		# The protocol info fields are currently separated by
		# pipe characters as a result of the ugly sed command
		# above.  Replace those with spaces and then place the resulting
		# string in $* so we can access each field individually.
		#
		set `echo $ppv_show_proto_info | $SED 's/|/ /g'`
		ppv_show_protocol="$1"
		shift

		#
		# Check the protocol from 'show -p' against the protocol(s)
		# that we think should be set for this share group.
		#
		unset ppv_protocol_match
		for ppv_compare_group in $ppv_remembered_protocols
		do
			if [ "$ppv_compare_group" = "$ppv_show_protocol" ]
			then
				ppv_protocol_match="yes"
				ppv_checked_protocols="$ppv_checked_protocols $ppv_show_protocol"
				break
			fi
		done

		#
		# If we expected this protocol, go compare the property settings
		#
		if [ "$ppv_protocol_match" ]
		then
			#
			# Take out the first colon if present due to a security
			# protocol.
			#
			ppv_show_protocol=`echo $ppv_show_protocol | $SED 's/://'`
			compare_protocol_properties $ppv_group $ppv_show_protocol $*
			if [ $? -ne 0 ]
			then
				POS_result 1 \
				    "Property verification failed for group $ppv_group protocol $ppv_show_protocol"
				ppv_retval=1
			fi
		else
			POS_result 1 \
			    "Protocol $ppv_show_protocol shown by 'show -p' but shouldn't be set for group $ppv_group"
			ppv_retval=1
		fi
	done

	#
	# We have checked every protocol reported by 'show -p' against those
	# we have stored.  Now we need to check every protocol we have
	# stored against those displayed by 'show -p' to make sure the show
	# command is not missing any of them.
	#
	for ppv_remembered_protocol in $ppv_remembered_protocols
	do
		unset ppv_protocol_match
		for ppv_checked_protocol in $ppv_checked_protocols
		do
			if [ "$ppv_checked_protocol" = "$ppv_remembered_protocol" ]
			then
				ppv_protocol_match="yes"
			fi
		done
		if [ ! "$ppv_protocol_match" ]
		then
			POS_result 1 \
			    "Group $ppv_group should have protocol $ppv_remembered_protocol set but 'show -p' doesn't show it"
			ppv_retval=1
		fi
	done

	return $ppv_retval
}

#
# NAME
#	create
#
# SYNOPSIS
#	create [POS or NEG] <group> [options for 'sharemgr create' command]
#
# DESCRIPTION
#	Execute 'sharemgr create' command and verify if the group was created
#	and has the expected options.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr create'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function create {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the create subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0
	unset c_negtext

	if [ "$1" = "NEG" ]
	then
		c_pos_neg=$1
		shift
	else
		c_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	c_group="$1"
	shift
	c_options="$*"

	# Parse options
	unset c_opt_n
	quasi_getopt c $c_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset c_dr_text
	if [ "$c_opt_n" ]
	then
		c_dr_text=" Dry run:"
	fi

	tet_infoline "*${c_dr_text} Create share group ($c_group) - $c_pos_neg"

	# Build the create command.
	c_cmd="${cmd_prefix}${SHAREMGR} create $c_options $c_group"

	logfile=`get_logfile create ${c_options}`
	# Execute the create command
	tet_infoline "  - $c_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $c_cmd${cmd_postfix} > $logfile 2>&1
		c_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $c_cmd${cmd_postfix}

	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

	if [ "$verbose" = "TRUE" ]
	then
		tet_infoline "Return code is $c_retval"
	fi

	#
	# Update variables used to remember configuration settings if the
	# create command succeeded and this is not a dry run.
	#
	if [ $c_retval -eq 0 -a ! "$c_opt_n" ]
	then
		#
		# Just in case we are adding multiple groups
		#
		for cgroup in ${c_group}
		do
			fnd=0
			for group in $GROUPS
			do
				if [ "$c_group" = "$group" ]
				then
					fnd=1
					break;
				fi
			done
			if [ $fnd -eq 0 ]
			then
				GROUPS="$GROUPS $c_group"
			fi
			#
			# Only update the various variables used to keep track
			# of information related to this share group if the
			# create operation was expected to pass.  If the
			# create command was expected to fail, we may have
			# been passed an invalid group name (e.g. contains
			# reserved characters) that will cause the shell
			# variable names (which incorporate the group name)
			# to be invalid and cause the shell to exit abnormally.
			#
			if [ "$c_pos_neg" = "POS" ]
			then
				eval unset SHARES_${cgroup}
				remember_protocol_settings $c_group create \
				    $c_options
			fi
		done
	fi

	if [ "$c_pos_neg" = "POS" ]
	then
		POS_result $c_retval "$c_cmd"
		#
		# Verify configuration changes if the command succeeded and
		# this is not a dry run.
		#
		if [ $c_retval -eq 0 -a ! "$c_opt_n" ]
		then
			#
			# o Verify group '$c_group' is shown in " \
			#    "list output."
			#
			list -v
			logfile=`get_logfile list -v`
			$GREP $c_group $logfile > /dev/null 2>&1
			c_result=$?
			if [ $c_pos_neg = "NEG" ]
			then
				NEG_result $c_result \
				    "$c_group found in list" \
				    "$c_group not found in list"
			else
				POS_result $c_result \
				    "$c_group not found in list" \
				    "$c_group found in list"
			fi

			eval EXP_STATE_${c_group}=\"enabled\"
			verify_group_state $c_group
			protocol_property_verification $c_group
		fi
	else
		NEG_result $c_retval "$c_cmd" "$c_cmd"
	fi

	return $c_retval
}


#
# NAME
#	delete
#
# SYNOPSIS
#	delete [POS or NEG] <group> [options for 'sharemgr delete' command]
#
# DESCRIPTION
#	Execute 'sharemgr delete' command and verify that the group was
#	deleted.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr delete'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function delete {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the delete subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0
	unset d_negtext

	if [ "$1" = "NEG" ]
	then
		d_pos_neg=$1
		d_negtext="- should fail"
		shift
	else
		d_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	#
	# If a protocol has been specified then the 'sharemgr delete' command
	# will just remove that protocol from the group.  If no protocol is
	# specified then the entire group will be deleted.
	#
	unset d_capture_protocol
	unset d_delete_protocol
	for d_arg in $*
	do
		if [ "$d_capture_protocol" ]
		then
			d_delete_protocol="$d_arg"
			break
		elif [ "$d_arg" = "-P" ]
		then
			d_capture_protocol="yes"
		fi
	done

	d_group="$1"
	shift
	d_options="$*"

	# Parse options
	unset d_opt_n
	quasi_getopt d $d_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset d_dr_text
	if [ "$d_opt_n" ]
	then
		d_dr_text=" Dry run:"
	fi

	d_valid_group=`valid_group $d_group`

	tet_infoline "*${d_dr_text} Delete share group ($d_group) - $d_pos_neg"

        #
	# Clear out the 'expected state' and 'share list' for the group to
	# be deleted.  (NOTE:  These two lines had been commented out for
	# reasons not remembered; uncommented them as we should be clearing
	# out these values.)
        #
	eval unset EXP_STATE_${d_group}
	eval unset SHARES_${d_group}

	logfile=`get_logfile delete ${d_options}`
	# Build and execute the 'sharemgr delete' command.
	d_cmd="${cmd_prefix}${SHAREMGR} delete $d_options $d_group"
	tet_infoline "  - $d_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $d_cmd${cmd_postfix} > $logfile 2>&1
		d_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $d_cmd${cmd_postfix}

	if [ $d_pos_neg = "POS" ]
	then
		POS_result $d_retval "$d_cmd"
	else
		NEG_result $d_retval "$d_cmd"
	fi

        #
	# If the delete command succeeded, clear the remembered protocol &
	# properties associated with the group and then delete the group
	# from the GROUPS list.  Skip if this was a dry run.
        #
	if [ $d_retval -eq 0 -a ! "$d_opt_n" ]
	then
		if [ "$d_delete_protocol" ]
		then
			#
			# Protocol $d_delete_protocol has been deleted from
			# the group but the group should still exist.  Remove
			# $d_delete_protocol from the list of protocols we
			# expect for this group.
			#
			eval d_tmp1=\"\$PROTOCOLS_${d_group}\"
			eval unset PROTOCOLS_${d_group}
			for d_protocol in $d_tmp1
			do
				if [ "$d_protocol" != "$d_delete_protocol" ]
				then
					eval PROTOCOLS_${d_group}=\"\$PROTOCOLS_${d_group} $d_protocol\"
				fi
			done
			clear_remembered_info $d_group protocol properties
			#
			# Verify that the group is still there (pass NEG
			# argument as, while the command succeeded, we don't
			# expect the group to have been deleted).
			#
			verify_group_delete NEG $d_group
		else
			#
			# The group has been deleted.   Clear out the 'expected
			# state' and 'share list' for the group to be deleted.
			eval unset EXP_STATE_${d_group}
			eval unset SHARES_${d_group}
			clear_remembered_info $d_group protocol properties
			remove_group_from_list $d_group

                        #
			# Verify '$d_group' is not shown in 'list' output
			# 	or (dependent on d_pos_neg)
			# Verify $d_group is still shown in 'list' output
                        #
			verify_group_delete $d_pos_neg $d_group
		fi
	fi

	return $d_retval
}

#
# NAME
#	disable
#
# DESCRIPTION
#	Execute 'sharemgr disable' command and verify that the specified
#	group(s) have indeed been disabled.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr disable'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function disable {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the disable subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		dis_pos_neg=$1
		shift
	else
		dis_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	dis_options="$1"
	shift
	dis_groups="$*"         # Group(s) to be disabled.

	# Parse options
	unset dis_opt_n
	quasi_getopt dis $dis_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset dis_dr_text
	if [ "$dis_opt_n" ]
	then
		dis_dr_text=" Dry run:"
	fi

	tet_infoline "*$dis_dr_text Disable share group(s) ($dis_groups) - $dis_pos_neg"

	logfile=`get_logfile disable ${dis_options}`
	# Build and execute disable command
	dis_cmd="${cmd_prefix} ${SHAREMGR} disable $dis_options $dis_groups"
	tet_infoline "  - $dis_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $dis_cmd${cmd_postfix} > $logfile 2>&1
		dis_result=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $dis_cmd${cmd_postfix}

	if [ "$dis_pos_neg" = "POS" ]
	then
		# o Verify return code is 0"
		POS_result $dis_result "$dis_cmd"

		# Update the state information we keep for this group if this
		# is not a dry run.
		if [ ! "$dis_opt_n" ]
		then
			for dis_group in $dis_groups
			do
				eval EXP_STATE_$dis_group=\"disabled\"
			done
		fi
	else
		# Verify return code != 0"
		NEG_result $dis_result "$dis_cmd"
		#
		# Need to reverse the pos_neg for the verification bit.
		#
		dis_pos_neg=POS;
	fi

	if [ "$dis_groups" -a ! "$dis_opt_n" ]
	then
		verify_groups $dis_pos_neg $dis_groups
	fi

	return $dis_result
}


#
# NAME
#	enable
#
# DESCRIPTION
#	Execute 'sharemgr enable' command and verify that the specified
#	group(s) have indeed been enabled.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr enable'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function enable {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the enable subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	unset en_all
	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		en_pos_neg=$1
		shift
	else
		en_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	en_options="$1"
	shift
	en_groups="$*"  # Group(s) to enable.  May include non-existent group(s)
			# for negative tests.

	# Parse options
	unset en_opt_n
	quasi_getopt en $en_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset en_dr_text
	if [ "$en_opt_n" ]
	then
		en_dr_text=" Dry run:"
	fi

	tet_infoline "*$en_dr_text Enable share groups ($en_groups) - $en_pos_neg"

	logfile=`get_logfile enable`
	# Build and execute command.
	en_cmd="${cmd_prefix}${SHAREMGR} enable $en_options $en_groups"
	tet_infoline "  - $en_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $en_cmd${cmd_postfix} > $logfile 2>&1
		en_result=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $en_cmd${cmd_postfix}

	if [ "$en_pos_neg" = "POS" ]
	then
                #
		# For a positive test case we expect zero exit status and for
		# the state of each group to be set to 'enabled'.
		# Verify return code is 0"
                #
		POS_result $en_result "$en_cmd"
		if [ ! "$en_opt_n" ]
		then
			for en_group in $en_groups
			do
				eval EXP_STATE_$en_group=\"enabled\"
			done
		fi
	else
                #
		# For a negative test case we expect non-zero exit status and
		# for the state of the group(s) to be unchanged.
		# Verify return code != 0"
                #
		NEG_result $en_result "$en_cmd"
		#
		# Need to reverse the positive/negative for the verify groups.
		#
		en_pos_neg=POS
	fi

	#
	# Verify the state of each group following the enable command.
	#
	if [ "$en_groups" -a ! "$en_opt_n" ]
	then
		verify_groups $en_pos_neg $en_groups
	fi

	return $en_result
}

#
# NAME
#	quasi_getopt
#
# SYNOPSIS
#	quasi_getopt prefix arg arg arg...
#
# DESCRIPTION
#	A quasi-getopts function to handle cases where multiple arguments to
#	a command are passed together in one variable.  For example, arguments
#	to 'sharemgr add' could contain:
#		-r "resource_name" -d "description text" -t
#	passed together in one shell variable with the quotes intact.  When
#	parsing an options list like this, you'd expect to get:
#		-r
#		resource_name
#		-d
#		description text
#		-t
#	but when the multiple arguments are passed together in one shell
#	variable, the shell will parse the line like:
#		-r
#		"resource_name"
#		-d
#		"description
#		text"
#		-t
#	This function is used to parse like the first example, whereas built-in
#	shell functions will do the second.  When passed a set of arguments it
#	will set variables as follows:
#		-x		Set <prefix>_opt_x to a white space (' ')
#		-x <value>	Set <prefix>_opt_x to <value>
#	The calling function can then determine what options/values were
#	invoked by checking the <prefix>_opt_<option> variable for each
#	option.  If the variable is not set then that option was not
#	invoked.  If the variable is set to a single white space then the
#	option was invoked with no following argument.  If the variable is
#	set to anything other than a single white space, then the option
#	was invoked with the argument listed in the <prefix>_opt_<option>
#	variable.
#
#	Be aware that this function eliminates any double quotes it finds
#	in arguments.
#
function quasi_getopt {
	qg_prefix=$1	# Prefix for variable names to be used
	shift

	unset qg_opt

	#
	# Step through each argument
	#
	for qg_arg in $*
	do
		if echo $qg_arg | grep "^-" >/dev/null 2>&1
		then
			# Remove the '-' to get single-character argument
			qg_opt="`echo $qg_arg | sed 's/^-//' `"
			# Initially, set the variable associated with the
			# current option to ' ' so that the calling function
			# can tell that the option was invoked.
			eval ${qg_prefix}_opt_${qg_opt}=\" \"
		elif [ "$qg_opt" ]
		then
			#
			# The current argument is not a switch (doesn't start
			# with '-') so append the arg to the value that we're
			# building for the current option after stripping any
			# double quotes out.
			#
			qg_tmp=`echo $qg_arg | sed 's/"//g' ` # Strip any quotes
			eval qg_tmp2=\"\$${qg_prefix}_opt_${qg_opt}\"
			if [ "$qg_tmp2" = " " ]
			then
				eval ${qg_prefix}_opt_${qg_opt}=\"$qg_tmp\"
			else
				eval ${qg_prefix}_opt_${qg_opt}=\"\$qg_tmp2 $qg_tmp\"
			fi
		fi
	done
}

#
# NAME
#	add_share
#
# SYNOPSIS
#	add_share [POS or NEG] <group> <options> <shares>
#
# DESCRIPTION
#	Execute 'sharemgr add-share' command and verify that the share(s)
#	were added to the expected group.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr add-share'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function add_share {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the add subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0
	as_result=0

	if [ "$1" = "NEG" ]
	then
		as_pos_neg=$1
		shift
	else
		as_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	as_group=$1
	as_options="$2"
	shift 2
	as_shares="$*"

	#
	# If the default protocol is smb then need
	# to add a dummy resource name to the options
	# as this is required with the smb protocol.
	#
	if [[ -n "$as_group" && $as_options != *-r* ]]
	then
		eval as_protocols=\"\$PROTOCOLS_$as_group\"
		if [[ $as_protocols == *smb* ]]
		then
			as_rname=${as_shares##/*/}
			eval as_options=\"$as_options -r res_name_$as_rname\"
		fi
	fi

	# Parse options
	unset as_opt_d as_opt_n as_opt_r as_opt_t
	quasi_getopt as $as_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset as_dr_text
	if [ "$as_opt_n" ]
	then
		as_dr_text=" Dry run:"
	fi

	tet_infoline "* -$as_dr_text Add share(s) ($as_shares) to group " \
	    "($as_group) - $as_pos_neg"

	logfile=`get_logfile add-share ${as_options}`
	# Build and execute command
	as_partial_cmd=""
	for as_share in $as_shares
	do
		as_partial_cmd="$as_partial_cmd -s $as_share"
	done
	as_cmd="${cmd_prefix}${SHAREMGR} add-share $as_options $as_partial_cmd $as_group"
	tet_infoline "  - $as_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $as_cmd${cmd_postfix} > $logfile 2>&1
		as_result=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $as_cmd${cmd_postfix}

	# Verify results of command.
	if [ "$as_pos_neg" = "POS" ]
	then
		POS_result $as_result "$as_cmd"
		#
		# If the 'add-share' command succeeded, and this is not a dry
		# run, save information about the share we just added for
		# later reference.
		#
		if [ $? -eq 0 -a ! "$as_opt_n" ]
		then
			#
			# If the shares are temporary, append "|tmp" to each
			# share name so that we can distinguish them from
			# permanent shares.
			#
			if [ "$as_opt_t" ]
			then
				unset as_shares_tmp
				for as_share in $as_shares
				do
					as_shares_tmp="$as_shares_tmp ${as_share}|tmp"
				done
				as_shares="$as_shares_tmp"
			fi

			#
			# Add the share(s) to the list of active shares for the
			# group.
			#
			eval SHARES_${as_group}=\"\$SHARES_${as_group} $as_shares\"

			# If the '-d' flag was given, remember the description.
			if [ "$as_opt_d" ]
			then
				for as_share in $as_shares
				do
					as_share_mod="`echo $as_share | \
					    sed -e 's/\//__/g' -e 's/|//g'`"
					if [ "$as_opt_d" = " " ]
					then
						eval unset DESC_${as_share_mod}
					else
						eval DESC_${as_share_mod}=\"$as_opt_d\"
					fi
				done
			fi

			# If the '-r' flag was given, remember the resource
			# name.
			if [ "$as_opt_r" ]
			then
				for as_share in $as_shares
				do
					as_share_mod="`echo $as_share | \
					    sed -e 's/\//__/g' -e 's/|//g'`"
					if [ "$as_opt_r" = " " ]
					then
						eval unset RSRC_${as_share_mod}
					else
						eval RSRC_${as_share_mod}=\"$as_opt_r\"
					fi
				done
			fi
		fi
	else
		NEG_result $as_result "$as_cmd"
	fi

	#
	# If this was not a dry run, verify that the share has been
	# added through 'sharemgr' and legacy methods (if appropriate).
	#
	if [ ! "$as_opt_n" ]
	then
		if [ $as_group ]
		then
			verify_share -g $as_group $as_pos_neg $as_shares
			legacy_share_confirm $as_group
		else
			verify_share $as_pos_neg $as_shares
		fi
	fi

	return $as_result
}


#
# NAME
#	set_share
#
# DESCRIPTION
#	Execute 'sharemgr set-share' command and verify that the share(s)
#	options were set as expected.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr set-share'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function set_share {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the set subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		ss_pos_neg=$1
		shift
	else
		ss_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	ss_share="$1"
	shift
	ss_options="$*"

	# Parse options
	unset ss_opt_d ss_opt_r ss_opt_n
	quasi_getopt ss $ss_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset ss_dr_text
	if [ "$ss_opt_n" ]
	then
		ss_dr_text=" Dry run:"
	fi

	ss_group=`which_group $ss_share`

	tet_infoline "*$ss_dr_text Set options for share ($ss_share) - " \
	    "$ss_pos_neg"

	logfile=`get_logfile set-share ${ss_options}`
	# Build and execute command
	ss_cmd="${cmd_prefix}${SHAREMGR} set-share $ss_options -s $ss_share $ss_group"
	tet_infoline "  - $ss_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $ss_cmd${cmd_postfix} > $logfile 2>&1
		ss_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $ss_cmd${cmd_postfix}

	# Verify return code is 0"
	if [ "$ss_pos_neg" = "POS" ]
	then
		POS_result $ss_retval "$ss_cmd"
	else
		NEG_result $ss_retval "$ss_cmd"
	fi

	#
	# If the command was successful, and this is not a dry run, update
	# the test's copy of the description and/or resource name as
	# appropriate.
	#
	if [ $ss_retval = 0 -a ! "$s_opt_n" ]
	then
		ss_share_mod="`echo $ss_share | sed 's/\//__/g'`"
		if [ "$ss_opt_d" ]
		then
			if [ "$ss_opt_d" = " " ]
			then
				eval unset DESC_${ss_share_mod}
			else
				eval DESC_${ss_share_mod}=\"$ss_opt_d\"
			fi
		fi

		if [ "$ss_opt_r" ]
		then
			if [ "$ss_opt_r" = " " ]
			then
				eval unset RSRC_${ss_share_mod}
			else
				eval RSRC_${ss_share_mod}=\"$ss_opt_d\"
			fi
		fi
	fi
	verify_share $ss_pos_neg $ss_share

	return $ss_retval
}

#
# NAME
#	set_security
#
# DESCRIPTION
#	Execute 'sharemgr set' command and verify that the share(s)
#	options were set as expected.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr set'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
function set_security {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the set security"
			tet_infoline "subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		ssec_pos_neg=$1
		shift
	else
		ssec_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	ssec_group="$1"
	shift
	ssec_options="$*"

	# Parse options
	unset ssec_opt_n
	quasi_getopt ssec $ssec_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset ssec_dr_text
	if [ "$ssec_opt_n" ]
	then
		ssec_dr_text=" Dry run:"
	fi

	tet_infoline "*$ssec_dr_text Set security options for group " \
	    "($ssec_group) $ssec_pos_neg"

	logfile=`get_logfile set_security ${ssec_options}`
	# Build and execute command
	ssec_cmd="${cmd_prefix}${SHAREMGR} set-security $ssec_options $ssec_group"
	tet_infoline "  - $ssec_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $ssec_cmd${cmd_postfix} > $logfile 2>&1
		ssec_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $ssec_cmd${cmd_postfix}

	#
	# Remember the changes we just made if the command succeeded and
	# we're not doing a dry run.
	#
	if [ $ssec_retval -eq 0 -a ! "$ssec_opt_n" ]
	then
		remember_protocol_settings $ssec_group set-security $ssec_options
	fi

	# o Verify return code is 0"
	if [ "$ssec_pos_neg" = "POS" ]
	then
		POS_result $ssec_retval "$s_cmd"
		protocol_property_verification $ssec_group
	else
		NEG_result $ssec_retval "$ssec_cmd"
	fi

	return $ssec_retval
}

#
# NAME
#	set_
#
# DESCRIPTION
#	Execute 'sharemgr set' command and verify that the share(s)
#	options were set as expected.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr set'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
function set_ {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the set subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		s_pos_neg=$1
		shift
	else
		s_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	s_group="$1"
	shift
	s_options="$*"

	# Parse options
	unset s_opt_n
	quasi_getopt s $s_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset s_dr_text
	if [ "$s_opt_n" ]
	then
		s_dr_text=" Dry run:"
	fi

	tet_infoline "*$s_dr_text Set options for group ($s_group) - $s_pos_neg"

	logfile=`get_logfile set ${s_options}`
	# Build and execute command
	s_cmd="${cmd_prefix}${SHAREMGR} set $s_options $s_group"
	tet_infoline "  - $s_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $s_cmd${cmd_postfix} > $logfile 2>&1
		s_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $s_cmd${cmd_postfix}

	# If the command succeeded, and this is not a dry run, update the
	# test's versions of the protocol settings.
	if [ $s_retval -eq 0 -a ! "$s_opt_n" ]
	then
		remember_protocol_settings $s_group set $s_options
	fi

	# Verify return code is 0"
	if [ "$s_pos_neg" = "POS" ]
	then
		POS_result $s_retval "$s_cmd"
		protocol_property_verification $s_group
	else
		NEG_result $s_retval "$s_cmd"
	fi

	return $set_retval
}

#
# NAME
#	unset
#
# DESCRIPTION
#	Execute 'sharemgr unset' command and verify that the share(s)
#	options were cleared as expected.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr unset'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
function unset_ {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the unset subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		us_pos_neg=$1
		shift
	else
		us_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	us_group="$1"
	shift
	us_options="$*"

	# Parse options
	unset us_opt_n
	quasi_getopt us $us_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset us_dr_text
	if [ "$us_opt_n" ]
	then
		us_dr_text=" Dry run:"
	fi

	tet_infoline "*$us_dr_text Unset options for group ($us_group) - " \
	    "$us_pos_neg"

	logfile=`get_logfile unset ${us_options}`
	# Build and execute command
	us_cmd="${cmd_prefix}${SHAREMGR} unset $us_options $us_group"
	tet_infoline "  - $us_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $us_cmd${cmd_postfix} > $logfile 2>&1
		us_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $us_cmd${cmd_postfix}

	# If the command succeeded, and this was not a dry run, update our
	# remembered settings for this group
	if [ $us_retval -eq 0 -a ! "$us_opt_n" ]
	then
		remember_protocol_settings $us_group unset $us_options
	fi

	# o Verify return code is 0"
	if [ "$us_pos_neg" = "POS" ]
	then
		POS_result $us_retval "$us_cmd"
		protocol_property_verification $us_group
	else
		NEG_result $us_retval "$us_cmd"
	fi

	return $us_retval
}

#
# NAME
#	remove_share
#
# SYNOPSIS
#	move_remove_share [POS or NEG] <options> <group> <list of shares>
#
# DESCRIPTION
#	Wrapper for the move_remove_share function for the remove-share
#	operation.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr remove-share'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function remove_share {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the remove subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		rs_pos_neg="$1"
		shift
	else
		rs_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	rs_group_arg="$1"
	rs_options="$2"
	shift 2
	rs_shares="$*"

	move_remove_share $rs_pos_neg "remove-share" "$rs_options" \
	    "$rs_group_arg" "$rs_shares"
	return $?
}

#
# NAME
#	move_share
#
# SYNOPSIS
#	move_remove_share [POS or NEG] <group> <options> <list of shares>
#
# DESCRIPTION
#	Wrapper for the move_remove_share function for the move-share operation.
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr move-share'
#	command.  So, even if called with 'NEG', a failure by the command
#	will result in non-zero status being returned.
#
function move_share {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the move subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	cmdlvl=0

	if [ "$1" = "NEG" ]
	then
		ms_pos_neg="$1"
		shift
	else
		ms_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	ms_group_arg="$1"
	ms_options="$2"
	shift 2
	ms_shares="$*"

	# Parse options
	unset ms_opt_n
	quasi_getopt ms $ms_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset ms_dr_text
	if [ "$ms_opt_n" ]
	then
		ms_dr_text=" Dry run:"
	fi

	move_remove_share $ms_pos_neg "move-share" "$ms_options" \
	    "$ms_group_arg" "$ms_shares"
	return $?
}

#
# NAME
#	move_remove_share
#
# SYNOPSIS
#	move_remove_share [POS or NEG] <'move-share' or 'remove-share'> \
#	  <group> <options> <list of shares>
#
# DESCRIPTION
#	Execute a 'move-share' or 'remove-share' sharemgr command
#
# RETURN VALUE
#	This function passes on the return value of the 'sharemgr move'
#	or 'sharemgr remove' command.  So, even if called with 'NEG', a
#	failure by the command will result in non-zero status being returned.
#
function move_remove_share {
	if [ "$1" = "NEG" ]
	then
		mrs_pos_neg="$1"
		shift
	else
		mrs_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	mrs_subcmd="$1"         # 'move-share' or 'remove-share'
	mrs_options="$2"	# Options for 'move-share' or 'remove-share'
	mrs_group_arg="$3"      # For 'move-share', the group to move the
				# shares to.  For 'remove-share', the group
				# to remove the shares from.
	shift 3
	mrs_shares="$*"         # List of shares to move.
				# unset mrs_ogroups
	unset mrs_agroups       # List of (real) groups affected by
				# the move.

	# Parse options
	unset mrs_opt_n
	quasi_getopt mrs $mrs_options

	#
	# Determine if the info message for this command should indicate
	# that it is a dry run.
	#
	unset mrs_dr_text
	if [ "$mrs_opt_n" ]
	then
		mrs_dr_text=" Dry run:"
	fi

	if [ "$mrs_subcmd" = "move-share" ]
	then
		tet_infoline "*$mrs_dr_text Move shares ($mrs_shares) to " \
		    "group ($mrs_group_arg) - $mrs_pos_neg"
	else
		tet_infoline "*$mrs_dr_text Remove shares ($mrs_shares) from " \
		    "group ($mrs_group_arg) - $mrs_pos_neg"
	fi

	#
	# If one or more share names have been provided (might not be for
	# negative test cases) then set the shares argument we'll use on
	# the command line.  If not, clear the shares argument.
	#
	if [ "$mrs_shares" ]
	then
		mrs_share_args="-s $mrs_shares"
	else
		unset mrs_share_args
	fi

	logfile=`get_logfile $msr_subcmd`
	#
	# Build the command, execute it, and append it to the list of
	# commands executed by the current test case.
	#
	mrs_cmd="${cmd_prefix}${SHAREMGR} $mrs_subcmd $mrs_options $mrs_share_args $mrs_group_arg"
	tet_infoline "  - $mrs_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		clean_logs
		eval $mrs_cmd${cmd_postfix} > $logfile 2>&1
		mrs_retval=$?
	fi
	append_cmd $mrs_cmd${cmd_postfix}

	#
	# Expect different return codes depending on if this is a positive
	# or negative test case.
	#
	if [ "$mrs_pos_neg" = "POS" ]
	then
		POS_result $mrs_retval "$mrs_cmd"
	else
		NEG_result $mrs_retval "$mrs_cmd"
	fi

	if [ "$mrs_pos_neg" = "POS" -a ! "$mrs_opt_n" ]
	then
		#
		# For each share, remove them from the list corresponding to
		# their 'old' group.  If this is a 'move' command rather than a
		# 'remove' command, add them to the list for their 'new' group.
		#
		for mrs_share in $mrs_shares
		do
			if [ "$mrs_subcmd" = "remove-share" ]
			then
				# Shares specified for a 'remove-share' command
				# will come from the group specified.
				if [ "$mrs_group_arg" ]
				then
					mrs_old_groups="$mrs_group_arg"
				else
					mrs_old_groups=`which_group $mrs_share`
					mrs_group_arg="$mrs_old_groups"
				fi
			else
				# Shares specified for a 'move-share' command
				# come from any defined group.
				mrs_old_groups="$GROUPS"
			fi

			#
			# Determine if the group name is valid (it might not be
			# for a negative test case).  If so, add it to the list
			# of groups affected by the command.
			#
			mrs_valid="`valid_group $mrs_group_arg`"
			if [ "$mrs_valid" ]
			then
				mrs_agroups="$mrs_group_arg"
			fi

			for mrs_old_group in $mrs_old_groups
			do
				unset mrs_new_list
				unset mrs_match

				# XXX Can't wrap the following:
				eval mrs_old_group_shares=\"\$SHARES_${mrs_old_group}\"
				for mrs_old_group_share in \
				    $mrs_old_group_shares
				do
					if [ "$mrs_share" = \
					    "$mrs_old_group_share" ]
					then
						mrs_match="$mrs_share"
					else
						# XXX Can't wrap the following:
						mrs_new_list="$mrs_new_list $mrs_old_group_share"
					fi
				done

				if [ "$mrs_match" ]
				then
					# This was the 'old' group the share
					# belonged to.
					# XXX Can't wrap the following:
					mrs_agroups="$mrs_agroups $mrs_old_group"
					if [ "$mrs_valid" ]
					then
                                                #
						# If the 'old' group is a valid
						# group, update its list of
						# shares.
						# This line is over 80
						# charaters in length, but
						# splitting it causes eval
						# to not be happy
                                                #
						eval SHARES_${mrs_old_group}=\"$mrs_new_list\"
					fi
					break
				fi
			done

			#
			# If this is a 'move-share' command, and the target
			# group name is valid, add the current share to the
			# list of shares in the target group.
			#
			if [ "$mrs_subcmd" = "move-share" ]
			then
				# If the new group is valid, add this share to
				# the list of shares in that group.
				if [ "$mrs_valid" ]
				then
                                        #
					# Wrapping the following line causes
                                        # eval to be unhappy.
                                        #
					eval SHARES_${mrs_group_arg}=\"\$SHARES_${mrs_group_arg} $mrs_share\"
				fi
			fi
		done
	fi

	#
	# Validate the current shares in all defined groups following the
	# operation.  We do this even if the command was a dry run or expected
	# to fail in order to insure that the command did not mess them up.
	#
	for mrs_check_group in `unique $GROUPS`
	do
		tet_infoline "* Verify configuration of shares in group" \
		    "$mrs_check_group using sharemgr commands."
		show $mrs_check_group
		eval mrs_group_shares=\"\$SHARES_${mrs_check_group}\"
		# Verify show output for group " \
		# "$mrs_check_group displays these shares: $mrs_group_shares"
		verify_share -g $mrs_check_group $mrs_group_shares
		legacy_share_confirm $mrs_check_group
	done

	return $mrs_retval
}

#
# NAME
#	set_ctl
#
# SYNOPSIS
#	take one or more properties and set them for the default protocol
#
# DESCRIPTION
#	Use the default protocol variable to determine the protocol that the
#	sharectl set command will use to set the provided properties to the
#	given values.  The first argument is will optionally be the POS/NEG
#	indicating the expected outcome of the call to sharectl set.  The
#	second argument will be the property followed by the value for that
#	argument.  If the value is ctl_reset then the argment will be taken
#	from the stored configuration.  These type of argument coupling will
#	proceed through until the last argument without a value, provided to
#	override the default protocol setting.
#
#	The information for each property will also, be stored
#	in as expected configuration for later verification via the
#	sharectl get interface.
#
# RETURN VALUE
#	This function passes on the return value of the sharectl set call.
#
function set_ctl {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the set subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	if [ "$1" = "NEG" ]
	then
		sctl_pos_neg="$1"
		shift
	else
		sctl_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	tet_infoline "* sharectl set property information"

	unset sctl_options
	unset sctl_properties
	unset sctl_values
	sctl_protocol="$def_protocols"
	sctl_nextarg=$1
	while [ "$sctl_nextarg" ]
	do
		shift
		sctl_value=$1
		if [ "$sctl_value" ]
		then
			if [ "$sctl_value" = "ctl_reset" ]
			then
				sctl_value=`get_ctl_default $sctl_nextarg`
			fi
			sctl_options="$sctl_options -p ${sctl_nextarg}=${sctl_value}"
			sctl_properties="$sctl_properties ${sctl_nextarg}"
			set -A sctl_values ${sctl_values[*]} \"${sctl_value}\"
			shift
		else
			sctl_protocol=$sctl_nextarg
		fi
		sctl_nextarg=$1
	done

	# Build the create command.
	sctl_cmd="${cmd_prefix}${SHARECTL} set $sctl_options $sctl_protocol"

	logfile=`get_logfile sharectl set ${sctl_options}`
	tet_infoline "  - $sctl_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		nfsd_pid=`$PGREP nfsd`
		clean_logs
		eval $sctl_cmd${cmd_postfix} > $logfile 2>&1
		sctl_retval=$?
	fi

	# Append command to list of commands executed by this test case.
	append_cmd $c_cmd${cmd_postfix}

	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

	if [ $sctl_pos_neg = "POS" ]
	then
		#
		# Report on the return code.
		#
		POS_result $sctl_retval "$sctl_cmd"

		#
		# Go through and update all the stored information for
		# each property.
		#
		sctl_cntr=0
		for sctl_property in $sctl_properties
		do
			eval CTLPROP_${sctl_protocol}_${sctl_property}=${sctl_values[${sctl_cntr}]}
			sclt_cntr=`expr $sctl_cntr + 1`
		done
		#
		# if the return code was valid then verify the results
		# for each property.
		#
		if [ $sctl_retval -eq 0 ]
		then
			for scsl_property in $sctl_properties
			do
				verify_ctl_properties -P $sctl_protocol \
				    $sctl_property
			done
		fi
	else
		NEG_result $sctl_retval "$sctl_cmd"
	fi

	return $sctl_retval
}


#
# NAME
#	get_ctl
#
# SYNOPSIS
#	take one or more (or zero) properties and get the property values
#
# DESCRIPTION
#	Will take as the first agrument the POS/NEG as optional.
#
# RETURN VALUE
#	This function passes on the return value of the sharectl get call.
#
function get_ctl {
	if [ "$1" != "NO_RESULT_CHK" -a "$sharemgr_NO_RESULT_CHK" != "TRUE" ]
	then
		CUR_RESULT=`get_tet_result`
		if [ "$CUR_RESULT" != "PASS" ]
		then
			tet_infoline "The current state of the test case is"
			tet_infoline "not PASS. Skipping the get subcommand."
			tet_infoline "This can be overridden by setting the"
			tet_infoline "environment variable"
			tet_infoline "sharemgr_NO_RESULT_CHK to TRUE"
			return
		fi
	elif [ "$1" = "NO_RESULT_CHK" ]
	then
		shift
	fi

	if [ "$1" = "NEG" ]
	then
		gctl_pos_neg="$1"
		shift
	else
		gctl_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	tet_infoline "* sharectl get property information"

	unset gctl_options
	unset gctl_properties
	gctl_protocol="$def_protocols"
	gctl_nextarg=$1
	while [ "$gctl_nextarg" ]
	do
		if [ "$gctl_nextarg" = "-P" ]
		then
			gctl_protocol=$2
			shift
		else
			gctl_options="$gctl_options -p ${gctl_nextarg}"
		fi
		shift
		gctl_nextarg=$1
	done

	# Build the create command.
	gctl_cmd="${cmd_prefix}${SHARECTL} get $gctl_options $gctl_protocol"

	logfile=`get_logfile sharectl get ${gctl_options}`
	tet_infoline "  - $gctl_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		nfsd_pid=`$PGREP nfsd`
		clean_logs
		eval $gctl_cmd${cmd_postfix} > $logfile 2>&1
		gctl_retval=$?
	fi

	if [ $gctl_pos_neg = "POS" ]
	then
		POS_result $gctl_retval "$l_cmd"
	else
		NEG_result $gctl_retval "$l_cmd"
	fi

	return $gctl_retval
}
