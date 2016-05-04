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
TFILE=$MNTPTR/$NAME.file.$$
EFILE=$TMPDIR/$NAME.err.$$

function test_setup
{
    [ "$DEBUG" != "0" ] && set -x
    echo "\n" > $EFILE
    echo "This is test file for $NAME" > $TFILE  2>> $EFILE || return $?
    chmod 0666 $TFILE >> $EFILE 2>&1 || return $?
}

function cleanup
{
    [ "$DEBUG" != "0" ] && set -x
    rm -fr $TFILE $EFILE $TMPDIR/$NAME.*.$$
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
# a: setfacl to delete default user/group/other of a file
if [[ $TestZFS == 1 ]]; then
	ULIST="user::rw- group::rw-"
else
	ULIST="user::rw- group::rw- other:rw-"
fi
ASSERTION="setfacl to delete these ACLs:\n\t<$ULIST> on a file; expect fail"
echo "$NAME{a}: $ASSERTION"
run_assertion d $TFILE "$ULIST" ""

# b: reset the ACLs in file with no user for owner
ULIST="group::rw- other:rw-"
ASSERTION="setfacl to reset ACLs in a file w/no user owner:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{b}: $ASSERTION"
run_assertion s $TFILE "$ULIST" ""

# c: reset the ACLs in file with no group for owner
ULIST="user::rw- other:rw-"
ASSERTION="setfacl to reset ACLs in a file w/no group owner:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{c}: $ASSERTION"
run_assertion s $TFILE "$ULIST" ""

# d: reset the ACLs in file with no other entry
ULIST="user::rw- group::rw-"
ASSERTION="setfacl to reset ACLs in a file w/no other entry:\n\t"
ASSERTION="$ASSERTION<$ULIST>, expect fail"
echo "$NAME{d}: $ASSERTION"
run_assertion s $TFILE "$ULIST" ""

# e: reset the ACLs in file w/additional user, but not mask
ULIST="user::rw-,group::rw-,other:rw-,user:$TUSER1:rwx"
ASSERTION="setfacl to reset ACLs in a file w/additional user, but not\n\t"
ASSERTION="$ASSERTION mask: <$ULIST>, expect fail"
echo "$NAME{e}: $ASSERTION"
run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-"

# f: reset the ACLs in file w/two same users
ULIST="user::rw-,group::rw-,other:rw-,mask:rw-"
ULIST="$ULIST,user:$TUSER2:rwx,user:$TUSER2:rwx"
ASSERTION="setfacl to reset ACLs in a file w/two same users, \n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{f}: $ASSERTION"
if [[ $TestZFS == 1 ]]; then
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rwx"
else
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rw-"
fi

# g: reset the ACLs in file w/two same group
ULIST="user::rw-,group::rw-,other:rw-,mask:rw-"
ULIST="$ULIST,group:bin:r-x,group:bin:rwx"
ASSERTION="setfacl to reset ACLs in a file w/two same group, \n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{g}: $ASSERTION"
if [[ $TestZFS == 1 ]]; then
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rwx"
else
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rw-"
fi

# h: reset the ACLs in file w/default user
ULIST="user::rw-,group::rw-,other:rw-,mask:rw-"
ULIST="$ULIST,default:user:$TUSER1:r-x"
ASSERTION="setfacl to reset ACLs in a file w/default user, \n    <$ULIST>"
ASSERTION="$ASSERTION\n\texpect fail"
echo "$NAME{h}: $ASSERTION"
if [[ $TestZFS == 1 ]]; then
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rwx"
else
	run_assertion s $TFILE "$ULIST" "user::rw-,group::rw-,other:rw-,mask:rw-"
fi

# Finally cleanup and exit
cleanup $PASS
