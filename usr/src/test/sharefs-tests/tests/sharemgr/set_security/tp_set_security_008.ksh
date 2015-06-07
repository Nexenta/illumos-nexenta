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
# ident	"@(#)tp_set_security_008.ksh	1.3	08/06/11 SMI"
#

#
# sharemgr set-security test case
#

#__stc_assertion_start
#
#ID: security008
#
#DESCRIPTION:
#
#	Attempt to execute 'sharemgr set' setting nfs ro and rw property 
#	with the different hosts, then unset both at the same time.
#
#STRATEGY:
#
#	Setup:
#               - Create share group with nfs protocol but no properties set.
#	Test:
#               - Execute sharemgr set for nfs protocol specifying
#		  ro and rw property with the same value
#               - Execute sharemgr unset for nfs protocol specifying
#		  ro and rw property.
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
function security008 {
	tet_result PASS
	tc_id="security008"
	tc_desc="Execute 'sharemgr set' setting nfs ro and rw to different"
	tc_desc="$tc_desc hosts then unset both at once"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	# Create share group with nfs protocol
	create ${TG[0]} -P nfs

	#
	# Attempt set_ rw and ro with different hosts.  (Dry run then
	# the real thing.)
	#
	set_ POS ${TG[0]} -n -P nfs -S sys -p rw=testzone1 -p ro=testzone2
	set_ POS ${TG[0]} -P nfs -S sys -p rw=testzone1 -p ro=testzone2
	#
	# Attempt to unset the rw and ro at the same time
	#
	unset_ ${TG[0]} -n -P nfs -S sys -p rw -p ro
	unset_ ${TG[0]} -P nfs -S sys -p rw -p ro

	#
	# Cleanup
	#
	# Delete all test groups
	delete_all_test_groups
	report_cmds $tc_id POS
}
