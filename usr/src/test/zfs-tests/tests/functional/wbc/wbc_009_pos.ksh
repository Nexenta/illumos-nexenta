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
# Copyright 2016 Nexenta Systems, Inc. All rights reserved.
#

. $STF_SUITE/tests/functional/wbc/wbc.cfg
. $STF_SUITE/tests/functional/wbc/wbc.kshlib

#
# DESCRIPTION:
#	Detaching redundant special vdev succeeds
#
# STRATEGY:
#	1. Create pool with mirrored special devices and enabled/disabled write
#	   back cache
#	2. Display pool status
#	3. Try to detach one special vdev
#	4. Display pool status
#	5. Scrub pool and check status
#

verify_runnable "global"
log_assert "Detaching redundant special vdev succeeds."
log_onexit cleanup
for wbc_mode in "none" "on" ; do
	log_must create_pool_special $TESTPOOL $wbc_mode "mirror" "mirror"
	log_must display_status $TESTPOOL
	log_must zpool detach $TESTPOOL $SSD_DISK1
	log_must zpool scrub $TESTPOOL
	while is_pool_scrubbing $TESTPOOL ; do
		sleep 1
	done
	log_must check_pool_errors $TESTPOOL
	log_must destroy_pool $TESTPOOL
done
log_pass "Detaching redundant special vdev succeeds."