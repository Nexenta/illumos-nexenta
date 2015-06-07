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
# ident	"@(#)tp_disable_008.ksh	1.3	08/06/11 SMI"
#

#
# Disable test case
#

#__stc_assertion_start
#
#ID: disable008
#
#DESCRIPTION:
#
#	Disable/enable all groups when multiple groups exist
#
#STRATEGY:
#
#	Setup:
#		- Create first share group with default properties.
#		- Populate first group with one share.
#		- Populate first group with second share.
#		- Create second share group with default properties.
#		- Populate second group with one share.
#		- Populate second group with second share.
#	Test:
#		- Disable all groups.
#		- Enable all groups.
#	Cleanup:
#		- Delete any shares created
#		- Delete any groups created
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
#	disable/enable
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
function disable008 {
	tet_result PASS
	tc_id="disable008"
	tc_desc="Disable/enable all groups when multiple groups exist"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create and populate first share group
	create ${TG[0]}
	add_share POS ${TG[0]} "" ${MP[0]}
	add_share POS ${TG[0]} "" ${MP[1]}

	# Create and populate second share group
	create ${TG[1]}
	add_share POS ${TG[1]} "" ${MP[2]}
	add_share POS ${TG[1]} "" ${MP[3]}

	#
	# Perform disable/enable operations
	#
	# Disable all groups and verify the states have changed.  (Dry run
	# first then the real thing.)
	#
	disable POS "-n -a"
	disable POS "-a"

	#
	# Enable all groups and verify the states have changed.  (Dry run
	# first then the real thing.)
	#
	enable POS "-n -a"
	enable POS "-a"

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
