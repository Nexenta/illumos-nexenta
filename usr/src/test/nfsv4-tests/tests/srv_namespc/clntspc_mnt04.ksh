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
# NFSv4 client name space test - positive tests for NFS urls
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`
NSPC=`echo $NAME | sed 's/./ /g'`

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv4 name space tests with URLs."

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt

# in case user wants to run IPv6
[[ $TRANSPORT == *6 ]] && tTCP=tcp6 || tTCP=tcp

# check for cipso connection
# note that the cases in this test only verify the mount point is accessible or
# not, so it only check READ ops, there's no WRITE ops. Due to the NFSv4 url
# mount does not work well at present (please see CR 6450723), your WRITE ops
# will probably fail if you doing mount with TX+webnfs
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
# a: Verify v4 NFS url mount of server's exported FS, expect successful
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v4 NFS url mount of server's exported FS, \
		expect successful"
    echo "$NAME{a}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the NFS url mount on the $SERVER public dir
    mount -o vers=4 nfs://$SERVER/ $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
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


# b: Verify v4 NFS url mount of a file below server's exported FS,
#    expect successful
function assertion_b
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v4 NFS url mount of a file below exported FS, \
		expect successful"
    echo "$NAME{b}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the NFS url mount on the $SRVPATH
    mount -o vers=4,proto=$tTCP,public nfs://$SERVER/$ATTRFILE $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    head $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "failed to open attrfile" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# c: Verify v4 NFS url mount of .., expect successful
function assertion_c
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v4 NFS url mount of .., expect successful"
    echo "$NAME{c}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # Do the mount on the $SRVPATH
    mount -o vers=4,proto=$tTCP,ro nfs://$SERVER/$DIR0777/../$ATTRDIR \
	$TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount FS is access'ble
    ls -d@ $TMPmnt | grep '\@' > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "$TMPmnt did not come back w/attr" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
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
assertion_c
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1

# cleanup here
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
