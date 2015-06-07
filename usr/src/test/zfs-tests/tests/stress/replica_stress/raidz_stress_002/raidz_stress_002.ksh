#!/usr/bin/ksh -p
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
# ident	"@(#)raidz_stress_002.ksh	1.1	07/10/09 SMI"
#

. ${STF_SUITE}/include/libtest.shlib
. ${STF_SUITE}/tests/stress/replica_stress/replica_stress_common.kshlib

###############################################################################
#
# __stc_assertion_start
#
# ID: raidz_stress_002
#
# DESCRIPTION:
#	Running multiple copies of dataset_create_write_destroy,
#	dataset_create_write_destroy_attr and dataset_xattr on separate 
#	raidz pools. Create new filesystem and write file at the same time.
# 	At the same time, synchronize it every 10 seconds.
#	The system shall not cause the system to fail, hang or panic.
#
# STRATEGY:
#	1. Setup phase will have created several raidz pools
#	2. Multiple copies of dataset_create_write_destroy are fired off
#	   one per pool in the background.
#	3. Multiple copies of dataset_create_write_destroy_attr are filed off
#	   one per pool in the background.
# 	4. Multiple copies of dataset_xattr are filed off one per pool in the
# 	   background.
#	5. Create three datasets in each pool and start writing files in
#	   background.
#	6. Wait for 30 seconds, then repeat the operation at step 2 - 7.
#	7. Start writing to the same files, making holes in those files in
#	   background.
#	8. Sync every 10 seconds.
#	9. Wait for our stress timeout value to finish, and kill any remaining
#          tests. The test is considered to have passed if the machine stays up
#	   during the time the stress tests are running and doesn't hit the stf
#	   time limit.
#
# TESTABILITY: explicit
#
# TEST_AUTOMATION_LEVEL: automated
#
# CODING_STATUS: COMPLETED (2006-06-08)
#
# __stc_assertion_end
#
###############################################################################

log_assert "parallel dataset_create_write_destroy, " \
	"dataset_create_write_destroy_attr , dataset_run_xattr " \
	"create separated filesystem and create files on them." \
	"Then synchronize per 10 seconds won't fail"

function regular_sync #<seconds>
{
	typeset -i timeout=$1

	while true; do
		$SLEEP $timeout
		$SYNC
	done

	exit 0
}

log_onexit cleanup

typeset pool=
typeset child_pids=

for pool in $(get_pools); do
	log_note "$CREATE_WRITE_DESTROY_SCRIPT $pool"
	$CREATE_WRITE_DESTROY_SCRIPT $pool > /dev/null 2>&1 &
	child_pids="$child_pids $!"

	log_note "$CREATE_WRITE_DESTROY_EXATTR_SCRIPT $pool"
	$CREATE_WRITE_DESTROY_EXATTR_SCRIPT $pool > /dev/null 2>&1 &
	child_pids="$child_pids $!"

	log_note "$DATASET_RUN_XATTR_SCRIPT $pool "
	$DATASET_RUN_XATTR_SCRIPT $pool > /dev/null 2>&1 &
	child_pids="$child_pids $!"

	create_write_fs $pool $loop
done

regular_sync 10 > /dev/null 2>&1 &
typeset sync_pid=$!

#
# Monitor stress processes until they exit or timed out
#
stress_timeout $STRESS_TIMEOUT $child_pids
$KILL -9 $sync_pid

log_pass
