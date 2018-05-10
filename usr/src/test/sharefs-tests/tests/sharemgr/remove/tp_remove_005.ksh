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
# ident	"@(#)tp_remove_005.ksh	1.3	08/06/11 SMI"
#

#
# remove test case
#

#__stc_assertion_start
#
#ID: remove005
#
#DESCRIPTION:
#
#	Attempt to remove a non-existent share from a valid share group.
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with default options.
#		- Add share to first share group.
#		- Verify (by new and legacy* methods) that the share is indeed
#		  shared and has the default options.
#	Test:
#		- Attempt to remove a non-existent share (provide a bogus path
#		  name) from the share group.  The operation should fail.
#		- Verify (by new and legacy* methods) that the share in the
#		  first group is still shared and has the default options.
#	Cleanup:
#		- Remove any shares created.
#		- Forcibly delete all share groups.
#
#	STRATEGY_NOTES:
#		- * Legacy methods will be used so long as they are still
#		  present.
#		- Return status is checked for all share-related commands
#		  executed.
#		- For all commands that modify the share configuration, the
#		  associated reporting commands will be executed and output
#		  checked to verify the expected changes have occurred.
#
#KEYWORDS:
#
#	move-share
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
function remove005 {
	tet_result PASS
	tc_id="remove005"
	tc_desc="Attempt to remove a non-existent share from a valid group"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate initial share group
	create test_group_1
	add_share POS test_group_1 "" ${MP[0]}
	#
	# Perform remove operation.  (Dry run first then real thing.)
	#
	remove_share NEG test_group_1 "-n" bogus_path
	remove_share NEG test_group_1 "" bogus_path
	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id NEG
}