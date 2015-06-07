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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
#

#
# cptest test case
#

. ${CTI_SUITE}/config/config

ic1="cptest001"
ic2="cptest002"
ic3="cptest003"
ic4="cptest004"
ic5="cptest005"
ic6="cptest006"
ic7="cptest007"
ic8="cptest008"
ic9="cptest009"

iclist="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6 $ic7 $ic8 $ic9"
test_list="$iclist "

. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_001
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_002
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_003
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_004
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_005
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_006
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_007
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_008
. ${CTI_SUITE}/tests/smbfs/cptest/tp_cptest_009

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
