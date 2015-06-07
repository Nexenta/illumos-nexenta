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
# ident	"@(#)tp_sharectl_034.ksh	1.3	08/06/11 SMI"
#

#
# Sharectl test purpose
#

#__stc_assertion_start
#
#ID: sharectl034
#
#DESCRIPTION:
#
#       Attempt to modify the max_logs_preserve
#
#STRATEGY:
#
#       Setup:
#       Test:
#               set the max_logs_preserve to bad values
#       Cleanup:
#               - N/A
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       sharectl
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
function sharectl034 {
	tet_result PASS
	tc_id="sharectl034"
	tc_desc="Attempt to modify the max_logs_preserve to bad values"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	check_ctl_support max_logs_preserve
	if [ $? -ne 0 ]
	then
		tet_infoline "Support for max_logs_preserve is not available"
		tet_result UNSUPPORTED
		return
	fi
	set_ctl NEG max_logs_preserve -1 nfs
	set_ctl NEG max_logs_preserve 0 nfs
	set_ctl NEG max_logs_preserve one nfs
}
