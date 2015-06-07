#! /usr/bin/ksh -p
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_zfs_share.ksh	1.6	09/08/01 SMI"
#

#
# zfs-share test case
#

tet_startup="startup"
tet_cleanup="cleanup"

#
# Leaving ic3 disabled for now because of the bad state things
# can get in until a potential fix is provided and then will
# enable.
#
iclist="ic1 ic2 ic4 ic5"
ic1="zfs001"
ic2="zfs002"
ic3="zfs003"
ic4="zfs004"
ic5="zfs005"

function startup
{
	tet_infoline "Checking environment and runability"
	share_startup
}

function cleanup
{
	tet_infoline "Cleaning up after tests"
	share_cleanup
}

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zfs/tp_zfs_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zfs/tp_zfs_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zfs/tp_zfs_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zfs/tp_zfs_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/zfs/tp_zfs_005

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
