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
# ID: mkdir_003
#
# DESCRIPTION:
#        Verify cifs client can create multi dirs on the smbfs mount point
#
# STRATEGY:
#       1. run "mount -F smbfs //server/public /export/mnt"
#       2. mkdir and rmdir can get the right message
#

mkdir003() {
tet_result PASS

tc_id="mkdir003"
tc_desc=" Verify can muti dir operation on the smbfs"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name)||return

testdir_init $TDIR
smbmount_clean $TMNT
smbmount_init $TMNT

cmd="mount -F smbfs //$TUSER:$TPASS@$server/public $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: smbmount can't mount the public share"
	return
else
	cti_report "PASS: smbmount can mount the public share"
fi

cti_execute_cmd "rm -rf $TMNT/*"
cpath=$(pwd)
cti_execute_cmd "cd $TMNT"

# mkdir on smbfs
cti_execute_cmd  "mkdir testdir"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: mkdir testdir failed"
	return
else
	cti_report "PASS: mkdir testdir succeeded"
fi

# list dir
cti_execute_cmd "ls -ld testdir"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: ls -ld testdir failed"
	return
else
	cti_report "PASS: ls -ld testdir succeeded"
fi

# access dir
cti_execute_cmd "cd testdir"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: cd testdir failed"
	return
else
	cti_report "PASS: cd testdir succeeded"
fi

cti_execute_cmd "cd -"
cti_execute_cmd "rm -rf testdir/*"

# negative mkdir case
cti_execute_cmd "mkdir testdir"
if [[ $? == 0 ]]; then
	cti_fail "FAIL: mkdir testdir should fail"
	return
else
	cti_report "PASS: mkdir testdir failed"
fi

# rmdir
cti_execute_cmd "rmdir testdir"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: rmdir testdir failed"
	return
else
	cti_report "PASS: rmdir testdir succeeded"
fi

cti_execute_cmd "cd $cpath"

smbmount_clean $TMNT
cti_pass "${tc_id}: PASS"
}
