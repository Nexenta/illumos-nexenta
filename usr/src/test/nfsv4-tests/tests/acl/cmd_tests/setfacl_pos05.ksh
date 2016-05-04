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
#     Call setfacl(1) modify 'groups' in the ACL entries to a file;
#     then verify ACLs are set correctly with getfacl(1).
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
    rm -fr $TFILE $EFILE $TMPDIR/$NAME.*.$$ $TMPDIR/*.err.$$
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
    ck_aces $OP "$ULIST" $TMPDIR/$NAME.ga.$$ || return $FAIL
    # try to read the file as user in another group
    if [ -n "$CANREAD" ]; then
	# get the user and try to read
	su $TUSER3 -c "cat $TOBJ" > $TMPDIR/$NAME.ga2.$$ 2>&1
	if [[ $? -eq 0 && $CANREAD != "true" ]]; then
		echo "\t Test FAIL, user<$user> still can read $TOBJ"
		grep $user $TMPDIR/$NAME.ga.$$
		cat $TMPDIR/$NAME.ga2.$$
		return $FAIL
	fi
        [ "$DEBUG" != "0" ] && cat $TMPDIR/$NAME.ga2.$$
    fi
	
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
# setfacl to modify/delete user & perms to a file:
ULIST="other:rwx staff:rw- bin:--x nobody:r-x"
ASSERTION="setfacl to add <$ULIST>\n\tgroups to the file, expect successful"
echo "$NAME{a}: $ASSERTION"
run_assertion m $TFILE "$ULIST" group

# b: setfacl to modify group & perms in a file, expect successful
ULIST="other:-w- staff:r-- bin:-wx nobody:rwx"
ASSERTION="setfacl to modify <$ULIST>\n\tgroups to the file,"
ASSERTION="$ASSERTION expect successful"
echo "$NAME{b}: $ASSERTION"
run_assertion m $TFILE "$ULIST" group

# c: setfacl to modify mask in a file, expect successful
ULIST="mask:--x"
ASSERTION="setfacl to modify <$ULIST> to the file, expect successful"
echo "$NAME{c}: $ASSERTION"
run_assertion m $TFILE $ULIST ""

# d: verify groups' perms are correct after the mask changed
ULIST="other:--- staff:--- bin:--x nobody:--x"
ASSERTION="verify effective perms on file of groups \n\t<$ULIST> set correctly"
echo "$NAME{d}: $ASSERTION"
get_acls $TFILE $TMPDIR/$NAME.gd.$$ && \
	ck_aces me "$ULIST" $TMPDIR/$NAME.gd.$$ && echo "\t Test PASS" 

# e: setfacl to modify group w/all perms; but can't read the file due to mask
ULIST="staff:rwx"
ASSERTION="setfacl to modify <$ULIST> to the file; but group\n\tshould still"
ASSERTION="$ASSERTION not able to read the file due to mask set before."
echo "$NAME{e}: $ASSERTION"
run_assertion m $TFILE $ULIST group true

# f: setfacl to delete group & perms in the file, expect successful
ULIST="other:-w- staff:rwx bin:-wx nobody:rwx"
ASSERTION="delete groups <$ULIST>\n\tACLs from the file, expect successful"
echo "$NAME{f}: $ASSERTION"
run_assertion d $TFILE "$ULIST" group


# Finally cleanup and exit
cleanup $PASS
