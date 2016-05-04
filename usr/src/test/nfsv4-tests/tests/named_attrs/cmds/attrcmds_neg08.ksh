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
#
# a: Verify runat will fail when the underlying server doesn't
#        support named attributes, expect FAIL
#

funcs="./attrcmds_funcs"
[ ! -r $funcs ] && echo "$0 ERROR: cannot source $funcs" && exit $UNINITIATED
. $funcs

setup

# Use pre-mounted filesystem previously setup by nfs4_gen framework

# Start test
# ---------------------------------------------------------------------
# a: Verify runat will fail when the underlying server doesn't
#        support named attributes, expect FAIL
ASSERTION="Verify runat will fail when the underlying server doesn't \
support named attributes"
ASSERTION="$ASSERTION, expect FAIL"
echo "$NAME{a}: $ASSERTION"

mkdir -m 0777 -p $TMPmnt 2>&1 > $TMPDIR/mount.out.$$
ret=$?
ckreturn $ret "cannot create dir $TMPmnt" $TMPDIR/mount.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 1
# mount WITHOUT using -o noxattr option
# onto TMPFS filesystem mounted WITH noxattr option
mount -F nfs -o vers=4 $SERVER:$SSPCDIR3 $TMPmnt > $TMPDIR/mount.out.$$ 2>&1
ret=$?
ckreturn $ret "mount -F nfs -o vers=4 failed, returned $ret." \
	$TMPDIR/mount.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

#Check mount TMPmnt point works
ls $TMPmnt > /dev/null 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "mount point $TMPmnt not accessible (ret=$ret)" \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

sleep 3 
#Ensure that test file doesn't already exist
rm -f $TMPmnt/$TESTFILE 2>&1 > /dev/null

sleep 1
# Create a test directory 
echo "This is a file" > $TMPmnt/$TESTFILE 2> $TMPDIR/$NAME.out.$$
ret=$?
ckreturn $ret "Cannot create [$TESTFILE], returned $ret." \
	$TMPDIR/$NAME.out.$$ UNINITIATED
[ $? -ne 0 ] && cleanup $UNINITIATED

# Now try to Create named attribute on exported noxattr mounted filesystem 
echo "This is an attribute" | runat $TMPmnt/$TESTFILE "cat > attr" \
	> $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "named attr creation not disabled, returned $ret." \
	$TMPDIR/$NAME.out.$$
# May want to check snoop traffic here
[ $? -eq 0 ] && cleanup $FAIL

# Verify named attribute was not created
runat $TMPmnt/$TESTFILE ls attr > $TMPDIR/$NAME.out.$$ 2>&1
ret=$?
ckreturn -r $ret "named attr was unexpectedly created, returned $ret." \
	$TMPDIR/$NAME.out.$$
[ $? -eq 0 ] && cleanup $FAIL

echo "\tTest PASS"
cleanup $PASS

exit $PASS
