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
# Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
#

#
# ACL test cases
#

. ${CTI_SUITE}/config/config

ic1="acl001"
ic2="acl002"
ic3="acl003"
ic4="acl004"
ic5="acl005"

test_list="$ic1 $ic2 $ic3 $ic4 $ic5"

. ${CTI_SUITE}/tests/smbfs/acl/tp_acl_001
. ${CTI_SUITE}/tests/smbfs/acl/tp_acl_002
. ${CTI_SUITE}/tests/smbfs/acl/tp_acl_003
. ${CTI_SUITE}/tests/smbfs/acl/tp_acl_004
. ${CTI_SUITE}/tests/smbfs/acl/tp_acl_005

. ${CTI_SUITE}/include/services_common.ksh
. ${CTI_SUITE}/include/smbutil_common.ksh
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/smbmount_common.ksh

. ${CTI_ROOT:?}/lib/ctilib.ksh
