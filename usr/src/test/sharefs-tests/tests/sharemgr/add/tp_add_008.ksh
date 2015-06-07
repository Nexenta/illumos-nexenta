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
# ident	"@(#)tp_add_008.ksh	1.3	08/06/12 SMI"
#

#
# add-share test case
#

#__stc_assertion_start
#
#ID: add008
#
#DESCRIPTION:
#
#	Attempt to add the same share to multiple groups.
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options.
#               - Create second share group with nfs protocol specified.
#       Test:
#		- Add share to first share group.
#		- Attempt to add the same share to a second share group.
#		  The operation should fail.
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
function add008 {
	tet_result PASS
	tc_id="add008"
	tc_desc="Attempt to add the same share to multiple groups"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	# Create share group
	create test_group_1
	create test_group_2 -P nfs

	#
	# Add temporary shares to the group
	#
	add_share POS test_group_1 "" ${MP[0]}
	# Dry run of second add that should fail
	add_share NEG test_group_2 "-n" ${MP[0]}
	# Real thing
	add_share NEG test_group_2 "" ${MP[0]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
