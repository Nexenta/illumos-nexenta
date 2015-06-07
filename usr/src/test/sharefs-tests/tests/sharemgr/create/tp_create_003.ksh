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
# ident	"@(#)tp_create_003.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create003
#
#DESCRIPTION:
#
#	Create a group removes legacy shares from /etc/dfs/dfstab
#
#STRATEGY:
#
#       Setup:
#		- Add a legacy share line to the /etc/dfs/dfstab
#       Test:
#		- use the create command to create a group
#		- Check that the legacy share line still exists
#       Cleanup:
#		- Clean up any groups created
#		- Clean up any shares created
#               - Remove the line from the /etc/dfs/dfstab
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       create legacy
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
function create003 {
	tet_result PASS
	tc_id="create003"
	tc_desc="Sharemgr should not remove shares from /etc/dfs/dfstab"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Backup and edit the /etc/dfs/dfstab file
	#
	cp /etc/dfs/dfstab /etc/dfs/dfstab.tet_sharemgr_test
	if [ $? -ne 0 ]
	then
		tet_infoline "Could not back /etc/dfs/dfstab"
		tet_result UNRESOLVED
		return
	fi
	tet_infoline " Writing the following line to dfstab :"
	tet_infoline "  share -F nfs -d \"tet share tests\" ${MP[0]}"
	echo "share -F nfs -d \"tet share tests\" ${MP[0]}" >> /etc/dfs/dfstab
	#
	# Create a group.  (Dry run, then for real.)
	#
	create ${TG[0]} -n
	create ${TG[0]}
	#
	# Check to see if the legacy share still exists.
	#
	grep "tet share tests" /etc/dfs/dfstab > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		tet_infoline "FAIL - sharemgr removed the legacy share from dfstab"
		tet_result FAIL
	else
		if [ $verbose ]
		then
			tet_infoline "PASS - sharemgr left the legacy share"
		fi
	fi
	#
	# Cleanup
	#
	delete_all_test_groups
	mv /etc/dfs/dfstab.tet_sharemgr_test /etc/dfs/dfstab
	report_cmds POS
}
