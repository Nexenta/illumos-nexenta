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
# mkdir test case
#

. ${CTI_SUITE}/config/config


ic1="mkdir001"
ic2="mkdir002"
ic3="mkdir003"
ic4="mkdir004"
ic5="mkdir005"
ic6="mkdir006"

iclist="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6"
test_list="$iclist"

. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_001
. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_002
. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_003
. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_004
. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_005
. ${CTI_SUITE}/tests/smbfs/mkdir/tp_mkdir_006

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
