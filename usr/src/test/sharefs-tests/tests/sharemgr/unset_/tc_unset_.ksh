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
# ident	"@(#)tc_unset_.ksh	1.5	08/06/11 SMI"
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11 ic12"
ic1="unset001"
ic2="unset002"
ic3="unset003"
ic4="unset004"
ic5="unset005"
ic6="unset006"
ic7="unset007"
ic8="unset008"
ic9="unset009"
ic10="unset010"
ic11="unset011"
ic12="unset012"

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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_010
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_011
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/unset_/tp_unset_012

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
