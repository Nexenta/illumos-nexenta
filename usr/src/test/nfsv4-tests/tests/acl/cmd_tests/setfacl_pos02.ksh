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
# ACL setfacl/getfacl positive basic test
#     Call setfacl(1) modify 'users' in the ACL entries to a
#     directory; then verify ACLs are set correctly with getfacl(1).
#

if [ -z "$DEBUG" ]; then
    export DEBUG=0 
else
    [ "$DEBUG" != "0" ] && set -x
fi

NAME=`basename $0`
CDIR=`pwd`

# Source for common functions
. $CDIR/ACL.utils

# Preparation: create temp file/directory for testing 
# Assume MNTPTR is the base test directory.
TDIR=$MNTPTR/$NAME.dir.$$
EFILE=$TMPDIR/$NAME.err.$$

function test_setup
{
    [ "$DEBUG" != "0" ] && set -x
    echo "\n" > $EFILE
    mkdir -m 0777 $TDIR >> $EFILE 2>&1 || return $?
}

function cleanup
{
    [ "$DEBUG" != "0" ] && set -x
    rm -fr $TDIR $EFILE $TMPDIR/$NAME.*.$$
    exit $1
}

# Test assertion driver
function run_assertion
{
    [ "$DEBUG" != "0" ] && set -x
    OP=${1}
    TOBJ=${2}
    ULIST=${3}
    WHO=$4
    CANREAD=$5

    echo "\n" > $EFILE
    set_acls $OP $TOBJ "$ULIST" $WHO || return $FAIL
    get_acls $TOBJ $TMPDIR/$NAME.ga.$$  || return $FAIL
    ULIST=$(echo $ULIST | sed 's/,/ /g')
    ck_aces $OP "$ULIST" $TMPDIR/$NAME.ga.$$ || return $FAIL
    # try to read the directory as user in ULIST
    if [ -n "$CANREAD" ]; then
	# get the user and try to read
	user=$(echo $ULIST | nawk -F\: '{print $1}')
	su $user -c "ls $TOBJ" > $TMPDIR/$NAME.ga2.$$ 2>&1
	if [[ $? -eq 0 && $CANREAD != "true" ]]; then
		echo "\t Test FAIL, user<$user> still can ls $TOBJ"
		grep $user $TMPDIR/$NAME.ga.$$
		cat $TMPDIR/$NAME.ga2.$$
		return $FAIL
	fi
    fi
    [ "$DEBUG" != "0" ] && cat $TMPDIR/$NAME.ga2.$$
	
    echo "\t Test PASS"

}

# Start main program here:
# ----------------------------------------------------------------------
test_setup
if [ $? -ne 0 ]; then
    echo "$NAME{setup}: preparation for $NAME test"
    echo "\t UNINITIATED - no assertions will be run"
    cat $EFILE
    cleanup $UNINITIATED
fi

# Assertions
# ----------------------------------------------------------------------
# a: setfacl to modify/delete user & perms to a directory:
ULIST="$TUSER1:rwx $TUSER2:rw- $TUSER3:--x sys:r-x"
ASSERTION="setfacl to add <$ULIST>\n\tusers to the dir, expect successful"
echo "$NAME{a}: $ASSERTION"
run_assertion m $TDIR "$ULIST" user

# b: setfacl to modify user & perms in a dir, expect successful
ULIST="$TUSER1:r-x $TUSER3:rwx sys:rw-"
ASSERTION="setfacl to modify users <$ULIST>\n\tto the directory,"
ASSERTION="$ASSERTION expect successful"
echo "$NAME{b}: $ASSERTION"
run_assertion m $TDIR "$ULIST" user

# c: setfacl to modify mask in a directory, expect successful
ULIST="mask:-w-"
ASSERTION="setfacl to modify <$ULIST> to the dir, expect successful"
echo "$NAME{c}: $ASSERTION"
run_assertion m $TDIR $ULIST ""

# d: verify users' perms are correct after the mask changed
ULIST="$TUSER1:--- $TUSER3-w- sys:-w-"
ASSERTION="verify effective perms on dir of users \n\t<$ULIST> set correctly"
echo "$NAME{d}: $ASSERTION"
get_acls $TDIR $TMPDIR/$NAME.gd.$$ && \
	ck_aces me "$ULIST" $TMPDIR/$NAME.gd.$$ && echo "\t Test PASS" 

# e: setfacl to modify user w/all perms; but can't <ls dir> due to mask
ULIST="$TUSER2:rwx"
ASSERTION="setfacl to modify <$ULIST> to the dir; but user\n\tshould still"
ASSERTION="$ASSERTION not able to <ls> the directory due to mask set before."
echo "$NAME{e}: $ASSERTION"
run_assertion m $TDIR $ULIST user true

# f: setfacl to delete user & perms in the directory, expect successful
ULIST="$TUSER1:r-x $TUSER2:r-- $TUSER3:rwx sys:rw-"
ASSERTION="delete users <$ULIST>\n\tACLs from the directory, expect successful"
echo "$NAME{f}: $ASSERTION"
run_assertion d $TDIR "$ULIST" user


# Finally cleanup and exit
cleanup $PASS
