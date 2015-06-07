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
# ident	"@(#)tc_disable_share.ksh	1.5	08/06/12 SMI"
#

#
# Disable test case
#

tet_startup="startup"
tet_cleanup="cleanup"

#
# ic9 Removing test because there is not a case where no groups exist.
#

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic10 ic11"
ic1="disable001"
ic2="disable002"
ic3="disable003"
ic4="disable004"
ic5="disable005"
ic6="disable006"
ic7="disable007"
ic8="disable008"
ic9="disable009"
ic10="disable010"
ic11="disable011"

function startup {
        tet_infoline "Checking environment and runability"
        share_startup
}

function cleanup {
        share_cleanup
}

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_010
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/disable/tp_disable_011

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
