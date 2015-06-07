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
# ident	"@(#)tp_zfs_003.ksh	1.4	09/08/01 SMI"
#

#
# zfs-share test case
#

#__stc_assertion_start
#
#ID: zfs003
#
#DESCRIPTION:
#
#	Create a zfs share with properties via zfs but is not shared and
#	attempt to share via sharemgr.
#
#STRATEGY:
#
#       Setup:
#		share a zfs file system via zfs and set a property via zfs
#       Test:
#		sharemgr set same option to reverse
#		verify that the zfs option is still set
#		unshare the file system and add to a test_group via sharemgr
#		sharemgr set option to reverse
#		confirm set succeeded.
#		remove-share via sharemgr and re-share via zfs
#		confirm zfs setting is still set.
#       Cleanup:
#		unshare the zfs file system via zfs 
#
#       STRATEGY_NOTES:
#		This may not be a failure if the file system is unshared.
#		The option must be set on the default group (which does
#		some bad things right now).
#
#KEYWORDS:
#
#       zfs
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
function zfs003 {
	tet_result PASS
	tc_id="zfs003"
	tc_desc="zfs share properties set, and currently not shared via zfs"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Setup
	#
	create test_group_1
	tet_infoline " - /usr/sbin/zfs set sharenfs=on `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs set sharenfs=on `convertzfs ${MP[1]}`
	tet_infoline " - /usr/sbin/zfs set sharenfs=nosuid `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs set sharenfs=nosuid `convertzfs ${MP[1]}`
	set_ NEG zfs "-p nosuid=false"

	tet_infoline " - /usr/sbin/zfs unshare `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs unshare `convertzfs ${MP[1]}`
	add_share test_group_1 "" ${MP[1]}
	set_ POS test_group_1 "-p nosuid=false"
	remove_share ${MP[1]}
	tet_infoline " - zfs share `convertzfs ${MP[1]}`"
	zfs share `convertzfs ${MP[1]}`
	zfs get sharenfs `convertzfs ${MP[1]}` | grep nosuid | \
	    grep -v false > /dev/null
	if [ $? -ne 0 ]
	then
		tet_infoline "FAIL - nosuid zfs setting was removed"
		tet_result FAIL
	fi

	tet_infoline " - /usr/sbin/zfs set sharenfs=off `convertzfs ${MP[1]}`"
	eval /usr/sbin/zfs set sharenfs=off `convertzfs ${MP[1]}`
	delete_all_test_groups
	report_cmds $tc_id POS
}
