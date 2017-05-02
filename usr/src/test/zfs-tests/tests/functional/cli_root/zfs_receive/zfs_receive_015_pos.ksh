#!/bin/ksh -p
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

. $STF_SUITE/include/libtest.shlib

#
# DESCRIPTION:
#	Verifying that receiving an incremental send works correctly
#	after flip the direction of replication for cloned datasets.
#
# STRATEGY:
#	1. Create source filesystem.
#	2. Create child dataset for the source filesystem.
#	3. Create first snapshot for the child filesystem.
#	4. Create clone from the first snapshot.
#	5. Create second snapshot for the clone.
#	6. Create another clone from the second snapshot.
#	7. Create the third recursive snapshot for the source filesystem.
#	8. Generate a full non-recursive stream from the third snapshot
#	   for the source filesystem and save this stream into the file.
#	9. Receive full non-recursive stream from the file and create a new
#	   destination filesystem as well.
#	10. Generate a full non-recursive stream from the third snapshot
#	    for the first clone and save this stream into the file.
#	11. Receive full non-recursive stream from the file and create a new
#	    child for the destination filesystem as well.
#	12. Generate a full non-recursive stream from the third snapshot
#	    for the second clone and save this stream into the file.
#	13. Receive full non-recursive stream from the file and create a new
#	    destination child filesystem as well.
#	14. Flip the direction of replication: create the fourth recursive
#	    snapshot for the destination filesystem.
#	15. Generate an incremental recursive stream from the third snapshot
#	    (the incremental source) to	the fourth snapshot (the incremental
#	    target. Save this stream into the file.
#	16. Verify that receiving an incremental send works correctly
#	    after flip the direction of replication for cloned datasets.
#

verify_runnable "both"

typeset streamfile=/var/tmp/streamfile.$$
typeset dataset=$TESTPOOL/$TESTFS
typeset src=src.$$
typeset dst=dst.$$

function cleanup
{
	log_must $RM -f $streamfile
	log_must $ZFS destroy -rf $dataset/$src
	log_must $ZFS destroy -rf $dataset/$dst
}

log_assert "Verifying that receiving an incremental send works correctly" \
	"after flip the direction of replication for cloned datasets."
log_onexit cleanup

log_must $ZFS create $dataset/$src
log_must $ZFS create $dataset/$src/a
log_must $ZFS snapshot $dataset/$src/a@b
log_must $ZFS clone $dataset/$src/a@b $dataset/$src/b
log_must $ZFS snapshot $dataset/$src/b@c
log_must $ZFS clone $dataset/$src/b@c $dataset/$src/c
log_must $ZFS snapshot -r $dataset/$src@r1
log_must $ZFS send -v $dataset/$src@r1 > $streamfile
log_must $ZFS receive -v $dataset/$dst < $streamfile
log_must $ZFS send -v $dataset/$src/b@r1 > $streamfile
log_must $ZFS receive -v $dataset/$dst/b < $streamfile
log_must $ZFS send -v $dataset/$src/c@r1 > $streamfile
log_must $ZFS receive -v $dataset/$dst/c < $streamfile
log_must $ZFS snapshot -r $dataset/$dst@r2
log_must $ZFS send -Rv -I $dataset/$dst@r1 $dataset/$dst@r2 > $streamfile
log_must $ZFS receive -v $dataset/$src < $streamfile

log_pass "Verifying that receiving an incremental send works correctly" \
	"after flip the direction of replication for cloned datasets."
