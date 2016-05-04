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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
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
is_root $NAME "NFSv4 basic server name space tests."

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt

allunsupp=0
is_cipso "vers=4" $SERVER
if [ $? -eq $CIPSO_NFSV4 ]; then
	cipso_check_mntpaths $BASEDIR $TMPmnt
	if [ $? -ne 0 ]; then
		allunsupp=1
		echo "$NAME: UNSUPPORTED"
		echo "$NAME: CIPSO NFSv4 requires non-global zone mount dirs."
		echo "$NSPC  The server's BASEDIR and client's MNTPTR"
		echo "$NSPC  must contain path legs with matching"
		echo "$NSPC  non-global zone paths."
		echo "$NSPC: Please try again ..."
	fi
fi

# Start test assertions here
# ----------------------------------------------------------------------
# a: Verify v4 mount of server's exported point, expect successful
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v4 mount of server's exported point, expect successful"
    echo "$NAME{a}: $ASSERTION"
    SRVPATH=$BASEDIR

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is accessible
    ls $TMPmnt/$LARGEDIR > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access ($TMPmnt/$LARGEDIR)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# b: Verify v4 mount of dir below server's exported point, expect successful
function assertion_b
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v4 mount of dir below exported point, expect successful"
    echo "$NAME{b}: $ASSERTION"
    SRVPATH=$BASEDIR/$DIR0777

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the mount on the $SRVPATH
    mount -o vers=4,forcedirectio $SERVER:$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is accessible
    cat $TMPmnt/$RWFILE > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access ($TMPmnt/$RWFILE)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# c: Verify v4 mount of dir above server's exported point, expect successful
function assertion_c
{
    [[ -n "$DEBUG" ]] && [[ "$DEBUG" != "0" ]] && set -x
    ASSERTION="Verify v4 mount of dir above exported point, expect successful"
    echo "$NAME{c}: $ASSERTION"
    MNTPATH=$(dirname $BASEDIR)
    SRVPATH=$TMPmnt/$(basename $BASEDIR)

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the mount on the $MNTPATH
    mount -o vers=4,noac,rw $SERVER:$MNTPATH/ $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    (( $? != 0 )) && return $FAIL

    # verify the mount point is accessible
    ls -al $TMPmnt |grep $(basename $BASEDIR) > $TMPDIR/$NAME.ls.$$ 2>&1
    ckreturn $? \
    "unable to list the content of the mount point ($TMPmnt)" \
    $TMPDIR/$NAME.ls.$$
    (( $? != 0 )) && return $FAIL

    if (( TestZFS == 0 )); then
	# verify the shared dir on server is writable
	touch $SRVPATH/file > $TMPDIR/$NAME.touch.$$ 2>&1
	ckreturn $? \
	"unable to create file on child dir of mounted filesystem ($SRVPATH)" \
	$TMPDIR/$NAME.touch.$$
	(( $? != 0 )) && return $FAIL

	# verify the shared dir on server is access'ble
	ls -al $SRVPATH |grep file > $TMPDIR/$NAME.ls.$$ 2>&1
	ckreturn $? \
	"unable to list the content of child dir of mounted filesystem \
	($SRVPATH)" \
	$TMPDIR/$NAME.ls.$$
	(( $? != 0 )) && return $FAIL
    fi

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    (( $? != 0 )) && return $FAIL

    echo "\t Test PASS"
}


# Start main program here:
# ----------------------------------------------------------------------

assertion_a
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_b
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_c
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1

# cleanup here
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
