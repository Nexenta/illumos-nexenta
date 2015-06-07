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
# ident	"@(#)tp_set_security_011.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr set-security test case
#

#__stc_assertion_start
#
#ID: security011
#
#DESCRIPTION:
#
#	Attempt to change nfs properties without specifying nfs protocol.
#
#STRATEGY:
#
#	Setup:
#               - Create share group with nfs protocol but no properties set.
#               - Set the rw property to testzone2
#	Test:
#               - Execute sharemgr set for nfs protocol specifying
#		  rw property to testzone1 without the -P nfs
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
function security011 {
	tet_result PASS
	tc_id="security011"
	tc_desc="Attempt to execute 'sharemgr set/unset-security' modifying the"
	tc_desc="$tc_desc rw property with a different value without -P nfs"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol
	create ${TG[0]} -P nfs

	#
	# Attempt set to modify property with no protocol.  (Dry run
	# then the real thing.)
	#
	set_ POS ${TG[0]} -n -P nfs -S sys -p rw=testzone2
	set_ POS ${TG[0]} -P nfs -S sys -p rw=testzone2
	set_ NEG ${TG[0]} -n -S sys -p rw=testzone1
	set_ NEG ${TG[0]} -S sys -p rw=testzone1
	#
	# Attempt to unset the security property without specifying a
	# protocol.  (Dry run then the real thing.)
	#
	unset_ NEG ${TG[0]} -n -S sys -p rw
	unset_ NEG ${TG[0]} -S sys -p rw
	unset_ POS ${TG[0]} -n -P nfs -S sys -p rw
	unset_ POS ${TG[0]} -P nfs -S sys -p rw

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
