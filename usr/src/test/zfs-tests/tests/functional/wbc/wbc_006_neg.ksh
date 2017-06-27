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
# Copyright 2017 Nexenta Systems, Inc.
#

. $STF_SUITE/tests/functional/wbc/wbc.cfg
. $STF_SUITE/tests/functional/wbc/wbc.kshlib

#
# DESCRIPTION:
#	A raidz special is not supported
#
# STRATEGY:
#	1. Try to create pool with unsupported vdev type
#	2. Creating pool must fail
#

verify_runnable "global"
log_assert "A raidz special is not supported."
log_onexit cleanup
for pool_type in "stripe" "mirror" ; do
	for special_type in "raidz" "raidz2" "raidz3" ; do
		for wbc_mode in "none" "on" ; do
			log_mustnot create_pool_special $TESTPOOL $wbc_mode \
			    $pool_type $special_type
		done
	done
done
log_pass "A raidz special is not supported."
