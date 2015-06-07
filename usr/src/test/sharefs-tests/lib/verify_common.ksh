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
# ident	"@(#)verify_common.ksh	1.7	09/08/23 SMI"
#

#
# This file contains common sharemgr verification functions and is meant to be
# sourced into the test case files.
#

#
# NAME
#	count_shares
#
# DESCRIPTION
#	Count the number of shares listed by sharemgr
#
function count_shares {
	cs_ret_cnt=0

	for cs_group in `$SHAREMGR list -v | $GREP enabled | $AWK '{print $1}'`
	do
		cs_cnt=`$SHAREMGR show $cs_group | $WC -l`
		if [ $cs_cnt -gt 0 ]
		then
			cs_ret_cnt=`$EXPR $cs_ret_cnt + $cs_cnt - 1`
		fi
	done

	echo $cs_ret_cnt
}


#
# NAME
#       unique
#
# DESCRIPTION
#       Delete duplicate entries from the input list.
#
function unique {
	unset u_output_list
	for u_input in $*
	do
		unset u_match
		for u_output in $u_output_list
		do
			if [ "$u_input" = "$u_output" ]
			then
				u_match="yes"
				break
			fi
		done
		if [ ! "$u_match" ]
		then
			u_output_list="$u_output_list $u_input"
		fi
	done
	echo $u_output_list
}

#
# NAME
#	valid_group
#
# DESCRIPTION
#	Determine if the specified group name is valid (is listed in the
#	global GROUPS variable).
#
function valid_group {
	vg_group="$1"

	#
	# If the group name isn't null...
	#
	if [ "$vg_group" ]
	then
		#
		# Check it against every group that was created by this
		# test case looking for a match.
		#
		for vg_valid_group in $GROUPS
		do
			if [ "$vg_group" = "$vg_valid_group" ]
			then
				echo "yes"
				return
			fi
		done
	fi

	echo ""
}

#
# NAME
#	legacy_share_confirm
#
# DESCRIPTION
#	For the specified group, verify that the shares and options belonging
#	to the group are accurately reflected by the 'legacy' commands &
#	configuration files pertaining to shares.
#
function legacy_share_confirm {
	if [ "$1" = "NEG" ]
	then
		lsc_pos_neg=$1
		shift
	else
		lsc_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	lsc_group="$1"

	if [ ! $LEGACYSHARE ]
	then
		return
	fi

	tet_infoline "* Verify configuration of shares in group " \
	    "$lsc_group using legacy methods"

	eval lsc_shares=\"\$SHARES_${lsc_group}\"

	#
	# Verify share(s) using /usr/sbin/share
	#
	lsc_cmd="/usr/sbin/share"
	tet_infoline " - $lsc_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		eval $lsc_cmd > /dev/null 2>&1
		lsc_result=$?
	fi
	append_cmd $lsc_cmd
	# Verify return code is 0"
	if [ "$lsc_pos_neg" = "POS" ]
	then
		POS_result $lsc_result "$lsc_cmd"
	else
		NEG_result $lsc_result "$lsc_cmd"
	fi

	eval lsc_exp_state=\"\$EXP_STATE_${lsc_group}\"
	for lsc_share in $lsc_shares
	do
		lsc_share="`echo $lsc_share | sed 's/|tmp$//'`"	# Strip "|tmp"

		if [ "$lsc_exp_state" = "enabled" ]
		then
			# Verify $lsc_share is shown in 'share' output 
			if [ "$report_only" != "TRUE" ]
			then
				$LEGACYSHARE | $GREP $lsc_share > /dev/null 2>&1
				lsc_result=$?
			fi
			if [ "$lsc_pos_neg" = "POS" ]
			then
				POS_result $lsc_result "$lsc_share shared"
			else
				NEG_result $lsc_result "$lsc_share not shared"
			fi
			# Verify $lsc_share has options matching $lsc_group"
			verify_share_options nfs
		else
			# Verify $lsc_share is NOT shown in 'share' output"
			if [ "$report_only" != "TRUE" ]
			then
				$LEGACYSHARE | $GREP $lsc_share > /dev/null 2>&1
				lsc_result=$?
			fi
			if [ "$lsc_pos_neg" = "POS" ]
			then
				NEG_result $lsc_result "$lsc_share not shared"
			else
				POS_result $lsc_result "$lsc_share shared"
			fi
		fi
	done

	#
	# Verify share(s) using /usr/sbin/dfshares
	#
	lsc_cmd="$DFSHARES -F nfs"
	tet_infoline " - $lsc_cmd"
	if [ "$report_only" != "TRUE" ]
	then
		eval $lsc_cmd > $dfs_log 2>&1
		lsc_result=$?
	fi
	append_cmd $lsc_cmd

	if [ "$report_only" = "TRUE" ]
	then
		return
	fi
	# Verify return code is 0"
	#
	# Need to check if there are any enabled groups with shares, because
	# if there are no enabled shares then dfshares will return
	# 1 instead of 0 as a return code.
	#
	# Also, check to see if mountd is running because dfstab will
	# fail in this case also.
	#
	$PGREP -x mountd > /dev/null 2>&1
	lsc_mntdrunning=$?
	lsc_share_cnt=`count_shares`
	if [ $lsc_share_cnt -eq 0 -o $lsc_mntdrunning -ne 0 ]
	then
		NEG_result $lsc_result $lsc_cmd
	else
		POS_result $lsc_result $lsc_cmd

		for lsc_share in $lsc_shares
		do
			lsc_share="`echo $lsc_share | sed 's/|tmp$//'`"
			if [ "$lsc_exp_state" = "enabled" ]
			then
				#
				# Verify $lsc_share is shown in 
				# 'dfshares' output"
                                #
				$GREP "$lsc_share" $dfs_log > /dev/null 2>&1
				POS_result $? \
				    "$lsc_share should be shown in 'dfsshares' output but isn't"
			else
				#
				# Verify $lsc_share is NOT shown in 
				# 'dfshares' output"
                                #
				$GREP "$lsc_share" $dfs_log > /dev/null 2>&1
				NEG_result $? \
				    "$lsc_share should not be shown in 'dfsshares' output but is"
			fi
		done
	fi

	#
	# Verify share(s) using /etc/dfs/dfstab
	#
	unset lsc_err
	for lsc_share in $lsc_shares
	do
		unset lsc_tmp_share
		echo $lsc_share | $GREP "|tmp" >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
			lsc_share="`echo $lsc_share | sed 's/|tmp$//'`"
			lsc_tmp_share="yes"
		fi
		#
		# If not temporary (no way to show yet, but should be
		# added.
		#
		# If the state is disabled the share will still show
		# in the dfstab.  Should ultimately remove the enable
		# check here altogether most likely.
		#
		if [ "$lsc_exp_state" = "enabled" ]
		then
                        #
			# Verify $lsc_share is shown in /etc/dfs/dfstab 
			# config file
                        #
			$GREP "$lsc_share" $DFSTAB > /dev/null 2>&1
			lsc_retval=$?
			if [ "$lsc_tmp_share" ]
			then
				NEG_result $lsc_retval \
				    "$DFSTAB contains tmp share $lsc_share but shouldn't"
				if [ $? -eq 0 ]
				then
					lsc_err=1
				fi
			else
				POS_result $lsc_retval \
				    "$DFSTAB doesn't contain share $lsc_share but should"
				if [ $? -ne 0 ]
				then
					lsc_err=1
				fi
			fi
		fi
	done

	#
	# Print out the contents of the dfstab file if we found any problems
	# with it.
	#
	if [ "$lsc_err" ]
	then
		tet_infoline "------------- Contents of $DFSTAB --------------"
		infofile "" $DFSTAB
		tet_infoline "------------------------------------------------"
	fi

	#
	# Check that the perms are correct on dfstab.
	#
	# Going to make this as a warning because all tests will fail
	# if this is broken.
	#
	pkgchk -a -P /etc/dfs/dfstab > /dev/null 2>&1
	lsc_res=$?
	if [ $lsc_res -ne 0 ]
	then
		tet_infoline "WARNING - expected attributes are not set correctly"\
			"for /etc/dfs/dfstab"
		pkgchk -a -P /etc/dfs/dfstab > $SHR_TMPDIR/lsc_pkgchk.$$ 2>&1
		infofile "  " $SHR_TMPDIR/lsc_pkgchk.$$
		rm -f $SHR_TMPDIR/lsc_pkgchk.$$
	fi

	#
	# Verify share(s) using /etc/dfs/sharetab
	#
	unset lsc_err
	for lsc_share in $lsc_shares
	do
		lsc_share="`echo $lsc_share | sed 's/|tmp$//'`"
		# if not temporary (no way to show yet, but should be
		# added.
		if [ "$lsc_exp_state" = "enabled" ]
		then
                        #
			# Verify $lsc_share is shown in /etc/dfs/sharetab 
			# config file"
                        #
			$GREP "$lsc_share" $SHARETAB > /dev/null 2>&1
			POS_result $? "$lsc_share listed in $SHARETAB"
			if [ $? -ne 0 ]
			then
				lsc_err=1
			fi
		else
                        #
			# Verify $lsc_share is NOT shown in 
			# /etc/dfs/sharetab config file
                        #
			$GREP "$lsc_share" $SHARETAB > /dev/null 2>&1
			NEG_result $? "$lsc_share not listed in $SHARETAB"
			if [ $? -eq 0 ]
			then
				lsc_err=1
			fi
		fi
	done

	#
	# Print out the contents of the sharetab file if we found any problems
	# with it.
	#
	if [ "$lsc_err" ]
	then
		tet_infoline "------------ Contents of $SHARETAB -------------"
		infofile "" $SHARETAB
		tet_infoline "------------------------------------------------"
	fi

	#
	# Check that the perms are correct on sharetab.
	#
	# Going to make this as a warning because all tests will fail
	# if this is broken.
	#
	lsc_res=`$FIND /etc/dfs/sharetab -perm 0444 | $WC -l`
	if [ $lsc_res -eq 0 ]
	then
		tet_infoline "WARNING - expected perms (0444) "\
		    "not set for sharetab"
	fi
	lsc_expectedog="rootroot"
	lsc_realog=`$LS -l /etc/dfs/sharetab | $AWK '{print $3 $4}'`
	if [ "$lsc_expectedog" != "$lsc_realog" ]
	then
		tet_infoline "WARNING - owner/group $lsc_expectedog incorrect" \
		    "for dfstab $lsc_realog"
	fi
}

#
# NAME
#	verify_groups
#
# DESCRIPTION
#	For all groups specified, verify the state of the groups using both
#	'new' and 'legacy' methods.
#
function verify_groups {
	if [ "$1" = "NEG" ]
	then
		vg_pos_neg=$1
		shift
	else
		vg_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	for v_group in $*
	do
		# Some group names may be bogus (non-existent) for negative
		# tests.  Check the group name against the list of 'real'
		# groups (list made by the 'create' function) before attempting
		# verification.
		for v_real_group in $GROUPS
		do
			if [ "$v_group" = "$v_real_group" ]
			then
				verify_group_state $vg_pos_neg $v_group
				legacy_share_confirm $v_group
				break
			fi
		done
	done
}

#
# NAME
#	verify_group_state
#
# DESCRIPTION
#	For the specified group, verify that the state shown by the reporting
#	commands matches the state we expect.
#
function verify_group_state {
	if [ "$1" = "NEG" ]
	then
		vgs_pos_neg=$1
		shift
	else
		vgs_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	vgs_groups="$*"

	#
	# * Verify expected enable/disable state for "\
	#    "group(s) $vgs_groups"
	#

	list -v
	logfile=`get_logfile list -v`
	for vgs_group in $vgs_groups
	do
		eval vgs_exp_state=\$EXP_STATE_${vgs_group}
		#
		# Verify state for '$vgs_group' in "
		#    "'list -v' output is '$vgs_exp_state'"
		#
		$GREP $vgs_group $logfile | \
		    $GREP $vgs_exp_state > /dev/null 2>&1
		vgs_result=$?
		if [ "$vgs_pos_neg" = "POS" ]
		then
			POS_result $vgs_result "$vgs_group not in $vgs_exp_state"
		else
			NEG_result $vgs_result "$vgs_group $vgs_exp_state"
		fi
	done
}

#
# NAME
#	verify_trd
#
# SYNOPSIS
#	verify_trd <share> <file containing 'show -v' output>
#
# DESCRIPTION
#	Verify tmp status, resource name, and description for a share.
#	For the specified share, determine if the output of 'show -v'
#	lists the proper:
#		- Persistent (temporary or permanent)
#		- Resource name
#		- Description
#
function verify_trd {
	vt_share="$1"
	vt_logfile="$2"

	# Separate share name from '|tmp' suffix (if present)
	vt_share_strip="`echo $vt_share | sed 's/|tmp//' ` "

	#
	# Determine if the persistence (permanent or temporary) of the
	# share displayed in 'show -v' output matches what we set up.
	#

	if $GREP $vt_share_strip $vt_logfile | $GREP "\*" > /dev/null 2>&1
	then
		# 'show -v' indicates temporary share
		vt_tmp_in_show=0
	else
		# 'show -v' doesn't indicate temporary share
		vt_tmp_in_show=1
	fi

	if echo $vt_share | $GREP "|tmp" > /dev/null 2>&1
	then
		# The share had been added as a temporary share
		POS_result $vt_tmp_in_show \
		    "Expected '*' before $vs_share_strip in 'show -v' output"
	else
		# The share had been added as a permanent share
		NEG_result $vt_tmp_in_show \
		    "Didn't expect '*' before $vs_share_strip in 'show -v' output"
	fi

	# Get the resource name and description that we remember for this
	# share.  The variable names are based on the share name, but use
	# double underscores in place of each slash.  The | symbol is removed
	# becuase the remembered value removed the pipe symbol from its
	# variable name.
	vt_share_mod="`echo $vt_share | sed -e 's/\//__/g' -e 's/|//g'`"
	eval vt_remembered_rsrc=\"\$RSRC_${vt_share_mod}\"
	eval vt_remembered_desc=\"\$DESC_${vt_share_mod}\"

	#
	# Extract resource name from 'show -v' output and compare it to the
	# value we remember for this share.
	#
	unset vt_show_rsrc
	if $GREP $vt_share_strip $vt_logfile | $GREP "=" >/dev/null 2>&1
	then
		vt_show_rsrc="`$GREP $vt_share_strip $vt_logfile | \
		    $GREP "=" | $SED 's/^[ |	]*//g' | $AWK -F= '{print $1}'`"
	fi
	if [ "$vt_remembered_rsrc" != "$vt_show_rsrc" ]
	then
		POS_result 1 \
		    "Expected resource name '$vt_remembered_rsrc' but 'show -v' gives '$vt_show_rsrc'"
	fi

	#
	# Extract description from 'show -v' output and compare it to the
	# value we remember for this share.
	#
	unset vt_show_desc
	if $GREP $vt_share_strip $vt_logfile | $GREP "\"$" >/dev/null 2>&1
	then
		vt_show_desc="`$GREP $vt_share_strip $vt_logfile | \
		    sed 's/\"$//' | sed 's/^.*\"//' `"
	fi
	if [ "$vt_remembered_desc" != "$vt_show_desc" ]
	then
		POS_result 1 \
		    "Expected description '$vt_remembered_desc' but 'show -v' gives '$vt_show_desc'"
	fi
}

#
# NAME
#	verify_share
#
# DESCRIPTION
#	Verify that a share(s) is listed in the show output and listed in
#	the specified group if a group is given.
#
# Note:  Steps needed to confirm output of 'sharemgr show' not known
# yet as functional spec doesn't provide the necessary details.
# So this may change, but for now will use the current state of 
# things.
#
function verify_share {
	unset vs_share
	unset vs_group


	while getopts g: options
	do
		case $options in
		g) vs_group=$OPTARG;;
		esac
	done

	vs_sharenotlistgrpmsg="vs_share : \$vs_share not listed in \$vs_group"
	vs_sharelistgrpmsg="vs_share : \$vs_share listed in \$vs_group"
	vs_sharenotlistmsg="vs_share : \$vs_share not listed"
	vs_sharelistmsg="vs_share : \$vs_share listed"
	vs_groupnotlistmsg="\$vs_group not listed"
	vs_grouplistmsg="\$vs_group listed"

	shift $((OPTIND - 1))
	if [ "$1" = "NEG" ]
	then
		vs_pos_neg=$1
		shift
	else
		vs_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	vs_shares=$*
	show -v $vs_group
	logfile=`get_logfile show -v $vs_group`
	infofile "show -v: " $logfile

	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

	if [ $vs_group ]
	then
		$GREP $vs_group $logfile > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			eval tet_infoline "FAIL - $vs_groupnotlistmsg"
			tet_result FAIL
		else
			if [ "$verbose" = "TRUE" ]
			then
				eval tet_infoline "PASS - $vs_grouplistmsg"
			fi

			#
			# For every share we remember being in this group...
			#
			for vs_share in $vs_shares
			do
				#
				# Strip the temporary share indicator off of
				# the share name (if present).
				#
				vs_share_strip="`echo $vs_share | \
				    sed 's/|tmp//' ` "

				#
				# Verify that the share is present in the
				# output of the 'show' command.
				#
				vs_share_line="`$GREP $vs_share_strip $logfile`"
				if [ "$vs_share_line" ]
				then
					vs_result=0

					#
					# Verify persistence (permanent or
					# temporary, resource name, and
					# description for the share.
					#
					verify_trd "$vs_share" $logfile
				else
					vs_result=1
				fi
				if [ $vs_pos_neg = "NEG" ]
				then
					NEG_result $vs_result \
					   "$vs_sharelistgrpmgs" \
					   "$vs_sharenotlistgrpmsg"
				else
					POS_result $vs_result \
					    "$vs_sharenotlistgrpmsg" \
					    "$vs_sharelistmsg"
				fi
			done
		fi
	else
		#
		# No group specified
		#
		for vs_share in $vs_shares
		do
			# Strip appended "|tmp" off $vs_share if present
			vs_share_strip="`echo $vs_share | sed 's/|tmp//' ` "

			$GREP $vs_share_strip $logfile > /dev/null 2>&1
			vs_result=$?
			if [ $vs_pos_neg = "NEG" ]
			then
				NEG_result $vs_result "$vs_sharelistmsg" \
				    "$vs_sharenotlistmsg"
			else
				POS_result $vs_result "$vs_sharenotlistmsg" \
				    "$vs_sharelistmsg"
			fi
		done
	fi

	#
	# Need to additionally verify that shares listed in a group
	# are supposed to be listed in the group
	#
	vs_shareshownnotmsg="\$share_shown should not be listed in \$vs_group"
	vs_shareshownmsg="\$share_shown should be listed in \$vs_group"

	if [ $vs_group ]
	then
		vs_grouplist=$vs_group
	else
		vs_grouplist=`unique $GROUPS`
	fi
	for vs_group in $vs_grouplist
	do
		unset shares_shown
		unset vs_group_shares

		eval vs_group_shares=\"\$SHARES_${vs_group}\"
		show $vs_group
		build_group_to_share $logfile
		eval vs_shares_shown=\${gts_${vs_group}[*]}
		for vs_share_shown in $vs_shares_shown
		do
			found=0
			for vs_share in $vs_group_shares
			do
				# Strip off the '|tmp' appendix from the
				# share name (if present)
				vs_share="`echo $vs_share | sed 's/|tmp//' ` "
				debug=$?
				if [ $vs_share_shown = $vs_share ]
				then
					found=1
					break;
				fi
			done
			if [ $found -eq 0 ]
			then
				eval tet_infoline "FAIL - $vs_shareshownnotmsg"
				tet_result FAIL
			else 
				if [ "$verbose" = "TRUE" ]
				then
					eval tet_infoline \
					    "PASS $vs_shareshownmsg"
				fi
			fi
		done
	done
}

#
# NAME
#	verify_group_delete
#
# DESCRIPTION
#	verify that the group is not listed or listed, depending on the POS
#	NEG option, in the output of sharemgr list
#
# NOTE : POS is the default
#
function verify_group_delete {
	if [ "$1" = "NEG" ]
	then
		vgd_pos_neg=$1
		shift
	else
		vgd_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	vgd_group=$1
	
	# Verify group '$d_group' is not shown in 'list' output"
	list
	logfile=`get_logfile list`
	$GREP $vgd_group $logfile > /dev/null 2>&1
	vgd_result=$?
	#
	# Note : The reverse of POS and NEG functions are being called
	# because grep returning 1 is really a positive result for this
	# case.
	#
	if [ "$vgd_pos_neg" = "POS" ]
	then
		NEG_result $vgd_result "$vgd_group listed, was not deleted" \
		    "$vgd_group not listed, was deleted"
	else
		POS_result $vgd_result "$vgd_group not listed, was deleted" \
		    "$vgd_group listed, was not deleted"
	fi
}

#
# NAME
#	verify_share_options
#
# DESCRIPTION
#	Confirm that the options listed in the LEGACYSHARE command and sharemgr
#	match up properly.  Can pass a specific protocol for checking.
#	NOTE : This is using 2 variables set in the calling function :
#		$lsc_group
#		$lsc_share
#
function verify_share_options {
	if [ $1 ]
	then
		vso_prot=$1
	else
		vso_prot="all"
	fi
	
	# Verify $lsc_share has options matching $lsc_group"
	show -p -P $vso_prot $lsc_group
	logfile=`get_logfile show -p -P $vso_prot $lsc_group`
	append_cmd $LEGACYSHARE
	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

	vso_lsc_options=`$LEGACYSHARE | $GREP $lsc_share | \
	    $AWK '{print $3}' | sed s/\"//g | tr "," " "`
	vso_sc_options=`$GREP -w $lsc_group $logfile | $GREP $vso_prot | \
	    eval sed -e 's/${vso_prot}=\(//' -e 's/$lsc_group//' -e 's/\)//' \
	    -e 's/\"//g'`
	if [ "$vso_sc_options" ]
	then
		#
		# For each option that is set to true in sc_otions check
		# for a corresponding option in the share output.
		#
		for vso_sc_opt in $vso_sc_options
		do
			echo $vso_sc_opt | $GREP "true" > /dev/null 2>&1
			if [ $? -eq 0 ]
			then
				vso_sc_opt=`echo $vso_sc_opt | \
				    $AWK -F"=" '{print $1}'`
				echo $vso_lsc_options | \
				    $GREP $vso_sc_opt > /dev/null 2>&1
				POS_result $? \
				    "$vso_sc_opt in $vso_lsc_options list"
			else
				echo $vso_lsc_options | $GREP $vso_sc_opt >\
				    /dev/null 2>&1
				POS_result $? \
				    "$vso_sc_opt in $vso_lsc_options list"
			fi
		done
		#
		# For each option that is in the share list make sure there
		# is a true option setting in the sc_options list.
		#
		for vso_lsc_opt in $vso_lsc_options
		do
			vso_lsc_opt_found=1
			for vso_sc_opt in $vso_sc_options
			do
				echo $vso_sc_opt | $GREP $vso_lsc_opt > \
				    /dev/null 2>&1
				if [ $? -eq 0 ]
				then
					echo $vso_lsc_opt | $GREP "=" > \
					    /dev/null 2>&1
					if [ $? -eq 0 ]
					then
						vso_lsc_opt_found=0
						POS_result $vso_lsc_opt_found \
						    "$vso_lsc_opt in $vso_sc_options"
					else
						echo $vso_sc_opt | $GREP \
						    "true" > /dev/null 2>&1
						POS_result $? \
						    "$vso_lsc_opt true for $vsc_sc_opt"
					fi
					break
				fi
			done
		done
	else
		if [ "$vso_lsc_options" != "rw" ]
		then
			tet_infoline "FAIL - Legacy share shows options "\
			    "$vso_lsc_options and sharemgr shows no options"
			tet_result FAIL
		fi
	fi
}

#
# NAME
#	build_group_to_share
#
# DESCRIPTION
#	builds a group to share array list based on the current
#	configuration.
#
function build_group_to_share {
	unset gts_lastelement
	unset ga_lastelement
	unset group_arry
	share_out=$1

	gts_lastelement=0
	ga_lastelement=0
	while IFS="\n" read line
	do
		if [ "${line%${line#?}}" != "	" ]
		then
			cur_group=${line}
			eval set -A group_arry ${group_arry[*]} $cur_group
			ga_lastelement=`$EXPR $ga_lastelement + 1`
			eval unset gts_${cur_group}
		else
			eval set -A gts_${cur_group} \${gts_${cur_group}[*]} \${line}
			gts_lastelement=`$EXPR $gts_lastelement + 1`
		fi
	done < $share_out
}

#
# NAME
#	verify_ctl_properties
#
# DESCRIPTION
#	Verify the given (if none given, all) properties for the protocol
#	specified (if no protocol given the use the default protocol).
#
#
function verify_ctl_properties {
	if [ "$1" = "NEG" ]
	then
		vcp_pos_neg=$1
		shift
	else
		vcp_pos_neg="POS"
		if [ "$1" = "POS" ]
		then
			shift
		fi
	fi

	if [ "$1" = "-P" ]
	then
		vcp_protocol=$2
		shift 2
	else
		vcp_protocol=$default_protocols
	fi

	if [ "$1" ]
	then
		vcp_properties="$*"
	else
		eval vcp_properites=\"\$CTLPROPS_${vcp_protocol}\"
	fi

	for vcp_chk_prop in $vcp_properties
	do
		eval vcp_chk_prop_val=\$CTLPROP_${vcp_protocol}_${vcp_chk_prop}
		get_ctl $vcp_chk_prop -P $vcp_protocol
		vcp_CHK_PROP_VAL=`cat $logfile | $AWK -F'=' '{print $2}'`

		if [ "$vcp_chk_prop_val" != "$vcp_CHK_PROP_VAL" ]
		then
			tet_infoline "FAIL - Set value for $vcp_chk_prop of"\
			    "$vcp_CHK_PROP_VAL does not equal expected value "\
			    "of $vcp_chk_prop_val"
			tet_result FAIL
		else
			if [ "$verbose" = "TRUE" ]
			then
				tet_infoline "PASS - Set value for "\
				    "$vcp_chk_prop of $vcp_CHK_PROP_VAL "\
				    "does equals expected value of "\
				    "$vcp_chk_prop_val"
			fi
		fi
	done
}
