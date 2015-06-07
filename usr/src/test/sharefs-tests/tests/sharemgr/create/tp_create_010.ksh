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
# ident	"@(#)tp_create_010.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create010
#
#DESCRIPTION:
#
#	Create a group with a property after group should fail.
#
#STRATEGY:
#
#       Setup:
#       Test:
#		- Attempt to create with "${TG[0]} anon=1234"
#       Cleanup:
#		- Delete any groups created
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       create NEG
#
#TESTABILITY: explicit
#
#AUTHOR: sean.wilcox@sun.com
#
#REVIEWERS: TBD
#
#TEST_AUTOMATION_LEVEL: automated
#
#CODING_STATUS: COMPLETE
#
#__stc_assertion_end
function create010 {
	tet_result PASS
	tc_id="create010"
	tc_desc="Sharemgr should fail : create ${TG[0]} anon=1234"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Create a group.  (Dry run then for real.)
	#
	create NEG "${TG[0]} anon=1234" -n
	create NEG "${TG[0]} anon=1234"
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds POS
}
