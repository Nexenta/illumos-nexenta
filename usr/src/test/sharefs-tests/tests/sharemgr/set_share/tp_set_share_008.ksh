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
# ident	"@(#)tp_set_share_008.ksh	1.4	08/06/11 SMI"
#

#
# sharemgr set_share test case
#

#__stc_assertion_start
#
#ID: set_share008
#
#DESCRIPTION:
#
#	Verify changes to one share don't affect another.
#
#STRATEGY:
#
#	Setup:
#		- Create share group with default options.
#		- Add share to share group with resource name and description
#		  specified.
#		- Add second share to share group with resource name and
#		  description specified.
#		- Verify (by new and legacy* methods) that the shares are
#		  indeed shared and have the expected resource names and
#		  descriptions.
#	Test:
#		- Clear resource name and description for the first share.
#		- Verify (by new and legacy* methods) that both shares are
#		  still shared and have the expected resource names and
#		  descriptions.
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
function set_share008 {
	tet_result PASS
	tc_id="set_share008"
	tc_desc="Verify changes to one share don't affect another"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate initial share group
	create test_group_1 -P nfs
	add_share POS test_group_1 "-d \"desc 1\" -r rsrc_1" ${MP[0]}
	add_share POS test_group_1 "-d \"desc 2\" -r init_rsrc" ${MP[2]}
	#
	# Clear resource name and description for first share.  (Dry run then
	# the real thing.)
	#
	set_share POS ${MP[0]} "-n -r \"\" -d \"\""
	set_share POS ${MP[0]} "-r \"\" -d \"\""
	#
	# Verify second share is unaffected
	#
	verify_share POS ${MP[2]}
	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
