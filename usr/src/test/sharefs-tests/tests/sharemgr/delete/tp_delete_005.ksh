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
# ident	"@(#)tp_delete_005.ksh	1.3	08/06/11 SMI"
#

#
# delete test case
#

#__stc_assertion_start
#
#ID: delete005
#
#DESCRIPTION:
#
#       Make sure deleting one group does not impact any others.
#
#STRATEGY:
#
#       Setup:
#		- Create 3 share groups
#		- Add a share to each of the share groups
#       Test:
#               - Delete a share group.
#               - Verify that the share group no longer exists.
#		- Verify that the remaining share groups exist.
#       Cleanup:
#		- Delete any groups created
#		- Delete any shares created
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
function delete005 {
	tet_result PASS
	tc_id="delete005"
	tc_desc="Make sure deleting one group does not impact any others"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share groups
	create ${TG[0]}
	create ${TG[1]} -P nfs
	create ${TG[2]}
	#
	# Add shares to the test groups
	add_share POS ${TG[0]} "" ${MP[0]}
	add_share POS ${TG[1]} "" ${MP[1]}
	add_share POS ${TG[2]} "" ${MP[2]}

	#
	# Delete one of the share groups  (Dry run then the real thing.)
	#
	delete POS ${TG[1]} -n -f
	delete POS ${TG[1]} -f

	tet_infoline "* Verify remaining groups are still intact"
	verify_share -g ${TG[0]}
	protocol_property_verification ${TG[0]}
	verify_share -g ${TG[2]}
	protocol_property_verification ${TG[2]}
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
