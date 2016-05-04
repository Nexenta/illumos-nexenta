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
#     Call setfacl(1) modify 'groups' in the ACL entries to an attribute
#     file; then verify ACLs are set correctly with getfacl(1).
#

[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

NAME=`basename $0`
CDIR=`pwd`

TESTROOT=${TESTROOT:-"$CDIR/../"}

# Source for common functions
. $CDIR/ACL.utils

# Preparation: create temp file/directory for testing 
# Assume MNTPTR is the base test directory.
TFILE=$MNTPTR/$NAME.file.$$
AFILE=$NAME.attr.$$
EFILE=$TMPDIR/$NAME.err.$$

function test_setup
{
    [[ -n $DEBUG && $DEBUG != 0 ]] && set -x

    echo "\n" > $EFILE
    echo "This is test file for $NAME" > $TFILE  2>> $EFILE || return $?
    chmod 0666 $TFILE >> $EFILE 2>&1 || return $?
    runat $TFILE "echo \"This is attribute file for $TFILE\" \
	> $AFILE" 2>> $EFILE || return $?
    runat $TFILE "chmod 0666 $AFILE" 2>> $EFILE | return $?
}

function cleanup
{
    [[ -n $DEBUG && $DEBUG != 0 ]] && set -x

    rm -fr $TFILE $EFILE $TMPDIR/$NAME.*.$$
    exit $1
}

# Test assertion driver
function run_assertion
{
    [[ -n $DEBUG && $DEBUG != 0 ]] && set -x

    OP=${1}
    TOBJ=${2}
    ULIST=${3}
    WHO=$4
    CKREAD=$5

    echo "\n" > $EFILE
    set_acls $OP $TOBJ "$ULIST" $WHO $TFILE || return $FAIL
    get_acls $TOBJ $TMPDIR/$NAME.ga.$$ $TFILE || return $FAIL
    ck_aces $OP "$ULIST" $TMPDIR/$NAME.ga.$$ || return $FAIL
    # try to read the file as group in ULIST
    if [ -n "$CKREAD" ]; then
	# get the user and try to read
	su $TUSER2 -c "runat $TFILE \"cat $TOBJ"\" > $TMPDIR/$NAME.ga2.$$ 2>&1
	case "$CKREAD" in
	    "true")
		grep "cannot" $TMPDIR/$NAME.ga2.$$ > /dev/null 2>&1
		if [ $? -ne 0 ]; then
		    echo "\t Test FAIL, user<$user> still can read $TOBJ"
		    grep $user $TMPDIR/$NAME.ga.$$
		    cat $TMPDIR/$NAME.ga2.$$
		    return $FAIL
		fi  ;;
	    "ckattr")
		grep "file for $TFILE" $TMPDIR/$NAME.ga2.$$ > /dev/null 2>&1
		if [ $? -ne 0 ]; then
		    echo "\t Test FAIL, user<$user> unable to read $TOBJ"
		    grep $user $TMPDIR/$NAME.ga.$$
		    cat $TMPDIR/$NAME.ga2.$$
		    return $FAIL
		fi  ;;
	esac
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
# a: setfacl to add group & perms to an attr file:
ULIST="other:rwx staff:rw- bin:--x nobody:r-x"
ASSERTION="setfacl to add <$ULIST>\n\tgroups to the attribute"
ASSERTION="$ASSERTION file, expect successful"
echo "$NAME{a}: $ASSERTION"
run_assertion m $AFILE "$ULIST" group

# b: setfacl to modify group & perms in an attr file, expect successful
ULIST="other:--- staff:r-- bin:-wx nobody:rwx"
ASSERTION="modify groups <$ULIST>\n\tto the attribute"
ASSERTION="$ASSERTION file, expect successful"
echo "$NAME{b}: $ASSERTION"
run_assertion m $AFILE "$ULIST" group

# c: setfacl to modify mask in an attr file, expect successful
ULIST="mask:--x"
ASSERTION="setfacl to modify <$ULIST> to attr file, expect successful"
echo "$NAME{c}: $ASSERTION"
run_assertion m $AFILE $ULIST none

# d: verify groups' perms are correct after the mask changed
ULIST="other:--- staff:--- bin:--x nobody:--x"
ASSERTION="verify effective perms on attr file of groups \n\t<$ULIST>"
ASSERTION="$ASSERTION set correctly"
echo "$NAME{d}: $ASSERTION"
get_acls $AFILE $TMPDIR/$NAME.gd.$$ $TFILE && \
	ck_aces me "$ULIST" $TMPDIR/$NAME.gd.$$ && echo "\t Test PASS" 

# e: setfacl to modify group w/all perms; but can't read the file due to mask
ULIST="staff:rwx"
ASSERTION="setfacl to modify <$ULIST> to attr file; but group\n\tshould still"
ASSERTION="$ASSERTION not able to read the file due to mask set before."
echo "$NAME{e}: $ASSERTION"
run_assertion m $AFILE $ULIST group true

# f: setfacl to modify mask in an attr file, expect successful
ULIST="mask:rw-"
ASSERTION="reset the mask <$ULIST> to attr file, expect successful"
echo "$NAME{f}: $ASSERTION"
run_assertion m $AFILE $ULIST none

# g: verify groups' perms are correct after the mask changed
ULIST="staff:rw-"
ASSERTION="verify effective perms on attr file of group \n\t<$ULIST>"
ASSERTION="$ASSERTION set correctly after mask changed."
echo "$NAME{g}: $ASSERTION"
get_acls $AFILE $TMPDIR/$NAME.gg.$$ $TFILE && \
	ck_aces me "$ULIST" $TMPDIR/$NAME.gg.$$ && echo "\t Test PASS" 

# h: setfacl to modify group w/all perms; but can't read the file due to mask
ULIST="bin:rw-"
ASSERTION="setfacl to modify <$ULIST> to the attr file; group be\n\t"
ASSERTION="$ASSERTION able to read the file now due to mask set before."
echo "$NAME{h}: $ASSERTION"

is_cipso "vers=4" $SERVER
if [ $? -eq $CIPSO_NFSV4 ]; then
	echo "Not supported over CIPSO connection.\n\tTest UNSUPPORTED"
else
	run_assertion m $AFILE $ULIST group ckattr
fi

# i: setfacl to delete group & perms in the file, expect successful
ULIST="other:rwx staff:rw- bin:--x nobody:r-x"
ASSERTION="delete groups <$ULIST>\n\tACLs from the attr file, expect successful"
echo "$NAME{i}: $ASSERTION"

is_cipso "vers=4" $SERVER
if [ $? -eq $CIPSO_NFSV4 ]; then
	echo "Not supported over CIPSO connection.\n\tTest UNSUPPORTED"
else
	run_assertion d $AFILE "$ULIST" group
fi

# Finally cleanup and exit
cleanup $PASS
