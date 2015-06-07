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
# ident	"@(#)tc_set_security.ksh	1.5	08/06/11 SMI"
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10 ic11 ic12 ic13 ic14 ic15"
ic1="security001"
ic2="security002"
ic3="security003"
ic4="security004"
ic5="security005"
ic6="security006"
ic7="security007"
ic8="security008"
ic9="security009"
ic10="security010"
ic11="security011"
ic12="security012"
ic13="security013"
ic14="security014"
ic15="security015"

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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_010
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_011
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_012
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_013
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_014
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/set_security/tp_set_security_015

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
