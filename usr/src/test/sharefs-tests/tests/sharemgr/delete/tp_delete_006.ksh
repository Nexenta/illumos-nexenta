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
# ident	"@(#)tp_delete_006.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete006
#
#DESCRIPTION:
#
#       Attempt deletion of group with insufficient privileges.
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options.
#       Test:
#               - Attempt to delete share group with insufficient privileges.
#		  The operation is expected to fail.
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
#       delete NEG
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
function delete006 {
	tet_result PASS
	tc_id="delete006"
	tc_desc="Attempt deletion of group with insufficient priveleges."
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share groups
	create ${TG[0]}

	#
	# Delete one of the share groups with insufficient user privileges.
	#
	# Do a dry run first which is expected to pass as privileges aren't
	# checked.
	#
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	delete POS ${TG[0]} -n
	# Now execute the real command which we expect to fail.
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	delete NEG ${TG[0]}

	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
