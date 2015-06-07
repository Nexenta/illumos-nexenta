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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tp_usage_001.ksh	1.4	09/08/01 SMI"
#

#
# sharemgr usage test case
#

#__stc_assertion_start
#
#ID: usage001
#
#DESCRIPTION:
#
#	Check that usage doesn't present incorrect data.
#
#STRATEGY:
#
#       Setup:
#		- dump the sharemgr usage list
#       Test:
#               - Check for each of the documented sub-commands
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       usage
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
function usage001 {
	tet_result PASS
	tc_id="usage001"
	tc_desc="Check the usage output of sharemgr command"
	usage_log="$SHR_TMPDIR/share_usage.log"
	usage_list="add-share create delete disable enable list"
	usage_list="$usage_list move-share remove-share set"
	usage_list="$usage_list set-share show share unset unshare"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	$SHAREMGR > $usage_log 2>&1
	append_cmd $SHAREMGR
	if [ "$report_only" ]
	then
		report_cmds $tc_id POS
		return
	fi

	for usage_item in $usage_list
	do
		shown_item=`awk ' {
			if ( $1 == item ) { print $1 }
		    } ' item=$usage_item $usage_log`
		if [ "$shown_item" != "$usage_item" ]
		then
			tet_infoline "$usage_item not listed in usage output"
			tet_result FAIL
		else
			if [ "$verbose" ]
			then
				tet_infoline "PASS : Check for $usage_item"
			fi
		fi
	done
	#
	# Cleanup
	#
	rm -f $usage_log
}
