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
# Verify NFsv2/v3 clients unable to crossing NFSv4 server mount points 
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv2/v3 client crossing server mount points tests."

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt

# in case user wants to run IPv6
[[ $TRANSPORT == *6 ]] && tUDP=udp6 || tUDP=udp

# Start test assertions here
# ----------------------------------------------------------------------
# a: Verify v2 mount of server's exported point, expect successful
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v2 mount of server's exported point, expect successful"
    echo "$NAME{a}: $ASSERTION"
    SRVPATH=$BASEDIR

    is_cipso "vers=2" $SERVER
    if [ $? -eq $CIPSO_NFSV2 ]; then
        echo "$NAME{a}: CIPSO NFSv2 is not supported under Trusted Extensions."
	echo "\t Test UNSUPPORTED"
        return $FAIL
    fi

    # Do the mount on the $SRVPATH
    mount -o vers=2,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls $TMPmnt/$LARGEDIR > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access ($TMPmnt/$LARGEDIR)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# b: Verify v3 mount of dir below server's exported point, expect successful
function assertion_b
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v3 mount of dir below exported point, expect successful"
    echo "$NAME{b}: $ASSERTION"
    SRVPATH=$BASEDIR/$DIR0777

    # Do the mount on the $SRVPATH
    mount -o vers=3,proto=$tUDP $SERVER:$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    cat $TMPmnt/$RWFILE > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access ($TMPmnt/$RWFILE)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# c: Verify v3 mount of dir above server's exported point, expect fail
function assertion_c
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Verify v3 mount of dir above exported point, expect fail"
    echo "$NAME{c}: $ASSERTION"
    SRVPATH=`dirname $BASEDIR`

    # Do the mount on the $SRVPATH
    mount -o vers=3,noac,ro $SERVER:$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    if [ $? -eq 0 ]; then
    	echo "\t Test FAIL: mount v3 succeeded above exported point"
	return $FAIL
    fi
	
    # should not be mounted umount it
    df $TMPmnt | grep $SERVER > /dev/null 2>&1
    if [ $? -eq 0 ]; then
    	echo "\t Test FAIL: mount failed, but ($TMPmnt) is mounted"
	umount $TMPmnt > /dev/null 2>&1
	return $FAIL
    fi

    echo "\t Test PASS"
}


# d: Verify public v3 mount of dir below exported point, expect successful
function assertion_d
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="public v3 mount of dir below exported point, expect successful"
    echo "$NAME{d}: $ASSERTION"
    SRVPATH=$PUBTDIR/$DIR0777

    # Do the mount on the $SRVPATH
    mount -o vers=3,proto=$tUDP nfs://$SERVER$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount nfsURL did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    cat $TMPmnt/$RWFILE > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access ($TMPmnt/$RWFILE)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}


# e: Verify public v3 mount of dir above server's exported point, expect fail
#    if the dir is not "/", otherwise, expect successful
function assertion_e
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    SRVPATH=`dirname $BASEDIR`
    [[ $SRVPATH == "/" ]] && expres="successful" || expres="fail"
    ASSERTION="Public v3 mount of dir above exported point, expect $expres"
    echo "$NAME{e}: $ASSERTION"

    # Do the mount on the $SRVPATH
    mount -o vers=3,noac,ro nfs://$SERVER$SRVPATH $TMPmnt \
	> $TMPDIR/$NAME.mnt.$$ 2>&1
    typeset ret=$?
    if [[ $SRVPATH == "/" ]]; then
	ckreturn $ret "mount nfsURL did not succeed" $TMPDIR/$NAME.mnt.$$
	[ $? -ne 0 ] && return $FAIL

	# verify the mount point is access'ble
	cat $TMPmnt/$ROFILE > $TMPDIR/$NAME.ck.$$ 2>&1
	ckreturn $? "unable to access ($TMPmnt/$ROFILE)" $TMPDIR/$NAME.ck.$$
	[ $? -ne 0 ] && return $FAIL

	# finally umount it
	umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
	ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
	[ $? -ne 0 ] && return $FAIL
    else
	if [ $ret -eq 0 ]; then
	    echo "\t Test FAIL: mount v3 succeeded above exported point"
	    return $FAIL
	fi
	    
	# should not be mounted umount it
	df $TMPmnt | grep $SERVER > /dev/null 2>&1
	if [ $? -eq 0 ]; then
	    echo "\t Test FAIL: mount failed, but ($TMPmnt) is mounted"
	    umount $TMPmnt > /dev/null 2>&1
	    return $FAIL
	fi
    fi

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
assertion_d
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_e
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1

# cleanup here
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
