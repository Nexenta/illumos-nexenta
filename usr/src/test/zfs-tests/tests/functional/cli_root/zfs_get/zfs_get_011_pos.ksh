#! /usr/bin/ksh -p
#
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#

#
# Copyright 2017 Nexenta Systems, Inc. All rights reserved.
#

. $STF_SUITE/tests/functional/cli_root/zfs_get/zfs_get_common.kshlib
. $STF_SUITE/tests/functional/cli_root/zfs_get/zfs_get_list_d.kshlib

#
# DESCRIPTION:
#	Check 'modified' zfs property works properly
#
# STRATEGY:
#	1. Create a filesystem
#	2. Create a snapshot for the filesystem
#	3. Check 'modified' property of the snapshot: should be 'no'
#	4. Create a file in the filesystem
#	5. Check 'modified' property of the snapshot: should be 'yes'
#	6. Create another snapshot for the filesystem
#	7. Check 'modified' property of the snapshot: should be 'no'
#	8. Do rollback for the first snapshot
#	9. Check 'modified' property of the snapshot: should be 'no'
#

verify_runnable "both"

log_assert "'modified' zfs-property should work properly"

mntpnt=$(get_prop mountpoint $TESTPOOL/$TESTFS)
TEST_FILE="$mntpnt/test_file"

create_snapshot $TESTPOOL/$TESTFS $TESTSNAP1
RESULT=$(get_prop "modified" $TESTPOOL/$TESTFS@$TESTSNAP1)
if [[ $RESULT != "no" ]]
then
	log_fail "1. 'modified' property should be 'no'"
fi

log_must $TOUCH $TEST_FILE
# We need to wait for at least one "sync"
log_must $SLEEP 6
RESULT=$(get_prop "modified" $TESTPOOL/$TESTFS@$TESTSNAP1)
if [[ $RESULT != "yes" ]]
then
	log_fail "2. 'modified' property should be 'yes'"
fi

create_snapshot $TESTPOOL/$TESTFS $TESTSNAP2
RESULT=$(get_prop "modified" $TESTPOOL/$TESTFS@$TESTSNAP2)
if [[ $RESULT != "no" ]]
then
	log_fail "3. 'modified' property should be 'no'"
fi

log_must $ZFS rollback -r $TESTPOOL/$TESTFS@$TESTSNAP1
RESULT=$(get_prop "modified" $TESTPOOL/$TESTFS@$TESTSNAP1)
if [[ $RESULT != "no" ]]
then
	log_fail "4. 'modified' property should be 'no'"
fi

log_pass "'modified' zfs-property should work properly"
