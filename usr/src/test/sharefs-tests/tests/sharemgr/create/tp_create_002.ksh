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
# ident	"@(#)tp_create_002.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create002
#
#DESCRIPTION:
#
#	Create a group and make sure that legacy shares that are 
#	in existence are not removed.
#
#STRATEGY:
#
#       Setup:
#		- create a share using legacy method (if it still
#		  exists) if not this test will be skipped.
#       Test:
#		- create a test group 
#		- verify the create succeeds.
#		- verify the legacy share exists
#       Cleanup:
#		- Delete any groups created
#		- Delete any shares created
#               - Make sure to unshare the legacy share
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
function create002 {
	tet_result PASS
	tc_id="create002"
	tc_desc="Sharemgr should not kill old shares"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	if [ ! "$LEGACYSHARE" ]
	then
		tet_infoline "UNTESTED - Legacy share commands do not exist"
		tet_result UNTESTED
		return
	fi

	#
	# Share a path with the legacy command.
	#
	tet_infoline " - $LEGACYSHARE ${MP[0]}"
	$LEGACYSHARE ${MP[0]}
	sharecnt_before=`$LEGACYSHARE | wc -l`
	tet_infoline " $sharecnt_before shares found"
	#
	# Create a share group.  (Dry run then for real.)
	#
	create ${TG[0]} -n
	create ${TG[0]}
	#
	# Check the legacy share still exists
	#
	sharecnt_after=`$LEGACYSHARE | wc -l`
	tet_infoline " $sharecnt_after shares found"
	if [ $sharecnt_before -ne $sharecnt_after ]
	then
		tet_infoline "FAIL - legacy share was lost"
		tet_result FAIL
	else
		if [ $verbose ]
		then
			tet_infoline "PASS - legacy share still shared"
		fi
	fi

	#
	# Cleanup
	#
	tet_infoline " - $LEGACYUNSHARE ${MP[0]}"
	$LEGACYUNSHARE ${MP[0]} > /dev/null 2>&1
	delete_all_test_groups
	report_cmds $tc_id POS
}
