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
# NFSv4 quota query with quota(1M) and rquotad(1M)
# Require root permission to mount the FS w/quota setup.
#
# Since quota(1M) is to display user quota for UFS filesystem only,
# all tests will return UNSUPPORTED if run from an NFSv4/ZFS filesystem,
# as ZFS supports different kind of quota.

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`

if [ $TestZFS -eq 1 ]; then
	echo "$NAME{all}: v4 client quota(1M) query test."
	echo "\t Test UNSUPPORTED: current TESTDIR is ZFS, doesn't\c"
	echo " support quota(1M)."
	exit $UNSUPPORTED
fi

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "$NAME{all}: v4 client quota query test."
	echo "\t Test UNINITIATED: need root permission to mount FS \c"
	echo "w/quota setup."
	exit $UNINITIATED
fi

# proc to check result and print out failure messages 
# ckres rc message cat_file
function ckres
{
    rc=$1
    msg=${2}
    cf=${3}

    if [ $rc -ne 0 ]; then
	echo "\t Test FAIL: $msg"
	[ -f $cf ] && cat $cf
    fi
    return $rc
}

TMPmnt=$ZONE_PATH/$NAME.$$
mkdir -m 0777 -p $TMPmnt


# Start test assertions here
# ----------------------------------------------------------------------
# a: query user's quota on v4 server's FS, expect successful
function assertion_a
{
    ASSERTION="query user's quota on v4 server's FS, expect successful"
    echo "$NAME{a}: $ASSERTION"
    SRVPATH=$QUOTADIR

    # Do the mount on the $SRVPATH
    mount -o vers=4,rw $SERVER:$SRVPATH $TMPmnt > $TMPDIR/$NAME.mnt.$$ 2>&1
    ckres $? "mount did not succeed" $TMPDIR/$NAME.mnt.$$
    [ $? -ne 0 ] && return $FAIL

    # verify the mount point is access'ble
    ls $TMPmnt/$DIR0777 > $TMPDIR/$NAME.ck.$$ 2>&1
    ckres $? "unable to access ($TMPmnt/$DIR0777)" $TMPDIR/$NAME.ck.$$
    [ $? -ne 0 ] && (umount -f $TMPmnt; return $FAIL)

    # now query quota for user $TUSER2:
    su $TUSER2 -c "quota -v" > $TMPDIR/$NAME.quota.$$ 2>&1
    ckres $? "quota query for $TUSER2 failed" $TMPDIR/$NAME.quota.$$
    [ $? -ne 0 ] && (umount -f $TMPmnt; return $FAIL)
    awk '{ \
	if (NF == 1) print $1; \
	else if ($1 ~ /[0-9][0-9]*/) {printf("%s %s\n"), $3, $NF}; \
    }' $TMPDIR/$NAME.quota.$$ > $TMPDIR/$NAME.q2.$$
    echo "$TMPmnt\n5 5" > $TMPDIR/$NAME.q3.$$
    diff $TMPDIR/$NAME.q2.$$ $TMPDIR/$NAME.q3.$$ > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "\t Test FAIL: quota value received not correct"
	cat $TMPDIR/$NAME.quota.$$
	umount -f $TMPmnt; return $FAIL
    fi

    # finally umount it
    umount $TMPmnt > $TMPDIR/$NAME.umnt.$$ 2>&1
    ckres $? "umount failed" $TMPDIR/$NAME.umnt.$$
    [ $? -ne 0 ] && return $FAIL

    echo "\t Test PASS"
    return $PASS
}



# Start main program here:
# ----------------------------------------------------------------------

assertion_a
rc=$?

# cleanup here
[ $rc -eq $PASS ] && rm -fr $TMPmnt $TMPDIR/$NAME.*.$$

exit 0
