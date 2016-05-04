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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 named attributes: 
# a: Test basic create named attr for dir object using runat, expect OK
# b: Test basic remove of dir object w/named attr using runat, expect OK
# c: Test READDIR of named attr dir using runat command, expect OK
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# XXX Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# --------------------------------------------------------------------
# a: Test basic create named attr for dir object using runat command, \
#expect OK
ASSERTION="Test basic create named attr for dir object using attr commands"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{a}: $ASSERTION"

#Check mount point works
ls $MNTPTR > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $MNTPTR not accessible (ret=$ret)." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

cd $MNTPTR > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot chdir to [$MNTPTR], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Create a test directory 
mkdir $MNTPTR/$TESTDIR1 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create [$TESTDIR1], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Now Create named attribute for file object 
echo "This is an attribute" | runat $MNTPTR/$TESTDIR1 "cat > attr" > \
	$TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr file object, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify test file still accessible
RESULT=$($LSATD $MNTPTR/$TESTDIR1 | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "$LSATD command didn't get attr (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify attr dir accessible by runat command
runat $MNTPTR/$TESTDIR1 ls -l > $TMPDIR/runat01.out.$$ 2>&1
ret=$?
ckreturn $ret "[$TESTFILE attr dir] not accessible, returned $ret." \
	$TMPDIR/runat01.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can view an attribute created in file's attribute directory
runat $MNTPTR/$TESTDIR1 cat attr > $TMPDIR/runat02.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot view [$TESTDIR1 attr], returned $ret" $TMPDIR/runat02.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
rm -rf $MNTPTR/$TESTDIR1 $TMPDIR/$NAME.*.$$ $TMPDIR/runat*.out.$$

# --------------------------------------------------------------------
# b: Test basic remove of dir object w/named attr, expect OK
ASSERTION="Test basic remove of dir object w/named attr"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{b}: $ASSERTION"

cd $MNTPTR > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot chdir to [$MNTPTR], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Create a test directory 
mkdir $MNTPTR/$TESTDIR2 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create [$TESTDIR2], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Now Create named attribute for file object
echo "This is an attribute for remove" | runat $MNTPTR/$TESTDIR2 \
	"cat > attrb" > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr file objec, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify test dir is still accessible
$LSATD $MNTPTR/$TESTDIR2 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "[$TESTDIR2] not accessible, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify attr dir accessible by runat command
runat $MNTPTR/$TESTDIR2 ls -l > $TMPDIR/runat02.out.$$ 2>&1
ret=$?
ckreturn $ret "[$TESTDIR2 attr file] not accessible, returned $ret." \
	$TMPDIR/runat02.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Remove dir and it's attr file object using basic "rm" command
rm -r $MNTPTR/$TESTDIR2 > $TMPDIR/rm02.out.$$ 2>&1
ret=$?
ckreturn $ret "[$TESTDIR2 attr dir] was not removed, returned $ret." \
	$TMPDIR/rm02.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify test dir not accessible
$LSATD $MNTPTR/$TESTDIR2 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "[$TESTDIR2] still accessible, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

# Verify attr no longer accessible by runat command
runat $MNTPTR/$TESTDIR2 ls -l > $TMPDIR/runat02.out.$$ 2>&1
ret=$? 
ckreturn -r $ret "[$TESTDIR2 attr dir] was not removed, returned $ret." \
	$TMPDIR/runat02.out.$$
[ $? -eq 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
rm -rf $TMPDIR/$NAME.*.$$ $TMPDIR/runat*.out.$$ 

#---------------------------------------------------------------------:w
# c: Test READDIR of named attr dir using runat command, expect OK
ASSERTION="Test READDIR of named attr dir using runat command, expect OK"
echo "$NAME{c}: $ASSERTION"

# Create a temporary test directory for this assertion
mkdir $MNTPTR/$TESTDIR3 > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create dir [$MNTPTR/$TESTDIR3], returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Create named attribute for this dir object
Tattr=attrdir.$$
echo "This is an attribute for the dir object of $MNTPTR/$TESTDIR3" | \
        runat $MNTPTR/$TESTDIR3 "cat > $Tattr; chmod 600 $Tattr" \
        > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret \
    "Cannot create attr file [$Tattr] for $MNTPTR/$TESTDIR3, returned $ret." \
        $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Now Verify attr dir accessible by runat command and list the attr file
runat $MNTPTR/$TESTDIR3 'ls -l' | \
	egrep -iv "SUNWattr|total" > $TMPDIR/runatc.out.$$ 2>&1
ret=$?
ckreturn $ret "'runat [$MNTPTR/$TESTDIR3] ls -l' failed, returned $ret." \
	$TMPDIR/runatc.out.$$
[ $? -ne 0 ] && cleanup $FAIL

Tmode=`nawk '{print $1}' $TMPDIR/runatc.out.$$`
Tname=`nawk '{print $9}' $TMPDIR/runatc.out.$$`
ret=0 && [ "$Tmode" != "-rw-------" ] && ret=1
ckreturn $ret \
	"'runat $MNTPTR/$TESTDIR3 ls -l' incorrect mode $Tmode." \
	$TMPDIR/runatc.out.$$
[ $? -ne 0 ] && cleanup $FAIL

ret=0 && [ "$Tname" != "$Tattr" ] && ret=1
ckreturn $ret \
	"'runat $MNTPTR/$TESTDIR3 ls -l' incorrect attr name $Tname."\
	$TMPDIR/runatc.out.$$
[ $? -ne 0 ] && cleanup $FAIL


echo "\tTest PASS"

# cleanup here
cleanup $PASS

exit $PASS
