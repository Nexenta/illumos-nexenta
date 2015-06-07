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
# ident	"@(#)tc_set_share.ksh	1.5	08/06/11 SMI"
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8"
ic1="set_share001"
ic2="set_share002"
ic3="set_share003"
ic4="set_share004"
ic5="set_share005"
ic6="set_share006"
ic7="set_share007"
ic8="set_share008"

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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_share/tp_set_share_008

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
