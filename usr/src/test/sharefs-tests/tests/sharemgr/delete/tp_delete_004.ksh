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
# ident	"@(#)tp_delete_004.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete004
#
#DESCRIPTION:
#
#	Verify -f flag required to remove group that contains a share
#
#STRATEGY:
#
#       Setup:
#               - Create first share group with default options.
#		- Add a share to the share group.
#       Test:
#		- Attempt to delete the share group without using the '-f'
#		  flag.  This operation should fail.
#               - Delete share group using the -f flag.
#               - Verify that the share group no longer exists.
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
function delete004 {
	tet_result PASS
	tc_id="delete004"
	tc_desc="Verify -f flag required to remove group that contains a share"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group
	create ${TG[0]}
	# Add the share to the group
	add_share POS ${TG[0]} "" ${MP[0]}
	# Attempt to delete the share without using the '-f' option.  This
	# should fail.  (Dry run then the real thing.)
	delete NEG ${TG[0]} -n
	delete NEG ${TG[0]}
	if [ $? -ne 0 ]
	then
		delete POS ${TG[0]} "-f"
	else
		tet_infoline "${TG[0]} was removed without the force (-f) option"
	fi
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
