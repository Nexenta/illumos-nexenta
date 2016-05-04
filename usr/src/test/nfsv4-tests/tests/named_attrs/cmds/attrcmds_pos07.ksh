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
# a: Test for umount of fs on NFS client after named attr 
#	creation/access/remove of file object, expect OK
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# --------------------------------------------------------------------
# a: Test for umount of fs on NFS client after named attr \
# creation/access/remove of file object, expect OK
ASSERTION="Test for umount of fs on NFS client after named attr \
creation/access/remove of file object, expect OK"
ASSERTION="$ASSERTION, expect successful"
echo "$NAME{a}: $ASSERTION"

mkdir -m 0777 -p $TMPmnt 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "cannot create mount point $TMPmnt, returned $ret" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Do the V4 mount on the new mount pointer for testing purposes 
mount -o vers=4,rw $SERVER:$BASEDIR $TMPmnt > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "mount did not succeed, returned $ret" $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
#Ensure that test file doesn't already exist
rm -f $TMPmnt/$TESTFILE 

#Check mount TMPmnt point works
ls $TMPmnt > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $TMPmnt not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Create a test directory 
echo "This is a file" > $TMPmnt/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create [$TESTFILE], returned $ret." $TMPDIR/$NAME.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# Verify test file was created with extended attribute dir
$LSAT $TMPmnt/$TESTFILE > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "$LSAT cannot access $TESTFILE, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Now Create named attribute for file object 
echo "This is an attribute" | runat $TMPmnt/$TESTFILE \
	"cat > attr" > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot create attr dir, returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

# Verify test file still accessible
RESULT=$($LSAT $TMPmnt/$TESTFILE | awk '{print $1}' | cut -c11 \
	2> $TMPDIR/$NAME.out.$$)
ret=0 && [ "$RESULT" != "@" ] && ret=1
ckreturn $ret "'$LSAT $TMPmnt/$TESTFILE' failed (res=$RESULT)" \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1 
# Verify attr dir accessible by runat command
runat $TMPmnt/$TESTFILE ls -l > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "cannot access $TESTFILE attr using runat, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

sleep 1
# Verify can view an attribute created in file's attribute directory
runat $TMPmnt/$TESTFILE cat attr > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn $ret "Cannot view [$TESTFILE attr], returned $ret." $TMPDIR/$NAME.out.$$
[ $? -ne 0 ] && cleanup $FAIL

echo "\tTest PASS"

# cleanup here
cleanup $PASS

exit $PASS
