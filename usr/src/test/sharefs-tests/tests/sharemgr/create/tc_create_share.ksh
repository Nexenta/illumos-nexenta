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
# ident	"@(#)tc_create_share.ksh	1.5	08/06/11 SMI"
#

#
# create-share test case
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11 ic12 ic13"
ic1="create001"
ic2="create002"
ic3="create003"
ic4="create004"
ic5="create005"
ic6="create006"
ic7="create007"
ic8="create008"
ic9="create009"
ic10="create010"
ic11="create011"
ic12="create012"
ic13="create013"

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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_010
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_011
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_012
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/create/tp_create_013

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
