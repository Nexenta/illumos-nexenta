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
# ID:nsmbrc001
#
# DESCRIPTION:
#        Verify minauth can work in default
#
# STRATEGY:
#	1. create a .nsmbrc file include default section
#	   minauth=kerberos
#	2. run "smbutil view user@server and get the failure"
#	3. create a .nsmbrc file include server section minauth=kerberos
#	4. run "smbutil view user@server and get the failure"
#	

nsmbrc001() {
tet_result PASS

tc_id="nsmbrc001"
tc_desc="Verify minauth can work in default"
print_test_case $tc_id" - "$tc_desc

if [[ $STC_CIFS_CLIENT_DEBUG == 1 ]] || \
	[[ *:${STC_CIFS_CLIENT_DEBUG}:* == *:$tc_id:* ]]; then
    set -x
fi

server=$(server_name) || return

rm -f ~root/.nsmbrc
echo "[default]" > ~root/.nsmbrc
echo "minauth=kerberos" >> ~root/.nsmbrc

# this should fail
cmd="smbutil view //$TUSER:$TPASS@$server"
cti_execute -i '' PASS $cmd
if [[ $? == 0 ]]; then
	cti_execute_cmd "echo ::nsmb_vc|mdb -k"
	cti_fail "FAIL: can pass authentication by minauth=kerberos"
	return
else
	cti_report "PASS: can't pass authentication by minauth=kerberos"
fi

rm -f ~root/.nsmbrc

cti_pass "${tc_id}: PASS"
}
