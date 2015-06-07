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
# ident	"@(#)tp_add_009.ksh	1.3	08/06/12 SMI"
#

#
# add-share test case
#

#__stc_assertion_start
#
#ID: add009
#
#DESCRIPTION:
#
#	Attempt to add share with insufficient privileges
#
#STRATEGY:
#
#       Setup:
#               - Create share group with default options.
#       Test:
#		- Attempt to add a share with insufficient privileges.  The
#		  attempt should fail.
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#               - Return status is checked for all share-related commands
#                 executed.
#
#KEYWORDS:
#
#       add-share
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
function add009 {
	tet_result PASS
	tc_id="add009"
	tc_desc="Attempt to add share with insufficient privileges"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	# Create share group
	create test_group_1

	#
	# Attempt to add share while having insufficient user
	# privileges.
	#
	# Dry run - this should succeed as privileges aren't checked
	# during a dry run.
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	add_share POS test_group_1 "-n" ${MP[0]}
	# Real thing - this should fail.
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	add_share NEG test_group_1 "" ${MP[0]}

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
