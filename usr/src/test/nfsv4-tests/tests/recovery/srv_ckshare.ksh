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
# simple setuid program to do share/unshare at SERVER
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`

# It's assumed that env. variables (SERVER, TESTROOT, TMPDIR) are set
. $TESTROOT/testsh

# check for root to run 
is_root $NAME

if [ $# -lt 1 ]; then
	echo "Usage: $NAME action(share|unshare)"
	exit 1
fi

ACTION=$1

# setup the command based on the ACTION
case $ACTION in
	share)
		CMD="/usr/sbin/shareall" ;;
	unshare)
		CMD="/usr/sbin/unshareall" ;;
	*)
                echo "Unknow action=$ACTION, try [share|unshare]"
                exit 5
esac


echo "$NAME: Calling $CMD at $SERVER ... \c"
execute $SERVER root $CMD > $TMPDIR/$NAME.exe.$$ 2>&1
if [ $? -ne 0 ]; then 
	echo "FAIL"
	echo "$NAME: failed to run $CMD at $SERVER"
	cat $TMPDIR/$NAME.exe.$$
	exit 10
fi

echo "OK"
rm -f $TMPDIR/$NAME.*.$$
exit 0
