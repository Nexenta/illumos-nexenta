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
# ACL setfacl/getfacl negative basic test
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
    CKLIST=$4

    echo "\n" > $EFILE
    for ac in $ULIST
    do
	CMD="setfacl -$OP $ac $TOBJ" 
	$CMD > $EFILE 2>&1
	if [ $? -eq 0 ]; then
		echo "\t Test FAIL: <$CMD> did not fail"
		cat $EFILE
		return $FAIL
	fi
	[ "$DEBUG" != "0" ] && echo "CMD=<$CMD>" && cat $EFILE
    done
    get_acls $TOBJ $TMPDIR/$NAME.ga.$$  || return $FAIL
    [ -n "$CKLIST" ] && ULIST=$CKLIST
    ULIST=$(echo $ULIST | sed 's/,/ /g')
    ck_aces m "$ULIST" $TMPDIR/$NAME.ga.$$ || return $FAIL
    [ "$DEBUG" != "0" ] && cat $TMPDIR/$NAME.ga.$$
	
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
# a: setfacl to delete default user/group/other of a dir
if [[ $TestZFS == 1 ]]; then
	ULIST="user::rwx group::rwx"
else
	ULIST="user::rwx group::rwx other:rwx"
fi
ASSERTION="setfacl to delete these ACLs:\n\t<$ULIST> on a dir; expect fail"
echo "$NAME{a}: $ASSERTION"
run_assertion d $TDIR "$ULIST" ""

# b: reset the ACLs in dir with no user for owner
ULIST="group::rwx other:rwx"
ASSERTION="setfacl to reset ACLs in a dir w/no user owner:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{b}: $ASSERTION"
run_assertion s $TDIR "$ULIST" ""

# c: reset the ACLs in dir with no group for owner
ULIST="user::rwx other:rwx"
ASSERTION="setfacl to reset ACLs in a dir w/no group owner:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{c}: $ASSERTION"
run_assertion s $TDIR "$ULIST" ""

# d: reset the ACLs in dir with no other entry
ULIST="user::rwx group::rwx"
ASSERTION="setfacl to reset ACLs in a dir w/no other entry:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{d}: $ASSERTION"
run_assertion s $TDIR "$ULIST" ""

# e: reset the ACLs in dir w/additional user, but not mask
ULIST="user::rwx,group::rwx,other:rwx,user:$TUSER1:rwx"
ASSERTION="setfacl to reset ACLs in a dir w/additional user, but not\n\t"
ASSERTION="$ASSERTION mask: <$ULIST>, expect fail"
echo "$NAME{e}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx"

# f: reset the ACLs in dir w/two same users
ULIST="user::rwx,group::rwx,other:rwx,mask:rwx"
ULIST="$ULIST,user:$TUSER2:rwx,user:$TUSER2:rwx"
ASSERTION="setfacl to reset ACLs in a dir w/two same users, \n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{f}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx,mask:rwx"

# g: reset the ACLs in dir w/two same group
ULIST="user::rwx,group::rwx,other:rwx,mask:rwx"
ULIST="$ULIST,group:bin:r-x,group:bin:rwx"
ASSERTION="setfacl to reset ACLs in a dir w/two same group, \n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{g}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx,mask:rwx"

# h: reset the ACLs in dir w/two default users
ULIST="user::rwx,group::rwx,other:rwx,mask:rwx"
ULIST="$ULIST,default:user:$TUSER1:r-x,default:user:$TUSER2:--x"
ASSERTION="setfacl to reset ACLs in a dir w/two default users,\n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{h}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx,mask:rwx"

# i: reset the ACLs in dir w/two default groups
ULIST="user::rwx,group::rwx,other:rwx,mask:rwx"
ULIST="$ULIST,default:group:sys:r-x,default:group:sys:--x"
ASSERTION="setfacl to reset ACLs in a dir w/two default groups,\n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{i}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx,mask:rwx"

# j: reset the ACLs in dir w/two default mask entries
ULIST="user::rwx,group::rwx,other:rwx,mask:rwx"
ULIST="$ULIST,default:mask:r-x,default:mask:--x"
ASSERTION="setfacl to reset ACLs in a dir w/two default mask entries,\n"
ASSERTION="$ASSERTION    <$ULIST>\n\texpect fail"
echo "$NAME{j}: $ASSERTION"
run_assertion s $TDIR "$ULIST" "user::rwx,group::rwx,other:rwx,mask:rwx"


# Finally cleanup and exit
cleanup $PASS
