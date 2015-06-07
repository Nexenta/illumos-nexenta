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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tp_delete_002.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete002
#
#DESCRIPTION:
#
#       Forcefully deleting a group with a share leaves the share
#	in an unmountable state.
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options.
#		- Add a share to the group
#       Test:
#               - Delete share group with the -f option
#               - Verify that the share group no longer exists.
#		- Verify that the share mount point can be unmounted.
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#               - * Legacy methods will be used so long as they are still
#                 present.
#               - Return status is checked for all share-related commands
#                 executed.
#               - For all commands that modify the share configuration, the
#                 associated reporting commands will be executed and output
#                 checked to verify the expected changes have occurred.
#		- This test if fails will leave the mount point in a bad state
#		  an care needs to be taken to clean up this state, by 
#		  removing and reading the mount point and remounting the
#		  device.
#
#KEYWORDS:
#
#       delete
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
function delete002 {
	tet_result PASS
	tc_id="delete002"
	tc_desc="Forcibly  a group with a share"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group
	create ${TG[0]}
	# Add the share to the group
	add_share POS ${TG[0]} "" ${MP[0]}
	# Forcibly delete the group.  (Dry run then for real.)
	delete POS ${TG[0]} -n -f
	delete POS ${TG[0]} "-f"
	# Check that umount succeeds
	if [ $report_only ]
	then
		return
	fi

	TMPDEV=`grep ${MP[0]} /etc/mnttab | awk '{print $1}'`
	tet_infoline " - umount ${MP[0]}"
	umount ${MP[0]}
	if [ $? -ne 0 ]
	then
		tet_infoline "Must forcibly umount the mountpoint"
		reset_paths
		tet_result FAIL
	else
		# remount the mount point
		echo $TMPDEV | grep dev | grep dsk > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			tet_infoline " - mount $TMPDEV ${MP[0]}"
			mount $TMPDEV ${MP[0]}
		else
			tet_infoline " - zfs mount $TMPDEV"
			zfs mount $TMPDEV
		fi
		if [ $? -ne 0 ]
		then
			tet_infoline "Remount failed"
			reset_paths
			tet_result FAIL
		fi
	fi
	#
	# Cleanup
	#
	report_cmds $tc_id POS
}
