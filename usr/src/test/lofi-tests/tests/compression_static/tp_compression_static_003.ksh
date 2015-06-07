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
# ident	"@(#)tp_compression_static_003.ksh	1.2	08/12/19 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common
. ${TET_SUITE_ROOT}/lofi-tests/lib/util_common

#
# start __stc_assertion__
#
# ASSERTION: compression_static_003
#
# DESCRIPTION
#	When a zero-length file is compressed via lofiadm using the 'gzip'
#	compression type, the size should stay zero when compressed and
#	following subsequent decompression.
#
# STRATEGY:
#	Setup
#		- Create a file of zero size
#	Assert
#		- Compress the file using 'lofiadm -C gzip'
#		- Verify file size remains at zero.
#		- Decompress the file using 'lofiadm -U'
#		- Verify file size remains at zero.
#	Cleanup
#		- Remove the file
#
# end __stc_assertion__
#
function tp_compression_static_003 {
	typeset -r ME=$(whence -p ${0})
	zero_size_test 003 gzip $ME
}
