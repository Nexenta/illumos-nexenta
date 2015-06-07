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
# ident	"@(#)tp_move_004.ksh	1.3	08/06/11 SMI"
#

#
# move-share test case
#

#__stc_assertion_start
#
#ID: move004
#
#DESCRIPTION:
#
#	Move multiple shares from multiple share groups to a new share group
#	that has differing options from the source groups.
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with default options.
#		- Add multiple shares to the first share group.
#		- Verify (by new and legacy* methods) that the shares are
#		  indeed shared and have the default options.
#		- Create second share group with options differing from the
#		  first share group.
#		- Add multiple shares to the second share group.
#		- Verify (by new and legacy* methods) that the shares are
#		  indeed shared and have the options of the second share group.
#		- Create third share group with options differing from either
#		  of the other share groups.
#	Test:
#		- Move some of the shares from first two groups to third group.
#		- Verify (by new and legacy* methods) that the moved shares are
#		  still shared and now have the options of the third share
#		  group.
#		- Verify (by new and legacy* methods) that the shares that were
#		  not moved are still shared and retain the same options as
#		  before.
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
function move004 {
	tet_result PASS
	tc_id="move004"
	tc_desc="Move multiple shares from different groups to a new group with different options"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate initial share group
	create test_group_1
	add_share POS test_group_1 "" ${MP[1]}
	add_share POS test_group_1 "" ${MP[2]}
	# Create and populate second share group
	create test_group_2 -P nfs -p public=true -p nosub=true
	add_share POS test_group_2 "" ${MP[3]}
	add_share POS test_group_2 "" ${MP[4]}
	# Create third test group
	create test_group_3 -P nfs -p nosuid=true -p anon=12345 \
	    -p index=test_file_aaa
	#
	# Perform move operation.  (Dry run first then the real thing.)
	#
	move_share POS test_group_3 "-n" ${MP[1]} ${MP[3]}
	move_share POS test_group_3 "" ${MP[1]} ${MP[3]}
	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
