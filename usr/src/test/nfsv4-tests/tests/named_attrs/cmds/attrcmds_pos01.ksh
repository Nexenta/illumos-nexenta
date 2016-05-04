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
# a: Test basic create named attr for file object using runat, expect OK
# b: Test basic remove of file object w/named attr using runat, expect OK
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# XXX Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# --------------------------------------------------------------------
# a: Test basic create named attr for file object using attr commands, \
#expect OK
ASSERTION="Test basic create named attr for file object using runat \
command"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{a}: $ASSERTION"

#Check mount point works
ls $MNTPTR > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $MNTPTR not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
#Ensure that test file doesn't already exist
[ -f $MNTPTR/$TESTFILE ] && rm -f $MNTPTR/$TESTFILE > /dev/null 2>&1

sleep 1
# Create a test file 
echo "This is a file" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create testfile [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file was created with extended attribute dir
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot access testfile [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Now Create named attribute for file object 
echo "This is an attribute" | runat $MNTPTR/$TESTFILE "cat > attr" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr dir, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify test file still accessible
RESULT=$($LSAT $MNTPTR/$TESTFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSAT command cannot access attr (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1 
# Verify attr file accessible by runat command
runat $MNTPTR/$TESTFILE ls -l > $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn $ret "'runat $MNTPTR/$TESTFILE ls -l' failed, returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify can view an attribute created in file's attribute directory
runat $MNTPTR/$TESTFILE cat attr > $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot read access testfile [$TESTFILE attr], returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

cleanup $PASS

# --------------------------------------------------------------------
# b: Test basic remove of file object w/named attr using attr commands, \
#expect OK
ASSERTION="Test basic remove of file object w/named attr using runat command"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{b}: $ASSERTION"

# Verify file doesn't exist before test started
[ -f $MNTPTR/$TESTFILE ] && rm -f $MNTPTR/$TESTFILE > /dev/null 2>&1

sleep 1
# Create a test file 
echo "This is a file" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create [$TESTFILE], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file was created with extended attribute dir
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create [$TESTFILE], returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object
echo "This is an attribute for remove" | runat $MNTPTR/$TESTFILE "cat > attrb" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr dir, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify test file still accessible
RESULT=$($LSAT $MNTPTR/$TESTFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSAT command didn't get attr (res=$RESULT)" $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify attr dir accessible by runat command
runat $MNTPTR/$TESTFILE ls -l > $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn $ret "'runat $MNTPTR/$TESTFILE ls -l' failed, returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Remove file and it's attr dir using basic "rm" command
rm -f $MNTPTR/$TESTFILE > $TMPDIR/rm01.out.$$ 2>&1
ret=$?
ckreturn $ret "[$TESTFILE attr dir] was not removed, returned $ret." \
	$TMPDIR/rm01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify test file not accessible
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "[$TESTFILE] still accessible, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

# Verify attr nolonger accessible by runat command
runat $MNTPTR/$TESTFILE ls -l > $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn -r $ret "[$TESTFILE attr dir] was not removed, returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -eq 0 ] && cleanup $FAIL

echo "\tTest PASS"

cleanup $PASS

exit $PASS
