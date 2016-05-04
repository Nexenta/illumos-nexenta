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
# a: Verify that "-o noxattr" disables attribute creation from
#    the client using runat command, expect FAIL
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Assume that xattr mount option is set by default on UFS filesystems
# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# ---------------------------------------------------------------------
# a: Verify that "-o noxattr" disables attribute creation from \
# the client using runat command, expect FAIL
ASSERTION="Verify that \"-o noxattr\" disables attribute creation from \
the client using runat command"
ASSERTION="$ASSERTION, expect FAIL to create attribute"
echo "$NAME{a}: $ASSERTION"

mkdir -m 0777 $TMPmnt 2>&1 > $TMPDIR/mount.out.$$
ret=$?
ckreturn $ret "mkdir $TMPmnt failed, returned $ret" $TMPDIR/mount.out.$$ \
	UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# mount using -o noxattr option
mount -o vers=4,noxattr $SERVER:$BASEDIR $TMPmnt > $TMPDIR/mount.out.$$ 2>&1
ret=$?
ckreturn $ret "mount -o vers=4,noxattr failed, exit non-zero." \
	$TMPDIR/$NAME.out.$$ UNINITIATED 
[ $? -ne 0 ] && cleanup $UNINITIATED

#Check mount point works
ls $TMPmnt > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $TMPmnt not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

#Ensure that test file doesn't already exist
rm -f $TMPmnt/$TESTFILE 2>&1 

# Create a test file
echo "This is a file" > $TMPmnt/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create [$TESTFILE] exit non-zero." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Now try to Create a named attribute for file object 
echo "This is an attribute" | runat $TMPmnt/$TESTFILE "cat > attr" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "named attr creation not disabled, returned $ret" \
	$TMPDIR/$NAME.out.$$
# May want to check snoop traffic here
[ $? -eq 0 ] && cleanup $FAIL

# Verify named attribute was not created
runat $TMPmnt/$TESTFILE ls attr > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "named attr was create unexpectedly, returned $ret" \
	$TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

echo "\tTest PASS"

# Cleanup test files
cleanup $PASS
exit $PASS
