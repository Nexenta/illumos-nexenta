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
# ID:nsmbrc003
#
# DESCRIPTION:
#        Verify password can work
#
# STRATEGY:
#       1. create a .nsmbrc file
#       2. run "smbutil logoutall"
#       3. run "mount -F smbfs //$TUSER@$server/public $TMNT"
#       4. smbutil and mount can get right message
#

nsmbrc003() {
tet_result PASS

tc_id="nsmbrc003"
tc_desc=" Verify password can work"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

smbmount_clean $TMNT
smbmount_init $TMNT

server=$(server_name) || return

rm -f ~root/.nsmbrc
pass=$(smbutil crypt $TPASS)
SERVER=$(echo $server | tr "[:lower:]" "[:upper:]")
echo "[$SERVER:$TUSER]" > ~root/.nsmbrc
echo "addr=$server" >> ~root/.nsmbrc
echo "password=$pass" >> ~root/.nsmbrc
chmod 600 ~root/.nsmbrc

smbutil logoutall

# get rid of our connection
kill_smbiod
sleep 2

cti_report "expect failure next"
cmd="smbutil view -N //$TUSER1@$server"
cti_execute -i '' PASS $cmd
if [[ $? == 0 ]]; then
	cti_fail "FAIL: $SERVER:$TUSER works for $TUSER1"
	return
else
	cti_report "PASS: $SERVER:$TUSER does't work for $TUSER1"
fi

cmd="mount -F smbfs //$TUSER@$server/public $TMNT"
cti_execute -i '' FAIL $cmd
if [[ $? != 0 ]]; then
	cti_fail "FAIL: $SERVER:$TUSER does't work for $TUSER"
	return
else
	cti_report "PASS: $SERVER:$TUSER works for $TUSER"
fi

smbmount_check $TMNT
if [[ $? != 0 ]]; then
	smbmount_clean $TMNT
	return
fi

rm -f ~root/.nsmbrc
smbmount_clean $TMNT

cti_pass "${tc_id}: PASS"
}
