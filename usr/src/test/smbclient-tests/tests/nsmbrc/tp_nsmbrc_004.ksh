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
# ID:nsmbrc004
#
# DESCRIPTION:
#        Verify minauth can work on SERVER section
#
# STRATEGY:
#       1. create a .nsmbrc file
#       2. run "smbutil view //$TUSER:$TPASS@$server"
#       3. smbutil can get right messages
#

nsmbrc004() {
tet_result PASS

tc_id="nsmbrc004"
tc_desc=" Verify minauth can work on SERVER section"
print_test_case $tc_id - $tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name) || return

rm -f ~root/.nsmbrc

SERVER=$(echo $server | tr "[:lower:]" "[:upper:]")
echo "[$SERVER]" > ~root/.nsmbrc
echo "addr=$server" >> ~root/.nsmbrc
echo "minauth=kerberos" >> ~root/.nsmbrc

# get rid of our connection
kill_smbiod
sleep 2

cti_report "expect failure next"
cmd="smbutil view //$TUSER:$TPASS@$server"
cti_execute -i '' PASS $cmd
if [[ $? == 0 ]]; then
	cti_execute_cmd "echo ::nsmb_vc|mdb -k"
	cti_fail "FAIL: minauth property in SERVER section doesn't work"
	return
else
	cti_report "PASS: minauth property in SERVER section works"
fi

rm -f ~root/.nsmbrc

cti_pass "${tc_id}: PASS"
}
