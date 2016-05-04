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
# a: Test copy/rename of file w/named attrs using attr cp command, expect OK
# b: Test creating hardlink in a file's attrdir, expect OK
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# -----------------------------------------------------------------------
# a: Test copy/rename of file w/named attrs using attr cp \
# command, expect OK
ASSERTION="Test copy/rename of file w/named attrs using attr cp command"
ASSERTION="$ASSERTION, expect OK" 
echo "$NAME{a}: $ASSERTION"

#Ensure that test file doesn't already exist
rm -f $MNTPTR/$TESTFILE > /dev/null 2>&1

#Check mount point works
ls $MNTPTR > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $MNTPTR not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Create a test file
echo "This is a file" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create testfile $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Verify test file is accessible  
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "$LSAT cannot access testfile $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object 
echo "This is an attribute" | runat $MNTPTR/$TESTFILE "cat > attrfile" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create named attr on [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify test file and new attrdir still accessible
RESULT=$($LSAT $MNTPTR/$TESTFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSAT command cannot access attr (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
runat $MNTPTR/$TESTFILE ls -l > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "'runat $MNTPTR/$TESTFILE ls -l' failed, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can use named attr cp command in named attr space
$CPAT $MNTPTR/$TESTFILE $MNTPTR/$NEWFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret \
	"'$CPAT $MNTPTR/$TESTFILE $MNTPTR/$NEWFILE' failed, returned $ret" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify new file still accessible
RESULT=$($LSAT $MNTPTR/$NEWFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "'$LSAT $MNTPTR/$NEWFILE' failed (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify can view named attr of new file created with cp command
runat $MNTPTR/$NEWFILE cat attrfile > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot access attr using runat on NEWFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
rm -f $TMPDIR/*.out.$$

# --------------------------------------------------------------------
# b: Test creating hardlink in a file's attrdir, expect OK
ASSERTION="Test creating hardlink in a file's attrdir, \
expect OK"
ASSERTION="$ASSERTION, expect OK"
echo "$NAME{b}: $ASSERTION"

#Ensure that test file doesn't already exist
rm -f $MNTPTR/$TESTFILE > /dev/null 2>&1

# Create a test file
echo "This is a file" > $MNTPTR/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create testfile $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file was created with extended attribute dir
$LSAT $MNTPTR/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "$LSAT on [$TESTFILE w/attr] failed, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Now Create named attribute for file object
echo "This is an attribute" | runat $MNTPTR/$TESTFILE "cat > attrdirname2" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create named attr on [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify attr was created on test file
RESULT=$($LSAT $MNTPTR/$TESTFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "'$LSAT $MNTPTR/$TESTFILE' failed (res=$RESULT)" $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL 

sleep 1
# Verify attr dir accessible by runat command
runat $MNTPTR/$TESTFILE ls -l > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "cannot access attr using runat on $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Get inode number of $TESTFILE
ATTRDIR=attrdirname2
INODE=$(runat $MNTPTR/$TESTFILE ls -i $ATTRDIR 2> $TMPDIR/$NAME.out.$$)
ret=$?
ckreturn $ret "[$TESTFILE attr dir $ATTRDIR] cannot get inode, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL
mv $TMPDIR/$NAME.out.$$ $TMPDIR/${NAME}_1.out.$$

INODE1=`echo $INODE | awk '{print $1}'`

sleep 1
# Create hardlink in attrdir of $TESTFILE
runat $MNTPTR/$TESTFILE ln $ATTRDIR $HLNK1 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret \
	"Cannot create link $HLNK1 to $ATTRDIR on $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Get inode number of new $HLNK1
INODE=$(runat $MNTPTR/$TESTFILE ls -i $HLNK1 2> $TMPDIR/$NAME.out.$$)
ret=$?
ckreturn $ret "[$TESTFILE attr link $HLNK1] cannot get inode, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL
mv $TMPDIR/$NAME.out.$$ $TMPDIR/${NAME}_2.out.$$

INODE2=`echo $INODE | awk '{print $1}'`

# add output for INODEs for debugging purposes
echo "INODE information from attrdir $ATTRDIR:\n" > $TMPDIR/${NAME}.out.$$
cat $TMPDIR/${NAME}_1.out.$$ >> $TMPDIR/${NAME}.out.$$ 2>/dev/null

echo "\n\nINODE information from link $HLNK1:\n" >> $TMPDIR/${NAME}.out.$$
cat $TMPDIR/${NAME}_2.out.$$ >> $TMPDIR/${NAME}.out.$$ 2>/dev/null

sleep 1 
# Verify inodes of $TESTFILE and $HLNK1 are the same
ret=0 && [ $INODE1 -ne $INODE2 ] && ret=1
ckreturn $ret "inodes of $ATTRDIR and $HLNK1 are not the same" \
	$TMPDIR/${NAME}.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
cleanup $PASS

exit $PASS
