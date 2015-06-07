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
# ident	"@(#)tp_unset_012.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr unset test case
#

#__stc_assertion_start
#
#ID: unset012
#
#DESCRIPTION:
#
#	Attempt to unset multiple nfs properties without specifying a protocol.
#
#STRATEGY:
#
#	Setup:
#		- Create share group with nfs protocol and properties set.
#	Test:
#		- Attempt to unset one of the properties without having
#		  specified a protocol.  The attempt should fail.
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
function unset012 {
	tet_result PASS
	tc_id="unset012"
	tc_desc="Attempt to unset multiple nfs properties without specifying"
	tc_desc="$tc_desc a protocol"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol and all properties set
	#
	create POS test_group_1 -P nfs -p aclok=\"true\" -p anon=\"1234\" \
	    -p index=\"test_file_aaa\" -p log=\"true\" -p nosub=\"true\" \
	    -p nosuid=\"true\"

	# Attempt to clear some of the group properties without specifying
	# a protocol.  (Dry run then the real thing.)
	unset_ NEG test_group_1 -n -p aclok -p index
	unset_ NEG test_group_1 -p aclok -p index

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
