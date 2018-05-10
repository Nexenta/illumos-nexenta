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
#	Creating a pool with a special device succeeds
#
# STRATEGY:
#	1. Create pool with separated special devices
#	2. Display pool status
#	3. Scrub pool and check status
#	4. Destroy and loop to create pool with different configuration
#

verify_runnable "global"
log_assert "Creating a pool with a special device succeeds."
log_onexit cleanup
for pool_type in "stripe" "mirror" "raidz" "raidz2" "raidz3" ; do
	for special_type in "stripe" "mirror" ; do
		for wbc_mode in "none" "on" ; do
			log_must create_pool_special $TESTPOOL $wbc_mode \
			    $pool_type $special_type
			log_must display_status $TESTPOOL
			log_must sync
			log_must zpool scrub $TESTPOOL
			while is_pool_scrubbing $TESTPOOL ; do
				sleep 1
			done
			log_must check_pool_errors $TESTPOOL
			log_must destroy_pool $TESTPOOL
		done
	done
done
log_pass "Creating a pool with a special device succeeds."