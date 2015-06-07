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
# ident	"@(#)tp_create_001.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create001
#
#DESCRIPTION:
#
#	Create a "blank" group
#
#STRATEGY:
#
#       Setup:
#		- Create 2 groups as a control set of groups
#       Test:
#		- use the create command without a group
#		- Verify that the command fails and that no group
#		  was created.
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
function create001 {
	tet_result PASS
	tc_id="create001"
	tc_desc="Create a blank group"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group.  (Dry run, then for real.)
	create ${TG[0]} -n
	create ${TG[0]}
	create ${TG[1]} -n
	create ${TG[1]}

	#
	# Call list and count the items in the list
	#
	list
	groupcnt_before=`wc -l $l_log | awk ' { print $1 } '`
	#
	# Call create without a group.  (Dry run, then for real.)
	#
	create NEG "" -n
	create NEG ""
	#
	# Call list and count the items in the list, then check that the 
	# count has not increased.
	#
	list
	groupcnt_after=`wc -l $l_log | awk ' { print $1 } '`
	if [ $groupcnt_before -ne $groupcnt_after ]
	then
		tet_infoline "FAIL - a blank group seems to have been created"
		tet_result FAIL
	else
		if [ $verbose ]
		then
			tet_infoline "PASS - a blank group was not created"
		fi
	fi
	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds $tc_id POS
}
