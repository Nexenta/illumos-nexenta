#! /usr/bin/ksh -p
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
# ident	"@(#)kill_mountd.ksh	1.6	08/06/12 SMI"
#

#
# oneoffs test cases
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1"
ic1="kill_mountd"

#__stc_assertion_start
#
#ID: oneoff001
#
#DESCRIPTION:
#
#	If mountd is killed sharemgr gets in a bad state for
#	certain commands.
#
#STRATEGY:
#
#       Setup:
#               - Create share groups and shares.
#       Test:
#		- Kill mountd and make sure sharemgr can still do 
#		  the following commands succesfully :
#			create
#			add-share
#			list
#			show
#			remove-share
#			delete
#
#       Cleanup:
#               - Make sure to restart mounted
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       kill mountd
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
function kill_mountd {
	tet_result PASS
	tc_id="kill_mountd"
	tc_desc="Kill mountd causes sharemgr problems"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc
	#
	# Setup
	#
	create test_group_1
	add_share POS test_group_1 "" ${MP[0]}
	tet_infoline " - svcadm disable network/nfs/server"
	svcadm disable network/nfs/server

	remove_share POS test_group_1 "" ${MP[0]}
	create test_group_2
	add_share POS test_group_2 "" ${MP[1]}
	list POS
	show POS
	remove_share POS test_group_2 "" ${MP[1]}
	delete test_group_2

	#
	# Cleanup
	#
	delete_all_test_groups
	#
	# Restart mountd
	#
	tet_infoline " - svcadm enable network/nfs/server"
	svcadm enable network/nfs/server
	report_cmds $tc_id POS
}

function startup
{
	tet_infoline "Checking environment and runability"
	share_startup
}

function cleanup
{
	tet_infoline "Cleaning up after tests"
	share_cleanup
}

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
