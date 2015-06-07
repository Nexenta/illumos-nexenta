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
# A test purpose file to test functionality of the modify-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: modify002
# 
# DESCRIPTION:
# 	a series of modify-lu commands with the incorrect syntax
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit firstly, then modify the logical unit
# 		with the following incorrect options:
# 			- a negative size
# 			- no size is given
# 			- no GUID is given
# 			- GUID and size are out of order (GUID must be last)
# 	Test: 
# 		Verify the failure of each modify attempt
# 	Cleanup:
# 		Delete the logical unit
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	modify-lu
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
function modify002 {
	cti_pass
	tc_id="modify002"
	tc_desc="a series of modify-lu commmands with the incorrect syntax"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 2g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	sbdadm_modify_lu NEG -s -1024m $DEV_ZVOL/$ZP/${VOL[0]}	
	sbdadm_modify_lu NEG -s $DEV_ZVOL/$ZP/${VOL[0]}		
	sbdadm_modify_lu NEG -s 1024m
	sbdadm_modify_lu NEG $DEV_ZVOL/$ZP/${VOL[0]} -s 1024m 

	eval guid=\$LU_${VOL[0]}_GUID
	sbdadm_modify_lu NEG -s -1024m $guid
	sbdadm_modify_lu NEG -s $guid
	sbdadm_modify_lu NEG -s 1024m
	sbdadm_modify_lu NEG $guid -s 1024m 
	
	tp_cleanup
	clean_fs zdsk

}
