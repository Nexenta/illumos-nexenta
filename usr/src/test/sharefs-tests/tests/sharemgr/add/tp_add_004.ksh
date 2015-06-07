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
# ident	"@(#)tp_add_004.ksh	1.3	08/06/12 SMI"
#

#
# add-share test case
#

#__stc_assertion_start
#
#ID: add004
#
#DESCRIPTION:
#
#	Add mix of permenent and temporary shares
#
#STRATEGY:
#
#       Setup:
#               - Create share group with nfs protocol and default options.
#       Test:
#		- Add one permanent share.
#		- Add one temporary share.
#		- Add a second permanent share.
#		- Add a second temporary share.
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
#AUTHOR: andre.molyneux@sun.com
#
#REVIEWERS: TBD
#
#TEST_AUTOMATION_LEVEL: automated
#
#CODING_STATUS: COMPLETE
#
#__stc_assertion_end
function add004 {
	tet_result PASS
	tc_id="add004"
	tc_desc="Add mix of permanent and temporary shares"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group
	create test_group_1 -P nfs

	#
	# Add temporary shares to the group
	#
	# Dry run
	add_share POS test_group_1 "-n" ${MP[0]}
	add_share POS test_group_1 "-n -t" ${MP[1]}
	add_share POS test_group_1 "-n" ${MP[2]}
	add_share POS test_group_1 "-n -t" ${MP[3]}
	# Real thing
	add_share POS test_group_1 "" ${MP[0]}
	add_share POS test_group_1 -t ${MP[1]}
	add_share POS test_group_1 "" ${MP[2]}
	add_share POS test_group_1 -t ${MP[3]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
