#! /usr/bin/ksh -p
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
# ident	"@(#)share_reboot.ksh	1.4	09/08/16 SMI"
#

#
# reboot test cases
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1"
ic1="reboot001"

#__stc_assertion_start
#
#ID: reboot001
#
#DESCRIPTION:
#
#       Check if shares and groups can survive system reboot.
#
#STRATEGY:
#
#       Setup:
#               - Create share groups and shares.
#       Test:
#               - Save needed information and reboot system, and
#                 make sure the groups and share are still there.
#       Cleanup:
#               - Make sure to recover ufs test file systems.
#
#       STRATEGY_NOTES:
#               - To complete this reboot test and obtain its final
#                 result, you must run 'reboot' scenario again after
#                 system comes back, ie. run the same command for
#                 two times:
#                   run_test -F <path-to-config-file> share reboot
#
#KEYWORDS:
#
#       share after reboot
#
#TESTABILITY: explicit
#
#AUTHOR: sean.wilcox@sun.com
#
#REVIEWERS: TBD
#
#TEST_AUTOMATION_LEVEL: automated
#
#CODING_STATUS: COMPLETE
#
#__stc_assertion_end
function reboot001 {
	tet_result PASS
	tc_id="reboot001"
	tc_desc="Create several shares and groups and confirm they survive a reboot"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	if [[ ! -f $SHR_TMPDIR/sharemgr_reboot ]]; then
		#
		# Setup
		#
		create ${TG[0]}
		add_share POS ${TG[0]} "" ${MP[0]}

		create ${TG[1]}
		add_share POS ${TG[1]} "" ${MP[1]}
		disable "" ${TG[1]}
		#
		# XXXX - Add the temporary share and confirm that it is
		# removed upon reboot.  This can be done once the updates
		# to the add_share for temporary shares is worked out.
		#
		# add_share POS ${TG[1]} "-t" ${MP[2]}
		#
		# Need to store off information for next round of
		# tests when the reboot comes back up.
		#
		set | grep "ShTst" > $SHR_TMPDIR/sharemgr_reboot.env
		set | grep "EXP_STATE_" >> $SHR_TMPDIR/sharemgr_reboot.env
		set | grep "SHARES_" >> $SHR_TMPDIR/sharemgr_reboot.env
		echo "real_groups=\"$real_groups\"" >> \
					$SHR_TMPDIR/sharemgr_reboot.env
		echo "${TG[0]}:${MP[0]}" > $SHR_TMPDIR/sharemgr_reboot
		echo "${TG[1]}:${MP[1]}" >> $SHR_TMPDIR/sharemgr_reboot
		#
		# Make sure ufs file systems are setup to persist across
		# a reboot.
		#
		addufstovfstab
		(( $? != 0 )) && return
		tet_infoline "Rebooting...."
		reboot
	else
		# need to remount the ufs manually after reboot
		typeset -i need_remnt=0
		# check if it is UFS as expected, as it will become zfs if
		# it was unmounted on zfs boot system
		df -F ufs ${MP[0]} > $SHR_TMPDIR/mp.df.$$ 2>&1
		if (( $? != 0 )); then
			need_remnt=1
		else
			grep ${MP[0]} $SHR_TMPDIR/mp.df.$$ > \
				$SHR_TMPDIR/mp.grep.$$
			if (( $? != 0 )); then
				need_remnt=1
			else
				# check if the device to mount is our expected
				typeset expdev=$(grep ${MP[0]} /etc/vfstab \
							| awk '{print $1}')
				typeset curdev=$(tail -1 $SHR_TMPDIR/mp.grep.$$ \
						| awk -F\( '{print $2}' \
						| awk -F\) '{print $1}')
				[[ $curdev != $expdev ]] && need_remnt=1
			fi
			rm -f $SHR_TMPDIR/mp.grep.$$
		fi
		rm -f $SHR_TMPDIR/mp.df.$$
		if (( $need_remnt != 0 )); then
			typeset ERRMSG="The required test ufs ${MP[0]} "
			ERRMSG="${ERRMSG}and/or ${MP[2]} cannot be remounted\n"
			ERRMSG="${ERRMSG}after reboot, which may cause other "
			ERRMSG="${ERRMSG}tests to fail, so it should be safer\n"
			ERRMSG="${ERRMSG}to unconfigure it and do cleanup "
			ERRMSG="${ERRMSG}manually if needed."
			# try to remount it based on the entry logged in vfstab,
			# if it failed, we need to refresh the zfs pool for
			# making its volumes can be used and mounted as before.
			mount ${MP[2]} > $SHR_TMPDIR/mp.mnt.$$ 2>&1
			if (( $? == 0 )); then
				mount -O ${MP[0]} > $SHR_TMPDIR/mp.mnt.$$ 2>&1
				if (( $? != 0 )); then
				    cti_reportfile $SHR_TMPDIR/mp.mnt.$$ \
				    "WARNING: failed to remount ufs ${MP[0]}"
				    tet_infoline "$ERRMSG"
				fi
			else
				typeset zfspool="share_pool"
				[[ -n $ZFSPOOL ]] && zfspool=$ZFSPOOL
				zpool export $zfspool > \
						$SHR_TMPDIR/zp.ref.$$ 2>&1
				typeset -i do_remnt=$?
				zpool import -d $TESTDIR $zfspool >> \
						$SHR_TMPDIR/zp.ref.$$ 2>&1
				do_remnt=$((do_remnt + $?))

				if (( $do_remnt == 0 )); then
				    mount ${MP[2]} > $SHR_TMPDIR/mp.mnt.$$ 2>&1
				    if (( $? != 0 )); then
					cti_reportfile $SHR_TMPDIR/mp.mnt.$$ \
					"WARNING: failed to remount ufs ${MP[2]}"
					tet_infoline "$ERRMSG"
				    fi
				    mount -O ${MP[0]} > $SHR_TMPDIR/mp.mnt.$$ 2>&1
				    if (( $? != 0 )); then
					cti_reportfile $SHR_TMPDIR/mp.mnt.$$ \
					"WARNING: failed to remount ufs ${MP[0]}"
					tet_infoline "$ERRMSG"
				    fi
				else
				    cti_reportfile $SHR_TMPDIR/zp.ref.$$ \
				    "WARNING: failed to refresh zpool $ZFSPOOL"
				    tet_infoline "$ERRMSG"
				fi
				rm -f $SHR_TMPDIR/zp.ref.$$
			fi
			rm -f $SHR_TMPDIR/mp.mnt.$$
		fi

		#
		# Use the sharemgr_reboot bits to confirm all
		# shares are still shared.
		#
		tet_infoline "Verify the groups ${TG[0]} and ${TG[1]} are in the"
		eval ES_tmp0=\"\$EXP_STATE_${TG[0]}\"
		eval ES_tmp1=\"\$EXP_STATE_${TG[1]}\"
		tet_infoline "correct state ${ES_tmp0} and ${ES_tmp1}"
		verify_groups ${TG[0]} ${TG[1]}
		tet_infoline "Verify the ${MP[0]} belongs to ${TG[0]}"
		verify_share ${MP[0]}
		tet_infoline "Verify the ${MP[1]} belongs to ${TG[1]}"
		verify_share ${MP[1]}
		
		#
		# Cleanup
		#
		while read line; do
			GROUPS="$GROUPS `echo $line | awk -F":" '{print $1}'`"
		done < $SHR_TMPDIR/sharemgr_reboot
		rm $SHR_TMPDIR/sharemgr_reboot
		rm $SHR_TMPDIR/sharemgr_reboot.env
		mv /etc/vfstab.sharemgr_tests.orig /etc/vfstab
		(( $? != 0 )) && tet_infoline \
			"WARNING : Unable to restore the original vfstab"
		delete_all_test_groups
		report_cmds $tc_id POS
	fi
}

function startup
{
	tet_infoline "Checking environment and runability"
	if [[ ! -f $SHR_TMPDIR/sharemgr_reboot ]]; then
		tet_infoline "Calling share_startup...."
		share_startup
		$CAT << __EOF__ > /etc/rc3.d/S99tetrestart
#!/bin/ksh

TET_ROOT=$TET_ROOT
TET_SUITE_ROOT=$TET_SUITE_ROOT

export TET_ROOT TET_SUITE_ROOT

${TET_ROOT}/bin/tcc -e share reboot
__EOF__
		chmod 755 /etc/rc3.d/S99tetrestart
	else
		tet_infoline "Calling minimal share_startup...."
		share_startup True
		#
		# Need to reload some environment variables to
		# use.
		#
		. $SHR_TMPDIR/sharemgr_reboot.env
		rm /etc/rc3.d/S99tetrestart
	fi
}

function cleanup
{
	tet_infoline "Cleaning up after tests"
	if [[ -f $SHR_TMPDIR/sharemgr_reboot ]]; then
		#
		# Should not get here when the file exists.
		# Need to do some extra cleanup.
		#
		# Reset the GROUPS variable based on sharemgr_reboot
		#
		while read line; do
			GROUPS="$GROUPS `echo $line | awk -F":" '{print $1}'`"
		done < $SHR_TMPDIR/sharemgr_reboot
		rm $SHR_TMPDIR/sharemgr_reboot
		tet_infoline "cleanup : GROUPS = $GROUPS"
		delete_all_test_groups
	fi
	share_cleanup
}

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
