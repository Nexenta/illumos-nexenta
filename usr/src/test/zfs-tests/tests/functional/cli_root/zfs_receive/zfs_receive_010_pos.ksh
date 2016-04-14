#!/bin/ksh -p
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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# Copyright 2016 Nexenta Systems, Inc. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib

#
# DESCRIPTION:
#	'zfs recv -F' destroy snapshots and file systems that do not
#	exist on the sending side.
#
# STRATEGY:
#	1. Create source filesystem.
#	2. Source filesystem: create child filesystems 'fs1', 'fs2'
#	   and take the recursive snapshot 'snap1'.
#	3. Source filesystem: send initial recursive replication stream
#	   from snapshot 'snap1'.
#	4. Destination filesystem: receive initial replication stream from
#	   source snapshot 'snap1'.
#	5. Source filesystem: take recursive snapshot 'snap2'.
#	6. Source filesystem: send incremental recursive replication stream
#	   from snapshot 'snap1' to snapshot 'snap2'.
#	7. Destination filesystem: receive incremental replication stream.
#	8. Destination filesystem: make sure that child filesystems 'fs1' and
#	   'fs2' and their recursive snapshots 'snap1' and 'snap2' are exists.
#	9. Source filesystem: create child filesystem 'fs3' and take recursive
#	   snapshot 'snap3'.
#	10. Source filesystem: recursively destroy snapshot 'snap1'.
#	11. Source filesystem: recursively destroy filesystem 'fs1'.
#	12. Source filesystem: send incremental recursive replication stream
#	    from snapshot 'snap2' to snapshot 'snap3'.
#	13. Destination filesystem: force receive (-F) incremental replication
#	    stream.
#	14. Destination filesystem: make sure that only child filesystems
#	    'fs2', 'fs3' and recursive snapshots 'snap2' and 'snap3' are exists.
#

verify_runnable "both"

typeset streamfile=/var/tmp/streamfile.$$
typeset dataset=$TESTPOOL/$TESTFS

function cleanup
{
	log_must $RM $streamfile
	log_must $ZFS destroy -rf $dataset/src
	log_must $ZFS destroy -rf $dataset/dst
}


log_assert "'zfs receive -F' destroy snapshots and file systems that do not " \
	"exist on the sending side."
log_onexit cleanup

log_must $ZFS create $dataset/src
log_must $ZFS create $dataset/src/fs1
log_must $ZFS create $dataset/src/fs2
log_must $ZFS snapshot -r $dataset/src@snap1
log_must $ZFS send -R $dataset/src@snap1 > $streamfile
log_must $ZFS receive $dataset/dst < $streamfile

log_must $ZFS snapshot -r $dataset/src@snap2
log_must $ZFS send -R -I $dataset/src@snap1 $dataset/src@snap2 > $streamfile
log_must $ZFS receive $dataset/dst < $streamfile
log_must $ZFS list $dataset/dst/fs1@snap1
log_must $ZFS list $dataset/dst/fs1@snap2
log_must $ZFS list $dataset/dst/fs2@snap1
log_must $ZFS list $dataset/dst/fs2@snap2

log_must $ZFS create $dataset/src/fs3
log_must $ZFS snapshot -r $dataset/src@snap3
log_must $ZFS destroy -r $dataset/src@snap1
log_must $ZFS destroy -r $dataset/src/fs1
log_must $ZFS send -R -I $dataset/src@snap2 $dataset/src@snap3 > $streamfile
log_must $ZFS receive -F $dataset/dst < $streamfile
log_must $ZFS list $dataset/dst/fs2@snap2
log_must $ZFS list $dataset/dst/fs2@snap3
log_must $ZFS list $dataset/dst/fs3@snap3
log_mustnot $ZFS list $dataset/dst/fs1
log_mustnot $ZFS list $dataset/dst/fs2@snap1

log_pass "Verifying 'zfs receive -F' succeeds."
