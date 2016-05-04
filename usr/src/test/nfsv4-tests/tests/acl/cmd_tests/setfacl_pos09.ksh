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
#     Call setfacl(1) verify "default" ACL entries and inherited
#     of a directory.
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

    echo "\n" > $EFILE
    set_acls $OP $TOBJ "$ULIST" $WHO || return $FAIL
    get_acls $TOBJ $TMPDIR/$NAME.ga.$$  || return $FAIL
    ULIST=$(echo $ULIST | sed 's/,/ /g')
    ck_aces $OP "$ULIST" $TMPDIR/$NAME.ga.$$ || return $FAIL
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
# a: setfacl to to add default ACLs 
ULIST="default:user::rwx,default:group::r-x,default:other:--x,default:mask:rwx"
ASSERTION="setfacl to add this default ACLs:\n    <$ULIST>"
echo "$NAME{a}: $ASSERTION"
run_assertion m $TDIR $ULIST ""

# b: setfacl to to add default user ACL
ULIST="default:user:$TUSER1:rwx"
ASSERTION="setfacl to add default user ACL \n\t<$ULIST>; expect successful"
echo "$NAME{b}: $ASSERTION"
run_assertion m $TDIR $ULIST ""

# c: verify file acl inherited from parent directory
ASSERTION="verify newly created file interited default ACL from\n\tparent"
ASSERTION="$ASSERTION dir, include ACLs <$ULIST> set from above"
echo "$NAME{c}: $ASSERTION"
ULIST=$(echo $ULIST | sed 's/default:user://')
echo "new interited file" > $TDIR/$NAME.nfile.$$ 2> $EFILE
ckreturn $? "<create $TDIR/$NAME.nfile.$$> failed" $EFILE
if [ $? -eq 0 ]; then
	if [[ $TestZFS == 1 ]]; then
		ls -v $TDIR/$NAME.nfile.$$ | grep "user:$TUSER1" > /dev/null 2>&1
		if [[ $? == 0 ]]; then
                        echo "\t Test PASS"
                else
			echo "Sub-file failed to inherite default ACL from parent."
                        ls -vd $TDIR/$NAME.ndir.$$
                        echo "\t Test FAIL"
                fi		
	else
		get_acls $TDIR/$NAME.nfile.$$ $TMPDIR/$NAME.gi.$$ && \
			ck_aces m "$ULIST" $TMPDIR/$NAME.gi.$$ && echo "\t Test PASS" 
	fi
fi

# d: setfacl to to add default group ACL
ULIST="default:group:staff:r-x"
ASSERTION="setfacl to add default group ACL \n\t<$ULIST>; expect successful"
echo "$NAME{d}: $ASSERTION"
run_assertion m $TDIR $ULIST ""

# e: verify new directory acl inherited from parent directory
ASSERTION="verify new created dir interited default ACL from \n\tparent"
ASSERTION="$ASSERTION dir, include group ACL <$ULIST> set from above"
echo "$NAME{e}: $ASSERTION"
ULIST=$(echo $ULIST | sed 's/default:group://')
mkdir -m 0775 $TDIR/$NAME.ndir.$$ > $EFILE 2>&1
ckreturn $? "<mkdir $TDIR/$NAME.ndir.$$> failed" $EFILE
if [ $? -eq 0 ]; then
	if [[ $TestZFS == 1 ]]; then
		ls -vd $TDIR/$NAME.ndir.$$ | grep "group:staff" > /dev/null 2>&1
		if [[ $? == 0 ]]; then
			echo "\t Test PASS" 
		else
			echo "Sub-dir failed to inherite default ACL from parent."
			ls -vd $TDIR/$NAME.ndir.$$
			echo "\t Test FAIL"
		fi
	else
		get_acls $TDIR/$NAME.ndir.$$ $TMPDIR/$NAME.gi.$$ && \
			ck_aces m "$ULIST" $TMPDIR/$NAME.gi.$$ && echo "\t Test PASS" 
	fi
fi

# f: setfacl to delete default user/group in the directory, expect successful
ULIST="default:user:$TUSER1:rwx default:group:staff:r-x"
ASSERTION="delete <$ULIST>\n\tACLs from the directory, expect successful"
echo "$NAME{f}: $ASSERTION"
run_assertion d $TDIR "$ULIST" ""

# g: verify new directory acl inherited from parent directory
ASSERTION="verify new created dir interited default ACL from parent don't\n\t"
ASSERTION="$ASSERTION have deleted <$ULIST> entries"
echo "$NAME{g}: $ASSERTION"
ULIST="user:$TUSER1:rwx group:staff:r-x"
mkdir -m 0700 $TDIR/$NAME.dirg.$$ > $EFILE 2>&1
ckreturn $? "<mkdir $TDIR/$NAME.dirg.$$> failed" $EFILE
if [ $? -eq 0 ]; then
	if [[ $TestZFS == 1 ]]; then
		ls -vd $TDIR/$NAME.dirg.$$ > $TMPDIR/$NAME.acl.$$
		cat $TMPDIR/$NAME.acl.$$ | grep "user:$TUSER1" > /dev/null 2>&1
		if [[ $? == 0 ]]; then
			echo "the acl with user $TUSER1 is inherited, it's not expected"
			cat $TMPDIR/$NAME.acl.$$
			echo "\t Test FAIL"
		fi
		cat $TMPDIR/$NAME.acl.$$ | grep "group:staff" > /dev/null 2>&1
		if [[ $? == 0 ]]; then
			echo "the acl with group staff is inherited, it's not expected"
			cat $TMPDIR/$NAME.acl.$$
			echo "\t Test FAIL"
		fi
		echo "\t Test PASS"
	else
		get_acls $TDIR/$NAME.dirg.$$ $TMPDIR/$NAME.gi.$$ && \
			ck_aces d "$ULIST" $TMPDIR/$NAME.gi.$$ && echo "\t Test PASS" 
	fi
fi


# Finally cleanup and exit
cleanup $PASS
