#!/bin/ksh -p
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# Copyright (c) 2012 by Delphix. All rights reserved.
# Copyright 2014 Nexenta Systems, Inc.
#

. $STF_SUITE/tests/functional/acl/acl_common.kshlib

#
# DESCRIPTION:
#	Verify aclinherit=passthrough-x will inherit the 'x' bits
#	if mode requests.
#
# STRATEGY:
#	1. Use both superuser and normal user to run the test case.
#	2. Create basedir and a set of subdirectores and files within it.
#	3. Set aclinherit=passthrough-x.
#	4. Verify only passthrough-x will inherit the 'x' bits if
#	   mode requests.
#

verify_runnable "both"

function cleanup
{
	if [[ -d $basedir ]]; then
		log_must $RM -rf $basedir
	fi
}

$ZPOOL upgrade -v | $GREP -q "passthrough-x aclinherit"
if (($? != 0)); then
	log_unsupported "aclinherit=passthrough-x is not supported"
fi

log_assert "Verify aclinherit=passthrough-x will inherit the 'x' bits" \
    "if mode requests"
log_onexit cleanup

set -A aces \
    "owner@:read_data/write_data/add_subdirectory/append_data/execute:dir_inherit/inherit_only:allow" \
    "owner@:read_data/write_data/add_subdirectory/append_data/execute::allow" \
    "group@:add_subdirectory/append_data/execute:dir_inherit/inherit_only:allow" \
    "group@:add_subdirectory/append_data/execute::allow" \
    "everyone@:add_subdirectory/append_data/execute:dir_inherit/inherit_only:allow" \
    "everyone@:add_subdirectory/append_data/execute::allow" \
    "owner@:read_data/write_data/add_subdirectory/append_data/execute:file_inherit/inherit_only:allow" \
    "group@:read_data/add_subdirectory/append_data/execute:file_inherit/inherit_only:allow" \
    "everyone@:read_data/add_subdirectory/append_data/execute:file_inherit/inherit_only:allow"

# Defile the based directory and file
basedir=$TESTDIR/basedir


#
# According to inherited flag, verify subdirectories and files within it has
# correct inherited access control.
#
function verify_inherit # <object>
{
	typeset obj=$1

	# Define the files and directories will be created after chmod
	ndir1=$obj/ndir1; ndir2=$ndir1/ndir2
	nfile1=$ndir1/nfile1.c; nfile2=$ndir1/nfile2

	log_must usr_exec $MKDIR -p $ndir1

	typeset -i i=0
	while ((i < ${#aces[*]})); do
		if ((i < 3)); then
			log_must usr_exec $CHMOD A$i=${aces[i]} $ndir1
		else
			log_must usr_exec $CHMOD A$i+${aces[i]} $ndir1
		fi
		((i = i + 1))
	done
	log_must usr_exec $MKDIR -p $ndir2
	log_must usr_exec $TOUCH $nfile1

	$CAT > $nfile1 <<EOF
#include <stdlib.h>
#include <stdio.h>
int main()
{ return 0; }
EOF

	mode=$(get_mode $ndir2)
	if [[ $mode != "drwxr-xr-x"* ]]; then
		log_fail "$ndir2: unexpected mode $mode, expected drwxr-xr-x"
	fi

	mode=$(get_mode $nfile1)
	if [[ $mode != "-rw-r--r--"* ]]; then
		log_fail "$nfile1: unexpected mode $mode, expected -rw-r--r--"
	fi

	if [[ -x /usr/sfw/bin/gcc ]]; then
		log_must /usr/sfw/bin/gcc -o $nfile2 $nfile1
		mode=$(get_mode $nfile2)
		if [[ $mode != "-rwxr-xr-x"* ]]; then
			log_fail "$nfile2: unexpected mode $mode," \
			    "expected -rwxr-xr-x,"
		fi
	fi
}

#
# Set aclmode=passthrough to make sure the acl will not change during chmod.
# TODO: Need to check that different combinations of aclmode/aclinherit settings
# work correctly.
#
log_must $ZFS set aclmode=passthrough $TESTPOOL/$TESTFS
log_must $ZFS set aclinherit=passthrough-x $TESTPOOL/$TESTFS

for user in root $ZFS_ACL_STAFF1; do
	log_must set_cur_usr $user
	verify_inherit $basedir
	cleanup
done

log_pass "Verify aclinherit=passthrough-x will inherit the 'x' bits" \
    "if mode requests"
