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
# ident	"@(#)tp_add_002.ksh	1.3	08/06/12 SMI"
#

#
# add-share test case
#

#__stc_assertion_start
#
#ID: add002
#
#DESCRIPTION:
#
#	Add a share with the group name listed first
#
#STRATEGY:
#
#       Setup:
#               - Create two share groups with default options.
#       Test:
#		- add the share with the group specified first
#		- verify that the share did not occur, and a core
#		  file was not produced.
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#               - Return status is checked for all share-related commands
#                 executed.
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
#__stc_assertion_end
function add002 {
	tet_result PASS
	tc_id="add002"
	tc_desc="Add a share with the group name listed first"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	# Create share group
	create test_group_1

	#
	# Set as_partial_cmd to the group and call add_share without
	# the group.
	# or call add_share with the group as the option arguement.
	#
	as_partial_cmd="test_group_1"
	# Dry run
	add_share NEG "" "-n" ${MP[0]}
	# Real thing
	add_share NEG "" "" ${MP[0]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
