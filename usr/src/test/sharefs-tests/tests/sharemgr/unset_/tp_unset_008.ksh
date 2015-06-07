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
# ident	"@(#)tp_unset_008.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr unset test case
#

#__stc_assertion_start
#
#ID: unset008
#
#DESCRIPTION:
#
#	Attempt to unset nfs properties when none of them were set.
#
#STRATEGY:
#
#	Setup:
#		- Create share group with nfs protocol and no properties set.
#	Test:
#		- Clear all nfs properties at the same time.  The operation
#		  should fail as none of them are set.
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
function unset008 {
	tet_result PASS
	tc_id="unset008"
	tc_desc="Unset all nfs properties when none of them were set"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol and no properties set.
	#
	create POS test_group_1 -P nfs

	#
	# Clear all nfs properties for the group.  This should fail.
	# (Dry run then the real thing.)
	#
	unset_ NEG test_group_1 -n -P nfs -p aclok -p anon -p index \
	    -p log -p nosub -p nosuid -p publicue\"
	unset_ NEG test_group_1 -P nfs -p aclok -p anon -p index \
	    -p log -p nosub -p nosuid -p publicue\"

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
