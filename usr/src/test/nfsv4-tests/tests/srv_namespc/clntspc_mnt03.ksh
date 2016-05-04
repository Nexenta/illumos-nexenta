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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 client name space test - positive tests
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`
NSPC=`echo $NAME | sed 's/./ /g'`

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv4 server name space (path) tests."

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt


# Start test assertions here
# ----------------------------------------------------------------------
# a: Verify pseudo path still work if mid-node is unshared, expect successful
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify pseudo path still work if mid-node is unshared"
    ASSERTION="$ASSERTION, expect successful"
    echo "$NAME{a}: $ASSERTION"
    # The SRVPATH should couple mounted-on exported point
    SRVPATH=$SSPCDIR3

    is_cipso "vers=4" $SERVER
    if [ $? -eq $CIPSO_NFSV4 ]; then
	cipso_check_mntpaths $BASEDIR $TMPmnt
	if [ $? -ne 0 ]; then
		allunsupp=1
		echo "$NAME: CIPSO NFSv4 requires non-global zone mount dirs."
		echo "$NSPC  The server's BASEDIR and client's MNTPTR"
		echo "$NSPC  must contain path legs with matching"
		echo "$NSPC  non-global zone paths."
		echo "$NSPC: Please try again ..."
		echo "\t Test UNSUPPORTED"
		return $FAIL
	fi
    fi

    # Do the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "first mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lt $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # Then go to server to unshare a mid-node of the SRVPATH
    rsh -n $SERVER "$CONFIGDIR/operate_dir unshare $SSPCDIR; \
    	/usr/sbin/share" > $TMPDIR/$NAME.ushr.$$ 2>&1
    egrep -w "$SSPCDIR" $TMPDIR/$NAME.ushr.$$ > /dev/null 2>&1
    if [ $? -eq 0 ]; then 
    	echo "\tTest FAIL: unshare failed" 
	cat $TMPDIR/$NAME.ushr.$$
	return $FAIL
    fi

    # now umount path and try again
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "first umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL
    mount -o vers=4,ro $SERVER:$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "2nd mount again did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL
    # verify the mount point is access'ble
    ls -lta $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after unshare" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # Finally umount and done
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "second umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# Start main program here:
# ----------------------------------------------------------------------

assertion_a
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1

log=$TMPDIR/rsh.out.$$
# cleanup here and reset server's share pathes
rsh -n $SERVER "$CONFIGDIR/operate_dir share $SSPCDIR" > $log

# Record share information in journal file for debugging.
grep "^SHARE" $log | grep "$SSPCDIR"

rm -rf $log
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
