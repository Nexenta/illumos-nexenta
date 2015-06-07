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
# ident	"@(#)tp_set_security_001.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr security test case
#

#__stc_assertion_start
#
#ID: security001
#
#DESCRIPTION:
#
#	Execute 'sharemgr set/unset' for nfs with '-S sys' but no properties
#	specified.
#
#STRATEGY:
#
#	Setup:
#               - Create share group with nfs protocol but no properties set.
#	Test:
#               - Execute sharemgr set for nfs protocol & '-S sys' without 
#		  specifying any properties.
#	Cleanup:
#		Forcibly delete all share groups
#
#	STRATEGY_NOTES:
#
#KEYWORDS:
#
#	set security
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
function security001 {
	tet_result PASS
	tc_id="security001"
	tc_desc="Execute 'sharemgr set/unset' for nfs with '-S sys' but no"
	tc_desc="$tc_desc properties specified"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol
	create ${TG[0]} -P nfs

	#
	# Attempt set_ with no properties.  (Dry run first then
	# the real thing.)
	#
	set_ POS ${TG[0]} -n -P nfs -S sys
	set_ POS ${TG[0]} -P nfs -S sys
	#
	# Attempt unset_ with no properties.  (Dry run first then
	# the real thing.)
	#
	unset_ POS ${TG[0]} -n -P nfs -S sys
	unset_ POS ${TG[0]} -P nfs -S sys

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
