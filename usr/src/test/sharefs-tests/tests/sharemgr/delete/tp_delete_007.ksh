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
# ident	"@(#)tp_delete_007.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete007
#
#DESCRIPTION:
#
#	Remove protocol for a share group
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options and protocol set.
#       Test:
#               - Delete share group's protocol
#               - Verify that share group's protocol was removed.
#       Cleanup:
#		- Delete any groups created
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
#       delete
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
function delete007 {
	tet_result PASS
	tc_id="delete007"
	tc_desc="Remove protocol for a share group"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group
	create ${TG[0]}
	#
	# Delete share group.  (Dry run then the real thing.)
	#
	delete POS ${TG[0]} -P nfs -n
	delete POS ${TG[0]} -P nfs
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
