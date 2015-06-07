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
# ident	"@(#)tp_show_002.ksh	1.3	08/06/12 SMI"
#

#
# sharemgr show test case
#

#__stc_assertion_start
#
#ID: show002
#
#DESCRIPTION:
#
#	Execute 'show' command for multiple populated groups at one time.
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with nfs protocol.
#		- Create second share group with no protocol specified.
#	Test:
#		- Execute single 'show' command for multiple groups.
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
#	show
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
function show002 {
	tet_result PASS
	tc_id="show002"
	tc_desc="Execute 'show' command for multiple populated groups at one time"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol
	create test_group_1 -P nfs
	create test_group_2

	#
	# Populate groups
	#
	add_share POS test_group_1 -t ${MP[0]}
	add_share POS test_group_2 -t ${MP[2]}

	#
	# Set and then clear the aclok property
	#
	show POS "test_group_1 test_group_2 zfs"

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
