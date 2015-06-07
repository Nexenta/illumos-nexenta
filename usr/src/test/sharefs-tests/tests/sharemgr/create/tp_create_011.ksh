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
# ident	"@(#)tp_create_011.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create011
#
#DESCRIPTION:
#	
#	Try adding protocol to group with default protocols (all supported)
#
#STRATEGY:
#
#       Setup:
#		- Create a group to use in the test.
#       Test:
#		- Create a group with -P <protocol> where group was
#		  already created.
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
function create011 {
	tet_result PASS
	tc_id="create011"
	tc_desc="Try adding protocol to group with default protocols (all supported)"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Create a group with default protocols (all supported).  (Dry run
	# then for real.)
	#
	create ${TG[0]} -n
	create ${TG[0]}

	#
	# Attempt to add NFS protocol even though all protocols already
	# enabled for the group.  This should fail.
	#
	create NEG ${TG[0]} -P nfs

	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds POS
}
