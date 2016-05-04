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
# NFSv4 client name space test - mounting symlink
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`
NSPC=`echo $NAME | sed 's/./ /g'`

# Source for common functions
. $TESTROOT/testsh

# check for root to run 
is_root $NAME "NFSv4 name space tests (mount symlink)."

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
# a: Verify mounting symlink dir in a shared FS, expect succeed
function assertion_a
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink dir in a shared FS"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{a}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/$SYMLDIR/dir2

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after share" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# b: Verify mounting symlink file (w/no perm) in a shared FS, expect succeed
function assertion_b
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink file(w/no PERM) in shared FS"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{b}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink to a file with mode=0000
    SRVPATH=$BASEDIR/$SYMNOPF

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify Getattr the mount point is correct
    ls -l $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to Getattr mnt-point after share" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL
    Mode=`awk '{print $1}' $TMPDIR/$NAME.ck.$$`
    if [[ $TestZFS = 1 ]]; then
        # ACL/xattr is set for FNOPERM
        expmode="----------+"
    else
        expmode="----------"
    fi
    if [ "$Mode" != $expmode ]; then
	echo "\t Test FAIL: file mode is incorrect"
	cat $TMPDIR/$NAME.ck.$$
	umount $TMPmnt
	return $FAIL
    fi

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# c: Verify mounting symlink to nosuchdir, expect fail
function assertion_c
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to nosuch dir, expect fail"
    echo "$NAME{c}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink file
    SRVPATH=$BASEDIR/syml_nodir

    # Test it with the mount on the $SRVPATH, should fail
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mounting <$SRVPATH> did not fail"
	cat $TMPDIR/$NAME.mnt.$$
	return $FAIL
    fi

    # verify the mount point is not NFS mounted
    df -F nfs $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mount point <$TMPmnt> should not be NFS"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    echo "\t Test PASS"
}

# d: Verify mounting symlink to out-of namespace dir(usr/lib), expect fail
function assertion_d
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to out-of namespace dir(usr/lib), expect fail"
    echo "$NAME{d}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink file
    SRVPATH=$BASEDIR/syml_outns

    # Test it with the mount on the $SRVPATH, should fail
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mounting <$SRVPATH> did not fail"
	cat $TMPDIR/$NAME.mnt.$$
	return $FAIL
    fi

    # verify the mount point is not NFS mounted
    df -F nfs $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mount point <$TMPmnt> should not be NFS"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    echo "\t Test PASS"
}

# e: Verify mounting symlink to file in unshared cross-mount, expect fail
# XXX this assertion may need to change when client cross-mount is available.
function assertion_e
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to file in unshared cross-mnt, expect fail"
    echo "$NAME{e}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink file
    SRVPATH=$BASEDIR/syml_nofile

    # Test it with the mount on the $SRVPATH, should fail
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mounting <$SRVPATH> did not fail"
	cat $TMPDIR/$NAME.mnt.$$
	return $FAIL
    fi

    # verify the mount point is not NFS mounted
    df -F nfs $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mount point should not be NFS"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    echo "\t Test PASS"
}

# h: Verify mounting symlink to another shared FS, expect succeed
function assertion_h
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to another shared FS"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{h}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/syml_sh_fs

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after share" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# i: Verify mounting symlink to a non-shared FS w/in shared node, expect succeed
# XXX this assertion may need to change when client cross-mount is available.
function assertion_i
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to non-shared FS in shared node, expect succeed"
    echo "$NAME{i}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink file
    SRVPATH=$BASEDIR/syml_nosh_fs

    # Test it with the mount on the $SRVPATH, should OK as a dir
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify client can't create file in it
    touch $TMPmnt/testfile.$$ > $TMPDIR/$NAME.ck.$$ 2>&1
    if [ $? -eq 0 ]; then
	echo "\t Test FAIL: mount point should not be writable"
	cat $TMPDIR/$NAME.ck.$$
	return $FAIL
    fi

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# m: Verify mounting symlink dir w/relative path, expect succeed
function assertion_m
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink dir with relative path"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{m}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/syml_dotd

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after unshare" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# n: Verify mounting symlink file w/relative path (. & ..), expect succeed
function assertion_n
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink file w/relative path (. & ..)"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{n}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/syml_dotf

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after unshare" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# o: Verify mounting symlink dir w/.. of shared inside shared FS, expect succeed
function assertion_o
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink dir w/.. of shared inside shared FS"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{o}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/syml_dotdot

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after unshare" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckreturn $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
}

# p: Verify mounting symlink to an absolute syml in shared FS, expect succeed
function assertion_p
{
    [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
    ASSERTION="Mounting symlink to an absolute symlink in shared FS"
    ASSERTION="$ASSERTION, expect succeed"
    echo "$NAME{p}: $ASSERTION"

    if [ $allunsupp -eq 1 ]; then
	echo "\t Test UNSUPPORTED"
	return $FAIL
    fi

    # SRVPATH should be a symlink
    SRVPATH=$BASEDIR/symldir2

    # Test it with the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckreturn $? "mount <vers=4,rw $SERVER:$SRVPATH> failed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls -lL $TMPmnt > $TMPDIR/$NAME.ck.$$ 2>&1
    ckreturn $? "unable to access the mnt-point after unshare" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && return $FAIL

    # umount it
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
assertion_d
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_e
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_h
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_i
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_m
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_n
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_o
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1
assertion_p
[ $? -ne 0 ] && umount -f $TMPmnt > /dev/null 2>&1


# cleanup here
rmdir $TMPmnt
rm -f $TMPDIR/$NAME.*.$$

exit 0
