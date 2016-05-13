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
#	Verifying 'zfs receive <cloned_dataset>' works.
#
# STRATEGY:
#	1. Create source filesystem 'src'.
#	2. Source filesystem: take the recursive snapshot 'snap1'.
#	3. Source filesystem: send initial recursive replication stream
#	   from the snapshot 'snap1'.
#	4. Destination filesystem: receive initial replication stream from the
#	   source snapshot 'snap1'.
#	5. Source filesystem: take the recursive snapshot 'snap2'.
#	6. Source filesystem: send incremental recursive replication stream
#	   from snapshot 'snap1' to snapshot 'snap2'.
#	7. Destination filesystem: receive incremental replication stream.
#	8. Destination filesystem: create a clone 'clone' of the snapshot
#	   'snap1'.
#	9. Destination filesystem: promote cloned filesystem.
#	10. Source filesystem: take the recursive snapshot 'snap3'.
#	11. Source filesystem: send incremental recursive replication stream
#	    from snapshot 'snap2' to snapshot 'snap3'.
#	12. Destination filesystem: receive incremental replication stream.
#	13. Destination filesystem: verify the receiving results.
#

verify_runnable "both"

typeset streamfile=/var/tmp/streamfile.$$
typeset dataset=$TESTPOOL/$TESTFS

function cleanup
{
	log_must $RM $streamfile
	log_must $ZFS destroy -rf $dataset/src
	log_must $ZFS destroy -rf $dataset/clone
	log_must $ZFS destroy -rf $dataset/dst
}

log_assert "Verifying 'zfs receive <cloned_dataset>' works."
log_onexit cleanup

log_must $ZFS create $dataset/src
log_must $ZFS snapshot -r $dataset/src@snap1
log_must $ZFS send -R $dataset/src@snap1 > $streamfile
log_must $ZFS receive $dataset/dst < $streamfile
log_must $ZFS snapshot -r $dataset/src@snap2
log_must $ZFS send -R -I $dataset/src@snap1 $dataset/src@snap2 > $streamfile
log_must $ZFS receive $dataset/dst < $streamfile
log_must $ZFS clone $dataset/dst@snap1 $dataset/clone
log_must $ZFS promote $dataset/clone
log_must $ZFS snapshot -r $dataset/src@snap3
log_must $ZFS send -R -I $dataset/src@snap2 $dataset/src@snap3 > $streamfile
log_must $ZFS receive $dataset/dst < $streamfile

log_pass "Verifying 'zfs receive <cloned_dataset>' works."
