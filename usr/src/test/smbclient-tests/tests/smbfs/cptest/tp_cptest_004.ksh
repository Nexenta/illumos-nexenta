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
# ID: cptest_004
#
# DESCRIPTION:
#        Verify can create and cp 3G file on the smbfs
#
# STRATEGY:
#       1. run "mount -F smbfs //server/public /export/mnt"
#       2. cp and diff can get the right message
#

cptest004() {
tet_result PASS

tc_id="cptest004"
tc_desc="Verify can cp 3g files on the smbfs"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
    [[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
	set -x
fi

size=3g
if [[ -n "$STC_QUICK" ]] ; then
  size=30m
fi

server=$(server_name) || return

testdir_init $TDIR
smbmount_clean $TMNT
smbmount_init $TMNT

cmd="mount -F smbfs //$TUSER:$TPASS@$server/public $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "smbmount can't mount the public share"
	return
else
	cti_report "smbmount can mount the public share"
fi

cti_execute_cmd "cd $TMNT"

cti_execute_cmd "mkfile $size $TDIR/test_file"
cti_execute FAIL "sum $TDIR/test_file"
read sum1 cnt1 junk < cti_stdout

# cp file to server
cti_execute_cmd "cp $TDIR/test_file test_file"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: cp $TDIR/test_file to test_file failed"
	return
else
	cti_report "PASS: cp $TDIR/test_file to test_file successfully"
fi

cti_execute FAIL "sum test_file"
if [[ $? != 0 ]]; then
	cti_fail "FAIL: sum $size file on smbfs failed"
	return
else
	cti_report "PASS: sum $size file on smbfs succeeded"
fi

read sum2 cnt2 junk < cti_stdout
if [[ $sum1 != $sum2 ]] ; then
	cti_fail "FAIL: first sum of the files are different"
	return
else
	cti_report "PASS: first sums of the files are same"
fi

# cp back to local
cti_execute_cmd "cp test_file $TDIR/test_file_cp "
if [[ $? != 0 ]]; then
	cti_fail "cp test_file $TDIR/test_file_cp failed"
	return
else
	cti_report "cp test_file $TDIR/test_file_cp succeeded"
fi

cti_execute FAIL "sum $TDIR/test_file_cp"
read sum3 cnt3 junk < cti_stdout
if [[ $sum1 != $sum3 ]] ; then
	cti_fail "the second sum of the files are different"
	return
else
	cti_report "the second sum of the files are same"
fi

cti_execute_cmd "rm test_file"
if [[ $? != 0 ]]; then
	cti_fail "rm the test_file failed"
	return
else
	cti_report "rm the test_file successfully"
fi

cti_execute_cmd "rm -rf $TDIR/*"
cti_execute_cmd "cd -"

smbmount_clean $TMNT

if [[ -n "$STC_QUICK" ]] ; then
	cti_report "PASS, but with reduced size."
	cti_untested $tc_id
	return
fi

cti_pass "${tc_id}: PASS"
}
