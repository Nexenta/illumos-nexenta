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
# ID: smbmount_005
#
# DESCRIPTION:
#        Verify "mount -F smbfs -O" work well
#
# STRATEGY:
#	1. create user "$AUSER" and "$BUSER"
#	2. run "mount -F smbfs //$AUSER:$APASS@$server/$AUSER $TMNT"
#	3. mount successfully
#	4. run "mount -F smbfs -O //$BUSER:$BPASS@$server/$BUSER $TMNT"
#	5. mount successfully
#

smbmount005() {
tet_result PASS

tc_id="smbmount005"
tc_desc="-O work well"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name) || return

testdir_init $TDIR
smbmount_clean $TMNT
smbmount_init $TMNT

cmd="mount -F smbfs //$AUSER:$APASS@$server/$AUSER $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: smbmount can't mount the share $AUSER with user $AUSER"
	return
else
	cti_report "PASS: smbmount can mount the share $AUSER with user $AUSER"
fi

smbmount_check $TMNT || return

# cp file
cmd="cp /usr/bin/ls ls_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: failed to cp the /usr/bin/ls file"
	return
else
	cti_report "PASS: cp the /usr/bin/ls file successfully"
fi

cmd="diff /usr/bin/ls ls_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the file /usr/bin/ls is different with file ls_file"
	return
else
	cti_report "PASS: the file /usr/bin/ls is same to the ls_file file"
fi

cmd="mount -F smbfs -O //$BUSER:$BPASS@$server/$BUSER $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: smbmount can't mount the share $AUSER on the same point twice with -O option"
	return
else
	cti_report "PASS: smbmount can mount the share $AUSER on the same point twice with -O option"
fi

smbmount_check $TMNT || return

cmd="diff /usr/bin/ls ls_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the second diff file /usr/bin/ls is different with the ls_file file"
	return
else
	cti_report "PASS: the second diff file /usr/bin/ls is same to the ls_file file"
fi

# cp file
cmd="cp /usr/bin/rm rm_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: failed to cp the /usr/bin/rm file"
	return
else
	cti_report "PASS: cp the file /usr/bin/rm successfully"
fi

cmd="diff /usr/bin/rm rm_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the file /usr/bin/rm is different with the rm_file file"
	return
else
	cti_report "PASS: the file /usr/bin/rm is same to the rm_file file"
fi

cmd="umount $TMNT"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the first umount $TMNT is failed "
	return
else
	cti_report "PASS: the first umount $TMNT is successful"
fi

cmd="diff /usr/bin/ls ls_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL:the third diff:file /usr/bin/ls is different with file ls_file"
	return
else
	cti_report "PASS:the third diff:file /usr/bin/ls is same to file ls_file"
fi
cmd="diff /usr/bin/rm rm_file"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the fourth diff:file /usr/bin/rm is different with file rm_file"
	return
else
	cti_report "PASS: the fourth diff:file /usr/bin/rm is same to the rm_file file"
fi

cmd="umount $TMNT"
cti_execute_cmd $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: the second umount $TMNT is failed"
	return
else
	cti_report "PASS: the second umount $TMNT is successful"
fi

smbmount_clean $TMNT
cti_pass "${tc_id}: PASS"
}
