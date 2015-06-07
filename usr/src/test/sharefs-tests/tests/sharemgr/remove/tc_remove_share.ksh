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
# ident	"@(#)tc_remove_share.ksh	1.5	08/06/11 SMI"
#

#
# remove test case
#

tet_startup="startup"
tet_cleanup="cleanup"

iclist="ic1 ic2 ic3 ic4 ic5 ic6 ic7 ic8 ic9 ic10"
ic1="remove001"
ic2="remove002"
ic3="remove003"
ic4="remove004"
ic5="remove005"
ic6="remove006"
ic7="remove007"
ic8="remove008"
ic9="remove009"
ic10="remove010"

#
# Here we need to source the configure file and do the initial
# setup for the tests.
# 	Initial Setup steps :
#		- check environment to see if we even need to run (checkenv)
#		- check for legacy share commands and setup
#		- Create file systems 
#		
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

. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_001
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_002
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_003
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_004
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_005
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_006
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_007
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_008
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_009
. ${TET_SUITE_ROOT}/sharefs-tests/tests/sharemgr/remove/tp_remove_010

. ${TET_SUITE_ROOT}/sharefs-tests/lib/share_common

. ${TET_ROOT}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
