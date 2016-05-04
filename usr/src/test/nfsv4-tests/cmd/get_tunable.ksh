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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# get_tunable.ksh support function
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`

if [ $# -lt 1 ]; then
	print -u 2 "Usage: $NAME kernel_symbol"
	return 1
fi

symbol=$1
Type="X"
[ $# -ge 2 ] && Type=$2
out=$(echo "$symbol/$Type" | mdb -k /dev/ksyms /dev/kmem | \
	tail -1 | sed 's/:/ /' | awk '{print $2}' 2> /dev/null)
res=$?
if [ $res = "0" ]; then
	echo $out
fi
return $res
