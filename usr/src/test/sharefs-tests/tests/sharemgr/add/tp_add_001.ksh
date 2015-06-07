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
# ident	"@(#)tp_add_001.ksh	1.3	08/06/12 SMI"
#

#
# add-share test case
#

#__stc_assertion_start
#
#ID: add001
#
#DESCRIPTION:
#
#	Add a share without a group name on the command line
#
#STRATEGY:
#
#       Setup:
#               - Create two share groups with default options.
#       Test:
#		- add the share without a group 
#               - Verify that the share did not add to a group
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
#       add-share
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
#__stc_asserti_end
function add001 {
	tet_result PASS
	tc_id="add001"
	tc_desc="Add a share without providing a group"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	# Create share group
	create test_group_1
	create test_group_2

	#
	# Add the share without the group
	#
	# Dry run
	add_share NEG "" "-n" ${MP[0]}
	# For real
	add_share NEG "" "" ${MP[0]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
