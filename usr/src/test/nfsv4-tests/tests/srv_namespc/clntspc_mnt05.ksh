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

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv4 name space tests (mount root)."

TMPmnt=/$NAME.$$
mkdir -m 0777 $TMPmnt


# Start test assertions here
# ----------------------------------------------------------------------
# a: Verify client can mount '/', expect successful
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify client can mount '/', expect successful"
    echo "$NAME{a}: $ASSERTION"

    # try to mount on the $SERVER '/'
    SRVPATH="/"
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount root did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lt $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # should at least see the first node of $BASEDIR
    EXP=`echo "$BASEDIR" | nawk -F\/ '{print $2}'`
    grep "$EXP" $TMPDIR/$NAME.ck.$$ > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
    	echo "\tTest FAIL: did not see the first node" 
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    # Finally umount and done
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# b: Verify client can mount '/' with public, expect successful
function assertion_b
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify client can mount '/' with public, expect successful"
    echo "$NAME{b}: $ASSERTION"

    # try to mount on the $SERVER '/' w/public option
    SRVPATH="/"
    mount -o vers=4,public $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount root did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lt $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL
    (cd $TMPmnt/$DIR0777; pwd; cd $CDIR) > $TMPDIR/$NAME.ck2.$$ 2>&1
    ckreturn $? "unable to cd into mountptr" $TMPDIR/$NAME.ck2.$$
    [ $? -ne 0 ] && return $FAIL

    # and check on an existing file under the mount ptr
    grep "$BLKFILE" $TMPDIR/$NAME.ck.$$ > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
    	echo "\tTest FAIL: did not see <$BLKFILE> inside mnt point"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    # Finally umount and done
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# Start main program here:
# ----------------------------------------------------------------------

assertion_a
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_b
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1

# cleanup tmp files
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
