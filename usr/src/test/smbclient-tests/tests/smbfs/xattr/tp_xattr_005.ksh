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
# ID:  xattr_005
#
# DESCRIPTION:
# Verify special . and .. dirs work as expected for xattrs
#
# STRATEGY:
#	1. Create a file and an xattr on that file
#	2. List the . directory, verifying the output
#	3. Verify we're unable to list the ../ directory
#

function xattr_005 {
tet_result PASS

tc_id=xattr_005
tc_desc="Verify special . and .. dirs work as expected for xattrs"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name) || return

testdir_init $TDIR
smbmount_clean $TMNT
smbmount_init $TMNT

cmd="mount -F smbfs //$TUSER:$TPASS@$server/public $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: smbmount can't mount the public share unexpectedly"
	return
else
	cti_report "PASS: smbmount can mount the public share as expected"
fi

smbmount_getmntopts $TMNT |grep /xattr/ >/dev/null
if [[ $? != 0 ]]; then
	smbmount_clean $TMNT
	cti_unsupported "UNSUPPORTED (no xattr in this mount)"
	return
fi

cti_execute_cmd "cd $TMNT"

# create a file, and an xattr on it

cti_execute_cmd "touch test_file"
create_xattr test_file passwd /etc/passwd

cur_ver=$(uname -r)
if [ "$cur_ver" == "5.10" ];then
	# listing the directory . should show one file

	OUTPUT=$(runat test_file ls .)
	if [ "$OUTPUT" != "passwd" ]
	then
	        cti_fail "Listing the . directory doesn't show \"passwd\" as expected."
	fi
	# list the directory . long form

	cti_execute_cmd "runat test_file ls -a . > $TDIR/output.$$"

	# create a file that should be the same as the command above
	create_expected_output $TDIR/expected-output.$$  .  ..   passwd
	# compare them

	cti_execute_cmd "diff $TDIR/output.$$ $TDIR/expected-output.$$"
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: special . dirs do not work as expected for xattrs"
	        return
	else
	        cti_report "PASS: special . dirs work as expected for xattrs"
	fi

else
	# listing the directory .
	
	cti_execute_cmd "runat test_file ls . > $TDIR/output.$$"
	create_expected_output  $TDIR/expected-output.$$  \
	passwd
	cti_execute_cmd "diff $TDIR/output.$$ $TDIR/expected-output.$$"
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: special . dirs do not work as expected for xattrs"
	        return
	else
	        cti_report "PASS: special . dirs work as expected for xattrs"
	fi
	
	# list the directory . long form

	cti_execute_cmd "runat test_file ls -a . > $TDIR/output.$$"
	create_expected_output  $TDIR/expected-output.$$ . ..  \
	passwd
	cti_execute_cmd "diff $TDIR/output.$$ $TDIR/expected-output.$$"
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: special . dirs do not work as expected for xattrs"
	        return
	else
	        cti_report "PASS: special . dirs work as expected for xattrs"
	fi

fi
	
# list the directory .. expecting one file

OUTPUT=$(runat test_file ls ..)
if [ $? != 0 ]
then
	cti_fail "runat test file ls .. failed with return val =$? unexpectedly"
	return
fi

if [ "$OUTPUT" != ".." ]
then
	cti_fail "Listing the .. directory doesn't show \"..\" as expected"
	return
fi

# verify we can't list ../

cti_execute PASS "runat test_file ls  ../"
if [[ $? == 0 ]]; then
	cti_fail "FAIL: can be able to list the ../ directory unexpectedly"
	return
else
	cti_report "PASS: unable to list the ../ directory as expected"
fi

cti_execute_cmd "cd -"
cti_execute_cmd "rm -rf $TDIR/*"

smbmount_clean $TMNT
cti_pass "$tc_id: PASS"
}
