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
# ident	"@(#)tp_disable_004.ksh	1.3	08/06/11 SMI"
#

#
# Disable test case
#

#__stc_assertion_start
#
#ID: disable004
#
#DESCRIPTION:
#
#	Disable/enable specific multiple groups with multiple shares each
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with default properties.
#		- Populate first group with one share.
#		- Create second (control) share group with default properties.
#		- Populate second group with one share.
#	Test:
#		- Disable first group.
#		- Verify that second group is still enabled.
#		- Enable first group.
#		- Verify that second group is still enabled.
#	Cleanup:
#		- Delete any shares created
#		- Delete any groups created
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
#	disable/enable
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
function disable004 {
	tet_result PASS
	tc_id="disable004"
	tc_desc="Disable/enable specific multiple groups with multiple shares each"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate share groups we will disable/enable
	create ${TG[0]}
	add_share POS ${TG[0]} "" ${MP[0]}
	add_share POS ${TG[0]} "" ${MP[1]}
	create ${TG[1]}
	add_share POS ${TG[1]} "" ${MP[2]}
	add_share POS ${TG[1]} "" ${MP[3]}

	#
	# Create and populate 'control' share group that will not be
	# enabled/disabled.  NOTE:  If this test case is enabled, the add_share
	# command below will fail because ${MP[2]} has already been added to
	# ${TG[1]}.
	#
	create ${TG[2]}
	add_share POS ${TG[2]} "" ${MP[4]}

	#
	# Perform disable/enable operations
	#
	# Disable ${TG[0]} & ${TG[1]} and verify the states have
	# changed.  (Dry run first then the real thing.)
	disable POS "-n" ${TG[0]} ${TG[1]}
	disable POS "" ${TG[0]} ${TG[1]}

	# Verify that ${TG[2]} is still enabled
	verify_group_state ${TG[2]}

	# Enable test groups 1 & 2 and verify the states have changed.  (Dry
	# run first then the real thing.)
	enable POS "-n" ${TG[0]} ${TG[1]}
	enable POS "" ${TG[0]} ${TG[1]}

	# Verify that ${TG[2]} is still enabled
	verify_group_state ${TG[2]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
