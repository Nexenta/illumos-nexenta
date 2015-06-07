#!/usr/bin/ksh -p
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
#

#
# Create the configuration file based on passed in variables
# or those set in the tetexec.cfg file.
#

iclist="ic1 ic2 ic3 ic4 ic5 ic6"
ic1="testdir_create"
ic2="testdir_delete"
ic3="user_create"
ic4="user_delete"
ic5="smbsrv_setup"
ic6="smbsrv_cleanup"

. ${CTI_SUITE}/config/config
. ${CTI_SUITE}/include/utils_common.ksh
. ${CTI_SUITE}/include/services_common.ksh

#
# NAME
#       testdir_create
#
# DESCRIPTION
#       create a fs mount point
#
testdir_create() {
	if [[ -z "$DISK" ]]; then
		cti_fail "FAIL: Must supply the -v DISK=<disk> argument"
		return
	fi

	rm -rf $TBASEDIR
	mkdir -m 777 $TBASEDIR

	zpool create -f -O mountpoint=$TBASEDIR $TESTDS $DISK
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to create testdir"
		return
	else
		cti_report "PASS: successsfully created testdir"
	fi

	cti_pass PASS
}

#
# NAME
#       testdir_delete
#
# DESCRIPTION
#       destroy the fs mount point
#
testdir_delete() {
	umount -f $TESTDS
	rm -rf $TBASEDIR
	zpool destroy $TESTDS
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to destroy testdir"
		return
	else
		cti_report "PASS: destroyed testdir"
	fi

	cti_pass PASS
}

#
# NAME
#       user_create
#
# DESCRIPTION
#       create users for the SMB client testing
#
user_create() {
	service_enable svc:/network/smb/client:default

	groupadd -g $SMBGRPGID $SMBGRP
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create group '$SMBGRP'"
	        return
	else
	        cti_report "PASS: created group '$SMBGRP'"
	fi

	useradd -u $TUSERUID -g $SMBGRPGID $TUSER
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create user '$TUSER'"
		return
	else
	        cti_report "PASS: created user '$TUSER'"
	fi

	useradd -u $TUSER1UID -g $SMBGRPGID $TUSER1
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create user '$TUSER1'"
		return
	else
	        cti_report "PASS: created user '$TUSER1'"
	fi

	groupadd -g $SMBGRP1GID $SMBGRP1
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create group '$SMBGRP1'"
	        return
	else
	        cti_report "PASS: created group '$SMBGRP1'"
	fi

	useradd -u $AUSERUID -g $SMBGRP1GID $AUSER
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create user '$AUSER'"
		return
	else
	        cti_report "PASS: created user '$AUSER'"
	fi

	useradd -u $BUSERUID -g $SMBGRP1GID $BUSER
	if [[ $? != 0 ]]; then
	        cti_fail "FAIL: failed to create user '$BUSER'"
		return
	else
	        cti_report "PASS: created user '$BUSER'"
	fi

	cti_pass PASS
}

#
# NAME
#       user_delete
#
# DESCRIPTION
#       delete the users created by user_create
#
user_delete() {
	for user in $TUSER $TUSER1 $AUSER $BUSER; do
	        userdel $user
	        if [[ $? != 0 ]]; then
	                cti_fail "FAIL: failed to delete user '$user'"
			return
		else
	                cti_report "PASS: deleted user '$user'"
	        fi
	done

	for group in $SMBGRP $SMBGRP1; do
	        groupdel $group
		if [[ $? != 0 ]]; then
	                cti_fail "FAIL: failed to delete group '$group'"
	                return
		else
	                cti_report "PASS: deleted group '$group'"
	        fi
	done

	cti_pass PASS
}

#
# NAME
#	smbsrv_setup
#
# DESCRIPTION
#	setup the SMB server
#
smbsrv_setup() {
	service_enable svc:/network/smb/server:default

	$EXPECT $PASSWDEXP $TUSER $TPASS
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to set password for user '$TUSER'"
		return
	else
		cti_report "PASS: set password for user '$TUSER'"
	fi

	$EXPECT $PASSWDEXP $TUSER1 $TPASS
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to set password for user '$TUSER1'"
		return
	else
		cti_report "PASS: set password for user '$TUSER1'"

	fi

	$EXPECT $PASSWDEXP $AUSER $APASS
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to set password for user '$AUSER'"
		return
	else
		cti_report "PASS: set password for user '$AUSER'"
	fi

	$EXPECT $PASSWDEXP $BUSER $BPASS
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to set password for user '$BUSER'"
		return
	else
		cti_report "PASS: set password for user '$BUSER'"
	fi

	sharemgr create -P smb $SHAREGRP
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to create share group '$SHAREGRP'"
		return
	else
		cti_report "PASS: created share group '$SHAREGRP'"
	fi

	for share in public $AUSER $BUSER; do
		rm -rf $TBASEDIR/$share
		mkdir -m 777 $TBASEDIR/$share

		sharemgr add-share -r $share -s $TBASEDIR/$share $SHAREGRP
		if [[ $? != 0 ]]; then
			cti_fail "FAIL: failed to create SMB share '$share'"
	        	return
		else
			cti_report "PASS: created SMB share '$share'"
		fi
	done

	cti_pass PASS
}

#
# NAME
#       smbsrv_cleanup
#
# DESCRIPTION
#       clean up SMB server
#
smbsrv_cleanup() {
	service_disable svc:/network/smb/server:default

	for share in public $AUSER $BUSER; do
		sharemgr remove-share -s $TBASEDIR/$share $SHAREGRP
		if [[ $? != 0 ]]; then
			cti_fail "FAIL: failed to delete SMB share '$share'"
			return
		else
			cti_report "PASS: deleted SMB share '$share'"
		fi
		rm -rf $TBASEDIR/$share
	done

	sharemgr delete $SHAREGRP
	if [[ $? != 0 ]]; then
		cti_fail "FAIL: failed to delete share group '$SHAREGRP'"
		return
	else
		cti_report "PASS: deleted share group '$SHAREGRP'"
	fi

	cti_pass PASS
}

. ${CTI_ROOT}/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
