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
# Copyright 2010 Sun Microsystems, Inc.  All rights reserved.
#

#
# ID: smbmount_008
#
# DESCRIPTION:
#          Verify normal smbmount can mount public share
#
# STRATEGY:
#	1. run "su  $TUSER -c  "mount -F smbfs -ofileperms=666
#	  //$TUSER:$TPASS@$server/public $TMNT""
#	2. mount successfully
#	3. run "su $AUSER -c "cp /usr/bin/ls ls_file""
#	4. mount and cp can get right message
#

smbmount008() {
tet_result PASS

tc_id="smbmount008"
tc_desc="Verify normal smbmount can mount public share"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name) || return

testdir_init $TDIR
smbmount_clean $TMNT
smbmount_init $TMNT

chown $TUSER $TMNT

cmd="mount -F smbfs -o fileperms=666 \
 //$TUSER:$TPASS@$server/public $TMNT"
cti_execute -i '' FAIL su $TUSER -c "$cmd"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the normal user can't mount the public share"
	smbmount_clean $TMNT
	return
else
	cti_report "PASS: the normal user can mount the public share"
fi

smbmount_check $TMNT || return

cd $TMNT
cti_execute_cmd "rm -rf $TMNT/*"

cmd="su $AUSER -c \"cp /usr/bin/ls ls_file\""
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: failed to cp the file /usr/bin/ls"
	return
else
	cti_report "PASS: cp the file /usr/bin/ls successfully"
fi

cmd="su $AUSER -c \"diff /usr/bin/ls ls_file\""
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the file /usr/bin/ls is different with the file ls_file"
	return
else
	cti_report "PASS: the file /usr/bin/ls is same to the file ls_file"
fi

cti_execute_cmd "rm ls_file"
cti_execute_cmd "cd -"

cmd="su $TUSER -c \"umount $TMNT\""
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the normal user can't umount the public share"
	smbmount_clean $TMNT
	return
else
	cti_report "PASS: the normal user can umount the public share"
fi

smbmount_clean $TMNT
cti_pass "${tc_id}: PASS"
}
