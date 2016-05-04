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
# a: Test basic create named attr for hardlink object using runat, expect OK
# b: Test basic remove of hardlink object w/named attr using runat, expect OK
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# --------------------------------------------------------------------
# a: Test basic create named attr for hardlink object using attr \
# commands, expect OK
ASSERTION="Test basic create named attr for hardlink object using \
attr commands"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{a}: $ASSERTION"

#Ensure that test file doesn't already exist
rm -f $MNTPTR/$TESTFILE $MNTPTR/$HLNK1 $MNTPTR/$HLNK2 > /dev/null 2>&1

#Check mount point works
ls $MNTPTR > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $MNTPTR not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Create a test file
echo "This is a testfile" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $? "Cannot create testfile [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file created is accessible
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "$LSAT cannot access $MNTPTR/$TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object 
echo "This is an attribute" | runat $MNTPTR/$TESTFILE "cat > attr" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr file in $MNTPTR/$TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Create a hardlink referencing test file
ln $MNTPTR/$TESTFILE $MNTPTR/$HLNK1 > $TMPDIR/ln1.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create link $HLNK1 to $TESTFILE, returned $ret" \
	$TMPDIR/ln1.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify hardlink is accessible
RESULT=$($LSAT $MNTPTR/$HLNK1 | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSAT command failed when using link $HLNK1 (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify attr dir space is  accessible by hardlink using runat command
runat $MNTPTR/$HLNK1 ls -l > $TMPDIR/runat03.out.$$ 2>&1
ret=$?
ckreturn $ret \
	"'runat $MNTPTR/$HLNK1 ls -l' (link) not accessible, returned $ret." \
	$TMPDIR/runat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can view an attribute created in originial file's 
# attribute directory
runat $MNTPTR/$HLNK1 cat attr > $TMPDIR/runat03.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot access attring link $HLNK1, returned $ret" \
	$TMPDIR/runat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
rm -f $MNTPTR/$HLNK1 $TMPDIR/*.out.$$

# --------------------------------------------------------------------
# b: Test basic remove of hardlink object w/named attr using attr \
# commands, expect OK
ASSERTION="Test basic remove of hardlink object w/named attr using \
attr commands"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{b}: $ASSERTION"

#Ensure that test file doesn't already exist
rm -f $MNTPTR/$TESTFILE2 $MNTPTR/$HLNK1 $MNTPTR/$HLNK2 > /dev/null 2>&1

sleep 1
# Create a test file
echo "This is a testfile" > $MNTPTR/$TESTFILE2 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create testfile $TESTFILE2, returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file was created with extended attribute dir
$LSAT $MNTPTR/$TESTFILE2 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "$LSAT cannot access $TESTFILE2, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object
echo "This is an attribute" | runat $MNTPTR/$TESTFILE2 "cat > attr" \
	> $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr on $MNTPTR/$TESTFILE2, returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Create a hardlink referencing test file
ln $MNTPTR/$TESTFILE2 $MNTPTR/$HLNK2 > $TMPDIR/ln2.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create link $HLNK2 to testfile, returned $ret." \
	$TMPDIR/ln2.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify hardlink is accessible
RESULT=$($LSAT $MNTPTR/$HLNK2 | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSAT command canot access attr (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL 

sleep 1
# Verify attr dir space accessible by hardlink using runat command
runat $MNTPTR/$HLNK2 ls -l > $TMPDIR/runat03.out.$$ 2>&1
ret=$?
ckreturn $ret "'runat $MNTPTR/$HLNK2 ls -l' (link) failed, returned $ret." \
	$TMPDIR/runat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can view an attribute created in originial file's attribute directory
runat $MNTPTR/$HLNK2 cat attr > $TMPDIR/runat03.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot access attr using link $HLNK2, returned $ret." \
	$TMPDIR/runat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Remove hardlink
rm -f $MNTPTR/$HLNK2 > $TMPDIR/rm03.out.$$  2>&1
ret=$?
ckreturn $ret "Failed to remove link $HLNK2, returned $ret." $TMPDIR/rm03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify that can still access original file
runat $MNTPTR/$TESTFILE2 ls -l > $TMPDIR/runat03.out.$$  2>&1
ret=$?
ckreturn $ret \
	"Cannot access testfile $TESTFILE2 after removing link, returned $ret."\
	$TMPDIR/runat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can still view original file named attr
runat $MNTPTR/$TESTFILE2 cat attr > $TMPDIR/runat_cat03.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot access attr using runat with $TESTFILE2, returned $ret." \
	$TMPDIR/runat_cat03.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

cleanup $PASS

exit $PASS
