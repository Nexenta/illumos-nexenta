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
# ident	"@(#)tp_zones_001.ksh	1.3	08/06/11 SMI"
#

#
# zones test case
#

#__stc_assertion_start
#
#ID: zone_disable001
#
#DESCRIPTION:
#
#	Attempt disable/enable from non-global zone.
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
#		- Attempt to disable the first test group from non-global
#		  zone.  The attempt should fail.
#		- Verify both groups are still enabled.
#		- Disable the first test group from global zone.
#		- Verify the second test group is still enabled.
#		- Attempt to enable the first test group from non-global
#		  zone.  The attempt should fail.
#		- Verify the first test group is still disabled.
#		- Enable the first test group from global zone.
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
function zone_disable001 {
	tet_result PASS
	tc_id="zone_disable001"
	tc_desc="Attempt disable/enable fron non-global zone"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate first share group
	# 
	create test_group_1
	add_share POS test_group_1 "" ${MP[0]}
	# Create and populate 'control' share group that will not be 
	# enabled/disabled
	create test_group_2
	add_share POS test_group_2 "" ${MP[1]}
	#
	# Perform disable/enable operations
	#
	# Attempt disable command from non-global zone
	cmd_prefix="zlogin testzone1 "
	disable NEG "" test_group_1
	# Verify that test_group_1 is still enabled
	verify_group_state test_group_1
	# Verify that test_group_2 is still enabled
	verify_group_state test_group_2
	# Execute disable command from global zone
	disable POS "" test_group_1
	# Verify that test_group_2 is still enabled
	verify_group_state test_group_2
	# Attempt enable command from non-global zone
	cmd_prefix="zlogin testzone1 "
	enable NEG "" test_group_1
	# Verify that test_group_1 is still disabled
	verify_group_state test_group_1
	# Verify that test_group_2 is still enabled
	verify_group_state test_group_2
	# Execute enable command with sufficient privileges
	enable POS "" test_group_1
	# Verify that test_group_2 is still enabled
	verify_group_state test_group_2
	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
