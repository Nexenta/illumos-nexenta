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
# ident	"@(#)tp_set_security_012.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr set-security test case
#

#__stc_assertion_start
#
#ID: security012
#
#DESCRIPTION:
#
#	Attempt to change nfs properties with insufficient privileges
#
#STRATEGY:
#
#	Setup:
#               - Create share group with nfs protocol but no properties set.
#               - Set the rw property to testzone2
#	Test:
#               - Execute sharemgr set for nfs protocol specifying
#		  rw property to testzone1 with insufficient privileges.
#	Cleanup:
#		Forcibly delete all share groups
#
#	STRATEGY_NOTES:
#
#KEYWORDS:
#
#	set-security
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
function security012 {
	tet_result PASS
	tc_id="security012"
	tc_desc="Attempt to execute 'sharemgr set/unset-security' modifying the"
	tc_desc="$tc_desc rw property with a different value with insufficient"
	tc_desc="$tc_desc privileges."
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol
	create ${TG[0]} -P nfs

	#
	# Attempt set without proper permissions.
	#
	set_ POS ${TG[0]} -P nfs -S sys -p rw=testzone2
	# Dry run is expected to pass as permissions aren't checked.
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	set_ POS ${TG[0]} -n -P nfs -S sys -p rw=testzone1
	# Actual attempt is expected to fail.
	cmd_prefix="su - nobody -c \""
	cmd_postfix="\""
	set_ NEG ${TG[0]} -P nfs -S sys -p rw=testzone1
	#
	# Attempt unset_ without proper permissions
	#
	# Dry run is expected to pass as permissions aren't checked.
	unset_ NEG ${TG[0]} -n -P nfs -S sys -p rw=testzone1
	# Actual attempt is expected to fail.
	unset_ NEG ${TG[0]} -P nfs -S sys -p rw=testzone1

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
