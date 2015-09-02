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
# Copyright 2015 Nexenta Systems, Inc. All rights reserved.
#

. $STF_SUITE/tests/functional/wrc/wrc.cfg
. $STF_SUITE/tests/functional/wrc/wrc.kshlib

#
# DESCRIPTION:
#	Non-redundant wrc vdev can not be detached from existing pool.
#
# STRATEGY:
#	1. Create pool with separated wrc devices.
#	2. Enable wrc active/passive/off mode
#	3. Display pool status
#	4. Try to detach non-redundant wrc vdev 
#	5. Verify failed to detach
#

verify_runnable "global"
log_assert "Non-redundant wrc vdev can not be detached."
log_onexit cleanup
for wrc_mode in "off" "active" "passive" ; do
	rs=$(random_get "4k" "8k" "16k" "32k" "64k" "128k")
	cs=$(random_get "off" "on" "lz4" "lzjb")
	log_must $ZPOOL create -f \
		-O compression=$cs -O recordsize=$rs \
		$TESTPOOL $pool_type $HDD_DISKS \
		special $SSD_DISKS
	log_must $ZPOOL set wrc_mode=$wrc_mode $TESTPOOL
	log_must display_status $TESTPOOL
	log_mustnot $ZPOOL detach $TESTPOOL $SSD_DISK1
	log_must $ZPOOL scrub $TESTPOOL
	while is_pool_scrubbing $TESTPOOL ; do
		$SLEEP 1
	done
	log_must check_pool_errors $TESTPOOL
	log_must destroy_pool $TESTPOOL
done
log_pass "Non-redundant wrc vdev can not be detached."
