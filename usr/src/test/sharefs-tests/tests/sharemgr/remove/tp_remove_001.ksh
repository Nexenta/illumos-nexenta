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
# ident	"@(#)tp_remove_001.ksh	1.3	08/06/12 SMI"
#

#
# remove test case
#

#__stc_assertion_start
#
#ID: remove001
#
#DESCRIPTION:
#
#	Remove the only share from an enabled share group.
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with default options.
#		- Add share to first share group.
#		- Verify (by new and legacy* methods) that the share is indeed
#		  shared and has the default options.
#		- Create second share group with default options.
#		- Add share to second group.
#	Test:
#		- Remove share from the first share group.
#		- Verify (by new and legacy* methods) that the share is no
#		  longer shared.
#	Cleanup:
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
function remove001 
{
	tet_result PASS
	tc_id="remove001"
	tc_desc="Remove the only share from an enabled group."
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate initial share group
	create test_group_1
	add_share test_group_1 "" ${MP[0]}
	# Create and populate second share group
	create test_group_2
	add_share test_group_2 "" ${MP[1]}
	#
	# Perform remove operation.  (Dry run first then real thing.)
	#
	remove_share POS test_group_1 "-n" ${MP[0]}
	remove_share POS test_group_1 "" ${MP[0]}
	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
