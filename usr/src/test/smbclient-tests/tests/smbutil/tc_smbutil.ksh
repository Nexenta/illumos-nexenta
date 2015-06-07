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
# smbutil test case
#

. ${CTI_SUITE}/config/config

ic1="smbutil001"
ic2="smbutil002"
ic3="smbutil003"
ic4="smbutil004"
ic5="smbutil005"
ic6="smbutil006"
ic7="smbutil007"
ic8="smbutil008"
ic9="smbutil009"
ic10="smbutil010"
ic11="smbutil011"
ic12="smbutil012"
ic13="smbutil013"
ic14="smbutil014"
ic15="smbutil015"
ic16="smbutil016"

iclist="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6 $ic7 $ic8 $ic9 $ic10"
test_list="$iclist $ic11 $ic12 $ic13 $ic14 $ic15 $ic16"

. ${CTI_SUITE}/tests/smbutil/tp_smbutil_001
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_002
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_003
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_004
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_005
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_006
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_007
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_008
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_009
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_010
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_011
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_012
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_013
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_014
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_015
. ${CTI_SUITE}/tests/smbutil/tp_smbutil_016

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
