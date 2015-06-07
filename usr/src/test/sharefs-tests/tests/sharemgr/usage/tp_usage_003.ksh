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
# ident	"@(#)tp_usage_003.ksh	1.4	09/08/01 SMI"
#

#
# sharemgr usage test case
#

#__stc_assertion_start
#
#ID: usage003
#
#DESCRIPTION:
#
#	Check individual usage doesn't present incorrect data when no
#	option is given.
#
#STRATEGY:
#
#       Setup:
#		- dump the sharemgr usage for each documented sub-command
#       Test:
#               - Check the sub-command is listed correctly.
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#		- only checking subcommands that require options
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
function usage003 {
	tet_result PASS
	tc_id="usage003"
	tc_desc="Check the usage output of sharemgr sub-commands"
	usage_log="$SHR_TMPDIR/share_usage.log"
	usage_list="add-share create delete disable enable"
	usage_list="$usage_list move-share remove-share set"
	usage_list="$usage_list set-share unset unshare"
	badopt="-xyz"

	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	for usage_item in $usage_list
	do
		result=0
		$SHAREMGR $usage_item 2>&1 | grep usage > $usage_log 2>&1
		append_cmd "$SHAREMGR $usage_item"
		if [ "$report_only" ]
		then
			continue
		fi
		shown_item=`awk ' {
		        if ( $2 == item ) { print $2 }
		    } ' item=$usage_item $usage_log`
		if [ "$shown_item" != "$usage_item" ]
		then
			result=1
		fi
		if [ $result -ne 0 ]
		then
			tet_infoline "$usage_item not shown correctly in usage"
			infofile "" $usage_log
			tet_result FAIL
		else
			if [ "$verbose" ]
			then
				tet_infoline "-----------------------------"
				tet_infoline "PASS : $usage_item"
				tet_infoline "$SHAREMGR $usage_item $badopt"
				tet_infoline `$SHAREMGR $usage_item $badopt`
				tet_infoline "-----------------------------"
			fi
		fi
	done

	#
	# cleanup
	#
	rm -f $usage_log
	report_cmds $tc_id POS
}
