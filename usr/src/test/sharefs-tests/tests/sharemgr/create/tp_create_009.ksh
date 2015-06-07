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
# ident	"@(#)tp_create_009.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create009
#
#DESCRIPTION:
#
#	Create a group shares legacy shares from /etc/dfs/dfstab
#	if they are not shared.
#
#STRATEGY:
#
#       Setup:
#		- Add a legacy share line to the /etc/dfs/dfstab
#       Test:
#		- use the create command to create a group
#		- Check that the legacy share is not shared.
#       Cleanup:
#		- Delete any groups created
#		- Delete any shares created
#               - Remove the line from the /etc/dfs/dfstab
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       create
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
function create009 {
	tet_result PASS
	tc_id="create009"
	tc_desc="Sharemgr should not share unshared legacy shares from /etc/dfs/dfstab"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Backup and edit the /etc/dfs/dfstab file
	#
	cp /etc/dfs/dfstab /etc/dfs/dfstab.tet_sharemgr_test
	sleep 1
	if [ $? -ne 0 ]
	then
		tet_infoline "Could not back /etc/dfs/dfstab"
		tet_result UNRESOLVED
		return
	fi
	tet_infoline "Writing following line to dfstab"
	tet_infoline "share -F nfs ${MP[0]}"
	echo "share -F nfs ${MP[0]}" >> /etc/dfs/dfstab
	#
	# Create a group.  (Dry run then for real.)
	#
	create ${TG[0]} -n
	create ${TG[0]}
	#
	# Check to see if the legacy share is shared
	#
	$LEGACYSHARE | grep "${MP[0]}" > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		tet_infoline "FAIL - sharemgr shared the legacy share "\
		    "from dfstab"
		tet_result FAIL
	else
		if [ $verbose ]
		then
			tet_infoline "PASS - sharemgr did not share "\
			    "the legacy share"
		fi
	fi
	#
	# Cleanup
	#
	delete_all_test_groups
	mv /etc/dfs/dfstab.tet_sharemgr_test /etc/dfs/dfstab
	#
	# Check to see if the share shows up in sharemgr if so, mark
	# as a failure and remove the share so as not to propagate 
	# failure to future tests.
	#
	$SHAREMGR show | grep ${MP[0]} > /dev/null
	if [ $? -eq 0 ]
	then
		tet_infoline "FAIL - sharemgr shows ${MP[0]} is shared."
		tet_result FAIL
		tp_create0009_grp=`which_group ${MP[0]}`
		remove_share POS $tp_create0009_grp ${MP[0]}
	fi
	report_cmds POS
}
