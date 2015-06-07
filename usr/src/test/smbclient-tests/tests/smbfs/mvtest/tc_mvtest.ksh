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
# mvtest test case
#

. ${CTI_SUITE}/config/config

ic1="mvtest001"
ic2="mvtest002"
ic3="mvtest003"
ic4="mvtest004"
ic5="mvtest005"
ic6="mvtest006"
ic7="mvtest007"

iclist="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6 $ic7"
test_list="$iclist"

. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_001
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_002
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_003
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_004
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_005
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_006
. ${CTI_SUITE}/tests/smbfs/mvtest/tp_mvtest_007

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
