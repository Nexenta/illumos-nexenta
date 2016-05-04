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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 named attributes: 
# a: Test hardlinks must not reference objects outside of 
#    the attrdir. expect FAIL
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# --------------------------------------------------------------------
# a: Test hardlinks must not reference objects outside of the attrdir, \
# expect FAIL
ASSERTION="Test hardlinks must not reference objects outside of the attrdir"
ASSERTION="$ASSERTION, expect FAIL"
echo "$NAME{a}: $ASSERTION"

#Check mount point works
ls $MNTPTR > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $MNTPTR not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

#Ensure that test file doesn't already exist
rm -f $MNTPTR/$TESTFILE $MNTPTR/$TESTFILE2 > /dev/null 2>&1

sleep 1
# Create a test file
echo "This is a testfile" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create test file $TESTFILE (ret=$ret)" $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Create a test file
echo "This is a textfile" > $MNTPTR/$TESTFILE2 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create test file $TESTFILE2 (ret=$ret)" $TMPDIR/$NAME.out.$$\
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file created is accessible
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create [$TESTFILE], returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object 
echo "This is an attribute" | runat $MNTPTR/$TESTFILE "cat > attr" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr dir, returned $ret ." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Try to create a hardlink referencing test file outside of attrdir
runat $MNTPTR/$TESTFILE ln $MNTPTR/$TESTFILE2 $HLNK1 > \
	$TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "Link unexpectedly created on object outside of attrdir,\
 returned $ret." $TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

sleep 1
# Verify hardlink not accessible
runat $MNTPTR/$TESTFILE ls $HLNK1 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "Link unexpectedly created on object outside of attrdir,\
 returned $ret." $TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup test files
cleanup $PASS

exit $PASS
