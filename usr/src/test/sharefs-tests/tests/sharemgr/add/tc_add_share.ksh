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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_add_share.ksh	1.5	08/06/12 SMI"
#

#
# add-share test case
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9"
ic1="add001"
ic2="add002"
ic3="add003"
ic4="add004"
ic5="add005"
ic6="add006"
ic7="add007"
ic8="add008"
ic9="add009"

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/add/tp_add_009

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

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh

