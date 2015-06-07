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
# smbmount test case
#
. ${CTI_SUITE}/config/config

ic1="smbmount001"
ic2="smbmount002"
ic3="smbmount003"
ic4="smbmount004"
ic5="smbmount005"
ic6="smbmount006"
ic7="smbmount007"
ic8="smbmount008"
ic9="smbmount009"
ic10="smbmount010"
ic11="smbmount011"
ic12="smbmount012"
ic13="smbmount013"
ic14="smbmount014"
ic15="smbmount015"
ic16="smbmount016"

iclist="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6 $ic7 $ic8"
test_list="$iclist $ic9 $ic10 $ic11 $ic12 $ic13 $ic14 $ic15 $ic16"

. ${CTI_SUITE}/tests/smbmount/tp_smbmount_001
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_002
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_003
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_004
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_005
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_006
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_007
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_008
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_009
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_010
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_011
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_012
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_013
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_014
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_015
. ${CTI_SUITE}/tests/smbmount/tp_smbmount_016

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
