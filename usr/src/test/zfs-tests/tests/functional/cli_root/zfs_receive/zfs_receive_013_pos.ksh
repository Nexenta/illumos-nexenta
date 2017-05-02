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
#	Verifying that an incremental replication stream can be received
#	after the first promote for the source child clone.
#
# STRATEGY:
#	1. Create source filesystem.
#	2. Create child dataset for the source filesystem.
#	3. Create first snapshot for the child filesystem.
#	4. Create clone from the first snapshot.
#	5. Create second snapshot for the clone.
#	6. Create another clone from the second snapshot.
#	7. Create the third recursive snapshot for the source filesystem.
#	8. Generate a full recursive stream from the third snapshot and
#	   save this stream into the file.
#	9. Receive full recursive stream from the file and create a new
#	   destination filesystem as well.
#	10. Promote the latest clone.
#	11. Create the fourth recursive snapshot for the source filesystem.
#	12. Generate an incremental recursive stream from the third snapshot
#	    (the incremental source) to	the fourth snapshot (the incremental
#	    target. Save this stream into the file.
#	13. Verify that an incremental replication stream can be received
#	    after the first promote for the source child clone.
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

log_assert "Verifying that an incremental replication stream can be received" \
	"after promote."
log_onexit cleanup

log_must $ZFS create $dataset/$src
log_must $ZFS create $dataset/$src/a
log_must $ZFS snapshot $dataset/$src/a@b
log_must $ZFS clone $dataset/$src/a@b $dataset/$src/b
log_must $ZFS snapshot $dataset/$src/b@c
log_must $ZFS clone $dataset/$src/b@c $dataset/$src/c
log_must $ZFS snapshot -r $dataset/$src@r1
log_must $ZFS send -Rv $dataset/$src@r1 > $streamfile
log_must $ZFS receive -v $dataset/$dst < $streamfile
log_must $ZFS promote $dataset/$src/c
log_must $ZFS snapshot -r $dataset/$src@r2
log_must $ZFS send -Rv -I $dataset/$src@r1 $dataset/$src@r2 > $streamfile
log_must $ZFS receive -v $dataset/$dst < $streamfile

log_pass "Verifying that an incremental replication stream can be received" \
	"after promote."
