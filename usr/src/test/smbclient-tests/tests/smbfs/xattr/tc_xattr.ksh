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
# xattr test case
#

. ${CTI_SUITE}/config/config

tet_startup="startup"
tet_cleanup="cleanup"

ic1="xattr_001"
ic2="xattr_002"
ic3="xattr_003"
ic4="xattr_004"
ic5="xattr_005"
ic6="xattr_006"
ic7="xattr_007"
ic8="xattr_008"
ic9="xattr_009"

test_list="$ic1 $ic2 $ic3 $ic4 $ic5 $ic6 $ic7 $ic8 $ic9 $ic10"

startup() {
set -x
	cti_report "In startup"
	mkdir -m 777  $TMNT
 	/usr/bin/mkdir -p -m 777  $TESTDIR
	/usr/bin/mkdir -p -m 777  $TESTDIR1
	log_must umount -f  $TMNT
set +x

}

cleanup() {
set -x
       cti_report "In cleanup"
 	/usr/bin/rm -rf  $TESTDIR
	/usr/bin/rm -rf  $TESTDIR1
set +x

}


. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_001
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_002
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_003
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_004
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_005
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_006
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_007
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_008
. ${CTI_SUITE}/tests/smbfs/xattr/tp_xattr_009

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh
. ${CTI_SUITE}/include/xattr_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
