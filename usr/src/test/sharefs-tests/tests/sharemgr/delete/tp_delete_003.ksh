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
# ident	"@(#)tp_delete_003.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete003
#
#DESCRIPTION:
#
#       Attempt to remove a group that has already been removed.
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options.
#       Test:
#               - Delete share group.
#               - Verify that the share group no longer exists.
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
#
#KEYWORDS:
#
#       delete NEG
#
#TESTABILITY: explicit
#
#AUTHOR: andre.molyneux@sun.com
#
#REVIEWERS: TBD
#
#TEST_AUTOMATION_LEVEL: automated
#
#CODING_STATUS: COMPLETE
#
#__stc_assertion_end
function delete003 {
	tet_result PASS
	tc_id="delete003"
	tc_desc="Attempt to remove a group that has already been removed"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group
	create ${TG[0]}
	#
	# Delete share group
	#
	delete POS ${TG[0]}
	#
	# Attempt to delete the share group again.  This should fail.  Execute
	# the 'sharemgr delete' directly rather than calling the test suite
	# delete function as we don't want the verification steps that function
	# calls, which would expect the group to be present after the delete
	# fails.
	#
	# First the dry run
	tet_infoline "* Dry run - Delete share group ($d_group) - NEG"
	cmd="$SHAREMGR delete -n ${TG[0]}"
	tet_infoline "  - $cmd"
	$cmd >/dev/null 2>&1
	retval=$?
	if [ $retval -eq 0 ]
	then
		NEG_result $retval 1 "$cmd"
	fi
	# Now the real thing
	tet_infoline "* Delete share group ($d_group) - NEG"
	cmd="$SHAREMGR delete ${TG[0]}"
	tet_infoline "  - $cmd"
	$cmd >/dev/null 2>&1
	retval=$?
	if [ $retval -eq 0 ]
	then
		NEG_result $retval 1 "$cmd"
	fi
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
