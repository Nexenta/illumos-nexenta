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
# ident	"@(#)tc_move_share.ksh	1.5	08/06/11 SMI"
#

tet_startup="startup"
tet_cleanup="cleanup"

#
# move003 - Disable this test for now until support is put into sharemgr
# move004 - Disable this test for now until support is put into sharemgr
#

iclist="ic1 ic2 ic5 ic6 ic7 ic8 ic9 ic10"
ic1="move001"
ic2="move002"
ic3="move003"
ic4="move004"
ic5="move005"
ic6="move006"
ic7="move007"
ic8="move008"
ic9="move009"
ic10="move010"

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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/move/tp_move_010

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
