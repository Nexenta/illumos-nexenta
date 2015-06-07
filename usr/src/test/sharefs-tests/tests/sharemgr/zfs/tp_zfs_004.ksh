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
# ident	"@(#)tp_zfs_004.ksh	1.4	09/08/01 SMI"
#

#
# zfs-share test case
#

#__stc_assertion_start
#
#ID: zfs004
#
#DESCRIPTION:
#
#	Disable/enable default group after zfs share does not reshare zfs
#
#STRATEGY:
#
#	Setup:
#		- share a zfs file system via zfs
#	Test:
#		- disable and enable the default group
#		- verify that the zfs share is shared.
#	Cleanup:
#		- unshare the file system via zfs
#
#	STRATEGY_NOTES:
#
#KEYWORDS:
#
#	zfs
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
function zfs004 {
	tet_result PASS
	tc_id="zfs004"
	tc_desc="Disable/enable default group after zfs share does not reshare"
	tc_desc="$tc_desc zfs"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	# Create share group
	create test_group_1
	tet_infoline " - /usr/sbin/zfs set sharenfs=on `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs set sharenfs=on `convertzfs ${MP[1]}`

	disable zfs
	enable zfs

	tet_infoline " - $SHAREMGR show zfs | grep ${MP[1]}"
	$SHAREMGR show zfs | grep ${MP[1]} > /dev/null 2>&1
	POS_result $? "zfs file system not shared after disable/enable of default"

	#
	# Cleanup
	#
	tet_infoline " - /usr/sbin/zfs set sharenfs=off `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs set sharenfs=off `convertzfs ${MP[1]}`
	delete_all_test_groups
	report_cmds $tc_id POS
}
