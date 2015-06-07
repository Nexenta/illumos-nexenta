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
# A test purpose file to test functionality of the create-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: create006
# 
# DESCRIPTION:
# 	A series of misconfigured command line arguments
# 
# STRATEGY:
# 
# 	Setup:
# 		Attempt to create a lun with the following misconfigured command
# 		line options:
# 			- a negative size
# 			- no size is given
# 			- no source name is given
# 			- filename and size are out of order 
# 			  (filename must be last)
# 	Test: 
# 		Verify the failure of each creation attempt
# 	Cleanup:
# 		Delete the target if it was created
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	create-lu
# 
# TESTABILITY: explicit
# 
# AUTHOR: John.Gu@Sun.COM
# 
# REVIEWERS:
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS (2008-02-14)
# 
# __stc_assertion_end
function create006 {
	cti_pass
	tc_id="create006"
	tc_desc="A series of misconfigured command line arguments"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}
	
	sbdadm_create_lu NEG -s -1024k $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu NEG -s $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu NEG -s 1024k
	sbdadm_create_lu NEG $DEV_ZVOL/$ZP/${VOL[0]} -s 1024k 
	
	tp_cleanup
	clean_fs zdsk

}

