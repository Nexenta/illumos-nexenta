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
# ident	"@(#)utils_common.ksh	1.9	09/08/16 SMI"
#

#
# This file contains common functions that are used to manage the
# test cases and other functionality in the test suite that would
# be a utility type function.  The start and cleanup functions for
# example.
#

#
# NAME
#	clean_logs
#
# DESCRIPTION
#	Clean up the default known log files.
#
function clean_logs {
	if [ $s_log ]
	then
		$RM -f ${s_log}* > /dev/null 2>&1
	fi
	if [ $l_log ]
	then
		$RM -f ${l_log}* > /dev/null 2>&1
	fi
	if [ $dfs_log ]
	then
		$RM -f ${dfs_log}* > /dev/null 2>&1
	fi
}

#
# NAME
#	cancel_tests
#
# DESCRIPTION
#	Cancel all the test purposes
#
function cancel_tests {
	for ct_TestCase in $iclist
	do
		eval ct_TestPurp=\${$ct_TestCase}
		tet_infoline "tet_delete $ct_TestPurp"
		tet_delete $ct_TestPurp \
		    "Canceling all tests : see previous log entries"
	done
}

#
# NAME
#	build_fs
#
# DESCRIPTION
# 	Build the file systems and mount file systems according to 
# 	configuration parameters.
#	- Create all the directories that are needed.
#	- Check the devices are not in use
#	- Create the needed file systems (ufs and/or zfs)
#	- Mount the file systems
#
function build_fs {
	typeset -i i=0
	tet_infoline "create the needed directories"
	for i in 0 1 2 3 4
	do
		if [ -d ${MP[$i]} ]
		then
			tet_infoline "Test ${MP[$i]} directory already exists "
			cancel_tests
			return 1
		fi
		$MKDIR -p ${MP[$i]}
		if [ $? -ne 0 ]
		then
			cti_result UNRESOLVED \
				"Cannot create the directory ${MP[$i]}"
			cancel_tests
			return 1
		fi
	done
	#
	# Mixed configuration, half ufs and half zfs
	# If the TESTDIR is based on UFS, create test file systems from the new
	# created zpool, otherwise, create all file systems from the existing zpool
	#
	typeset zfspool="share_pool"
	[[ -n $ZFSPOOL ]] && zfspool=$ZFSPOOL
	for i in 0 2; do
		create_ufs_fs $zfspool ${MP[$i]} 256m
		if (( $? != 0 )); then
			cti_result UNRESOLVED "failed to create ufs<${MP[$i]}>"
			cancel_tests
			return 1
		fi
	done
	i=1
	for size in "512m" "1g"; do
		create_zfs_fs $zfspool ${MP[$i]} $size
		if (( $? != 0 )); then
			cti_result UNRESOLVED "failed to create zfs<${MP[$i]}>"
			cancel_tests
			return 1
		fi
		i=$((i + 2))
	done

	return 0
}

#
# NAME
#	share_startup
#
# DESCRIPTION
#	The common startup function used at the beginning of each 
#	sub-suite.  
#	- Unset all the common variables.
#	- Verify that the sharemgr binary exists
#	- Verify that the legacy share tests need to be done
#	- Setup the basic log directory and files.
#	- Check and capture current shares on the system
#	- Call build_fs to setup the file systems
#
function share_startup {
	REBOOT_STARTUP=$1

	#
	# Do not let the startup phase be trapped
	#
	TRAPCOT=0
	trap TRAPCOT=1 2 15 EXIT

	#
	# Reset the umask to 022 this is a temporary fix to the
	# bug_018.  This will be removed once the smf/rbac bits
	# are done and the tmp file will go away that is causing
	# this issue.
	#
	umask 022


	unset real_shares
	unset cmd_prefix
	unset cmd_postfix
	unset cmd_prepost_lock
	tet_infoline "checkenv for runability"
	#
	# Leaving this for now to get a bit more information
	# on the checkenv tool and figure out a bit more about
	# using it.
	#

	tet_infoline "check for the new sharemgr commands"
	if [ "$report_only" = "TRUE" -o -x /usr/sbin/sharemgr ]
	then
		SHAREMGR=/usr/sbin/sharemgr
	else
		#
		# Not installed in the default need to look in the
		# var sadm contents to see if we can find it.
		#  Otherwise ABORT
		#
		tet_infoline "Share Manager tool is not installed, aborting"
		tet_result UNSUPPORTED
		cancel_tests
		return 1
	fi

	tet_infoline "check for the new sharectl commands"
	if [ "$report_only" = "TRUE" -o -x /usr/sbin/sharectl ]
	then
		SHARECTL=/usr/sbin/sharectl
	else
		#
		# Not installed in the default need to look in the
		# var sadm contents to see if we can find it.
		#  Otherwise ABORT
		#
		tet_infoline "Share CTL tool is not installed, aborting"
		tet_result UNSUPPORTED
		cancel_tests
		return 1
	fi

	tet_infoline "check for legacy share"
	if [ "$report_only" = "TRUE" -o -x /usr/sbin/share ]
	then
		LEGACYSHARE=/usr/sbin/share
		LEGACYUNSHARE=/usr/sbin/unshare
	else
		LEGACYSHARE=""
	fi

	if [ "$report_only" = "TRUE" ]
	then
		[ ! $CMD_SUMMARY_FILE ] && \
			CMD_SUMMARY_FILE=$SHR_TMPDIR/sharemgr_cmd_summary.$$
		return 0
	fi

	if [ ! -d $LOGDIR ]
	then
		$MKDIR -p $LOGDIR
		if [ $? -ne 0 ]
		then
			#
			# No logging can occur therefor all verifications
			# are going to fail.
			#
			cancel_tests
			return 1
		fi
	else
		#
		# Clean out log files
		#
		clean_logs
	fi

	if [ "$REBOOT_STARTUP" ]
	then
		tet_infoline "Skipping the rest of startup due to reboot test."
		trap 2 15 EXIT
		return 0
	fi

	#
	# Check for test_groups in use
	#
	TGPTR=0
	TGFND=0
	while [ $TGPTR -lt ${#TG[*]} ]
	do
		sharemgr list | $GREP ${TG[$TGPTR]}
		if [ $? -eq 0 ]
		then
			tet_infoline "${TG[$TGPTR]} is listed in sharemgr list"
			tet_result UNRESOLVED
			TGFND=`$EXPR $TGFND + 1`
		else
			set -A ShTstTG ${ShTstTG[*]} ${TG[$TGPTR]}
		fi
		TGPTR=`$EXPR $TGPTR + 1`
	done
	if [ $TGFND -gt 0 ]
	then
		cancel_tests
		return 1
	fi

	#
	# Make an attempt to see if there are any groups already setup.
	#
	real_shares=`$SHAREMGR list`
	tet_infoline "real_share = $real_shares"

	#
	# Update the /etc/nfs/nfslog.conf file with entries required
	# some of the tests.
	#
	cp /etc/nfs/nfslog.conf /etc/nfs/nfslog.sharemgr_tests.orig
	echo "nfslog	de4faultdir=/var/tmp \\" >> /etc/nfs/nfslog.conf
	echo "		log=nfslog fhtable=fhtable buffer=nfslog_workbuffer" \
	    >> /etc/nfs/nfslog.conf
	echo "true	de4faultdir=/var/tmp \\" >> /etc/nfs/nfslog.conf
	echo "		log=nfslog fhtable=fhtable buffer=nfslog_workbuffer" \
	    >> /etc/nfs/nfslog.conf

	#
	# Determine the default protocols to be used during testing.
	#
	unset def_protocols
	def_protocols=`sharectl status | grep -v client | awk '{printf("%s ", $1)}'`
	tet_infoline "The default protocols are $def_protocols"

	if [ "$setup_once" != "TRUE" ]; then
		build_fs
		[ $? -ne 0 ] && return 1
	fi

	if [ $TRAPCOT -eq 1 ]
	then
		tet_infoline "trap caught in startup phase"
		#
		# Wait for children to complete and then cleanup
		#
		wait
		sleep 1
		wait
		tet_infoline "Calling share_cleanup"
		share_cleanup
		exit
	fi
	trap 2 15 EXIT

	return 0
}

#
# NAME
#	clean_fs
#
# DESCRIPTION
#	clean the file systems that were created for the tests by
#	unmounting and tearing down the zfs file systems and pools
#	that were created.
#
function clean_fs {
	for i in 0 2; do
		destroy_ufs_fs ${MP[$i]}
		(( $? != 0 )) && \
			tet_infoline "WARNING, unable to destroy ufs<${MP[$i]}>"
	done

	for i in 1 3; do
		typeset ZFSn=$(zfs list -o mountpoint,name \
			| grep "^${MP[$i]}" | awk '{print $2}')
		if (( $? == 0 )) && [[ -n $ZFSn ]]; then
			zfs destroy -r -f $ZFSn
			(( $? != 0 )) && \
				tet_infoline \
				    "WARNING, unable to destroy zfs <${MP[$i]}>"
		fi
	done

	#
	# Remove the td directories
	#
	for i in 0 1 2 3 4
	do
		if [ -d ${MP[$i]} ]
		then
			$RMDIR ${MP[$i]}
			if [ $? -ne 0 ]
			then
				#
				# The directory may have been mounted but not
				# added to the mount list due to interrupt or
				# some other error.  If the directory is in
				# this list then it is safe to attempt to 
				# unmount the directory here just to make sure
				# this is the reason for the failure.
				#
				$UMOUNT -f ${MP[$i]}
				$RMDIR ${MP[$i]}
				if [ $? -ne 0 ]
				then
				    tet_infoline "Unable to remove ${MP[$i]}"
				fi
			fi
		fi
	done

	if [ -d ${TESTDIR} ]
	then
		$RM -fr ${TESTDIR}/td*
	fi
}

#
# NAME:  delete_all_test_groups
#
# SYNOPSIS:  delete_all_test_groups
#
# DESCRIPTION:
#	This function deletes all groups created by the test suit.  As the
#	list of groups maintained by the tests ($GROUPS) may not always be
#	100% correct (if the 'sharemgr create' command misbehaves), we prefer
#	to delete all groups that the 'sharemgr list' command says are
#	configured.  Exceptions are 'default' and 'zfs' which are always
#	present on the system.
#
#	We will fall back to deleting groups based on $GROUPS only if we are
#	unable to retrieve a list of groups from 'sharemgr list'.
#
function delete_all_test_groups {

	datg_listed_groups=`$SHAREMGR list`
	if [ "$datg_listed_groups" ]
	then
		#
		# 'sharemgr list' returned a list of configured groups.  Delete
		# all of the groups in that list except 'default' and 'zfs'.
		#
		for datg_listed_group in $datg_listed_groups
		do
			#
			# Skip the groups that are always configured on the
			# system ('default' and 'zfs')
			#
			if [ "$datg_listed_group" = "default" -o \
			    "$datg_listed_group" = "zfs" ]
			then
				continue
			fi

			#
			# Skip the shares that were defined on the system
			# at the start of the tests.
			#
			echo "$real_shares" | grep "$datg_listed_group" > /dev/null
			if [ $? -eq 0 ]
			then
				continue
			fi

			#
			# Determine if the group we are about to delete is one
			# that we expected to be configured.
			#
			unset datg_expected
			for datg_indicated_group in $GROUPS
			do
				if [ "$datg_indicated_group" = \
				    "$datg_listed_group" ]
				then
					datg_expected=yes
					break
				fi
			done
			if [ ! "$datg_expected" ]
			then
				tet_infoline "WARNING: 'sharemgr list' shows" \
				    "group $datg_listed_group that the tests" \
				    "don't think is currently configured"
			fi

			#
			# Actually perform the delete
			#
			delete NO_RESULT_CHK POS $datg_listed_group -f
		done
	else
		#
		# 'sharemgr list' did not return a list of groups, which
		# probably means the command itself failed.  In that case,
		# delete any groups that the test cases had recorded as
		# having created.
		#
		for datg_group in $GROUPS
		do
			delete NO_RESULT_CHK POS $datg_group -f
		done
	fi
}

#
# NAME
#	share_cleanup
#
# DESCRIPTION
#	The common cleanup function used at the end of each 
#	sub-suite.  
#	- Call clean_fs() to clean up the file systems
#	- re-enable any shares that were originally shared on the fs.
#	- Remove any groups that might have been left over.
#	- cleanup the default logs.
#
function share_cleanup {
	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

	[ "$setup_once" != "TRUE" ] && clean_fs

	#
	# If found groups on startup make sure all groups are re-enabled.
	#
	if [ "$real_shares" ]
	then
		tet_infoline "re-enable real groups - $SHAREMGR enable -a"
		$SHAREMGR enable -a
	fi

	#
	# Remove any groups that may have been created but got
	# left behind.
	#
	for ShGrp in ${ShTstTG[*]}
	do
		$SHAREMGR list | $GREP -w $ShGrp > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			$SHAREMGR delete -f $ShGrp
		fi
	done

	#
	# Put the nfslog.conf file back in place.
	#
	mv /etc/nfs/nfslog.sharemgr_tests.orig /etc/nfs/nfslog.conf > \
	    /dev/null 2>&1

	#
	# Remove any left over log files
	#
	clean_logs
	$RM -fr ${LOGDIR} > /dev/null 2>&1
}

#
# NAME
#	reset_paths
#
# DESCRIPTION
#	Simply attempt to reset all the file system paths and delete
#	any groups, in an attempt to recover from a minor failure.
#
# 	Clear out all the mount points and then remount them.
# 	Make sure to destroy all shares that potentially are left
# 	about.
# 	Then recreate all the paths and remount all the devices.
#
# 	Any failure here will be considered catastrophic because this 
# 	function is called to put a bad state back to a good state, and
# 	we do not want to work from a bad state.
#
function reset_paths {
	delete_all_test_groups

	clean_fs

	build_fs
}

#
# NAME
#	infofile
#
# DESCRIPTION
# 	Write a file out using tet_infoline
#
function infofile {
	i_prefix=$1

	while read i_line
	do
		tet_infoline "$i_prefix$i_line"
	done < $2
}

#
# NAME
#	check_for_core
#
# DESCRIPTION
# 	Check for the potential catastrophic failure of the command based
# 	on the result.
#
function check_for_core {
	if [ $1 -ge 131 ]
	then
		tet_infoline "Core dump likely produced!"
	fi
}

#
# NAME
#	POS_results
#
# DESCRIPTION:
#	Evaluate the results of a command that was expected return status of
#	zero.  If the command did not return status of zero print a
#	failure line to the journal containing fail_string, set tet_result
#	to FAIL.
#
# $1 result to check
# $2 ($3) "FAIL string output"
# $3 ($4) "PASS string output"
#
function POS_result {
	if [ "$report_only" = "TRUE" ]
	then
		return 0
	fi

        Pr_result=$1
        #
        # Check to see if $2 was a string or a value.
        # This means that the fail string must begin with an alpha
        # character a-z or A-Z in order to be detected by the following
        # statement.
        #
        if [ `$EXPR "$2" : '.*/.*'` -gt 0 -o \
            `$EXPR "$2" : .*[a-z].*` -gt 0 -o \
            `$EXPR "$2" : .*[A-Z].*` -gt 0 ]
        then
                Pr_fail_str=$2
        else
                Pr_fail_str=$3
                shift
        fi

        if [ ! "$3" ]
        then
                Pr_pass_str=$2
        else
                Pr_pass_str=$3
        fi

        # Verify return code is 0"
        if [ $Pr_result -ne 0 ]
        then
                eval tet_infoline \"FAIL - $Pr_fail_str\"
                check_for_core $Pr_result
                if [ "$logfile" -a -f "$logfile" ]
                then
                        infofile "" $logfile
                fi
                tet_result FAIL
        elif [ "$verbose" = "True" ]
        then
                eval tet_infoline \"PASS - $Pr_pass_str\"
        fi

        return $Pr_result
}

#
# NAME
#	NEG_results
#
# DESCRIPTION:
#	Evaluate the results of a command that was expected return non-zero
#	status.  If the command did not return non-zero status print a
#	failure line to the journal containing fail_string, set tet_result
#	to FAIL.
#
# $1 result to check
# $2 ($3) "string output"
# $3 ($4) "PASS string output"
#
function NEG_result {
	if [ "$report_only" = "TRUE" ]
	then
		return
	fi

        Nr_result=$1

        #
        # Check to see if $2 was a string or a value.
        # This means that the fail string must begin with an alpha
        # character a-z or A-Z in order to be detected by the following
        # statement.
        #
        if [ `$EXPR "$2" : '.*/.*'` -gt 0 -o \
            `$EXPR "$2" : .*[a-z].*` -gt 0 -o \
            `$EXPR "$2" : .*[A-Z].*` -gt 0 ]
        then
                Nr_fail_str=$2
        else
                Nr_fail_str=$3
                shift
        fi

        if [ ! "$3" ]
        then
                Nr_pass_str=$2
        else
                Nr_pass_str=$3
        fi

        #
        # Should check for core on NEG results just to make
        # sure the reason for failure was not a core dump,
        # because core dumps are bad.
        #
        check_for_core $Nr_result
        if [ $? -ne 0 ]
        then
                tet_infoline "FAIL - command failed but possibly due to a corefile:"
                eval tet_infoline \"    $Nr_fail_str\"
                tet_result FAIL
        fi

        # Verify return code is != 0"
        if [ $Nr_result -eq 0 ]
        then
                tet_infoline "FAIL - command should have failed but succeeded:"
                eval tet_infoline \"    $Nr_fail_str\"
                tet_result FAIL
        elif [ "$verbose" = "True" ]
        then
                eval tet_infoline \"PASS - $Nr_pass_str\"
                if [ "$logfile" ]
                then
                        infofile "" $logfile
                fi
        fi

        return $Nr_result
}

#
# NAME
#	append_cmd
#
# DESCRIPTION
#	Add the specified command to the list of commands executed by this
#	test case.
#
function append_cmd {
	if [ "$cmd_list" ]
	then
		cmd_list="$cmd_list\n    $*"
	else
		cmd_list="    $*"
	fi
	#
	# Unset the prefix and post fix as these should only be
	# used for the primary command not any follow ups.
	#
	if [ ! $cmd_prepost_lock ]
	then
		unset cmd_prefix
		unset cmd_postfix
	fi
}


#
# NAME
#	report_cmds
#
# DESCRIPTION
#	Print out a summary of all commands executed by this test case.
#
function report_cmds {
	rc_tc_id="$1"           # ID for the current test case
	rc_pos_or_neg="$2"      # Is the test case positive (POS) or negative
				# (NEG)?

	if [ "$report_only" != "TRUE" -a "$verbose" != "TRUE" ]
	then
		return
	fi

	#
	# Build a brief header for this test case description.
	#
	rc_header="----- $rc_tc_id $rc_pos_or_neg Relevant commands executed -----"
	if [ "$CMD_SUMMARY_FILE" ]
	then
		# Send output to summary file
		tet_infoline "Dumping commands to $CMD_SUMMARY_FILE"
		echo $rc_header >> $CMD_SUMMARY_FILE
		echo $cmd_list >> $CMD_SUMMARY_FILE
	else
		# Send output to standard out
		tet_infoline $rc_header
		tet_infoline $cmd_list
	fi
}

#
# NAME
#	get_logfile
#
# DESCRIPTION
# 	Calculate the appropriate log file used given a specific
# 	command and option set.
#
function get_logfile {
	case $1 in
	"list") shift
		logfile=`echo ${l_log}$* | sed -e "s/ //g"`;;
	"show") shift
		logfile=`echo ${s_log}$* | sed -e "s/ //g"`;;
	"dfsshare") shift
		logfile=`echo ${dfs_log}$* | sed -e "s/ //g"`;;
	*) logf=`echo sharemgr_$* | sed -e "s/ //g" | sed -e "s/\///g"`
	   logfile=${LOGDIR}/$logf;;
	
	esac
	echo $logfile
}

#
# NAME
#	convertzfs
#
# DESCRIPTION
# 	Given a mount point convert to a zfs file system
#
function convertzfs {
	$DF $1 | $AWK -F"(" '{print $2}' | $AWK -F")" '{print $1}'
}


#
# NAME
#	add to vfstab
#
# DESCRIPTION
#	Add the currently mounted ufs file systems to the vfstab
#	to make them persistent across a reboot.
#
function addufstovfstab {
	cp /etc/vfstab /etc/vfstab.sharemgr_tests.orig
	if (( $? != 0 )); then
		tet_infoline "Unable to save original vfstab, exiting"
		tet_result UNRESOLVED
		return 1
	fi
	for i in 0 2
	do
		typeset blockdev=$(df -k ${MP[$i]} | awk '{print $1}' | \
						grep -v "^Filesystem$")
		typeset fstype=$(fstyp $blockdev)
		if [[ $fstype == ufs ]]; then
			typeset rawdev=$(echo $blockdev | \
					$SED 's/\/dsk\//\/rdsk\//')
			echo "${blockdev}\t${rawdev}\t${MP[$i]}\tufs\t" \
				"2\tno\trw" >> /etc/vfstab
		fi
	done
}

#
# NAME
#	get_ctl_default
#
# DESCRIPTION
#	Get the default value from the properties file.
#
function get_ctl_default {
	gcd_property=$1

	gcd_value=`$GREP -w $gcd_property $sharectl_orig | $AWK -F'=' '{print $2}'`

	echo $gcd_value
}


#
# NAME
#	check_ctl_support
#
# DESCRIPTION
#	Check for each property provided there is support for the property
# 	to be used.
#
# RETURN VALUE
#	Return 0 if supported and 1 if not supported.
#
function check_ctl_support {
	ccs_property=$1

	$GREP $ccs_property $sharectl_orig > /dev/null 2>&1
	return $?
}

#
# NAME
#       get_tet_result
#
# DESCRIPTION
#       Look in the TET_TMPRES file and get the current result state.
#       The current state is the last entry in this file.
#
# RETURN
#       returns a blank if file doesn't exist
#       returns the string PASS, FAIL, etc... of the current tet result
function get_tet_result {
	if [ ! -f $TET_TMPRES ]
	then
		echo ""
		return
	fi

	gtr_result=`tail -1 $TET_TMPRES`
	echo $gtr_result
}

#
# NAME
#	first
#
# DESCRIPTION
#	Return first item in a list.
#
function first {
	echo $1
}
	
#
# NAME
#	rest
#
# DESCRIPTION
#	Return all but the first item in a list.
#
function rest {
	if [ "$1" ]
	then
		shift
	fi

	echo "$@"
}
