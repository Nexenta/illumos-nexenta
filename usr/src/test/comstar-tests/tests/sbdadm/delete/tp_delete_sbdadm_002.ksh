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
# A test purpose file to test functionality of the delete-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: delete002
# 
# DESCRIPTION:
# 	a series of delete-lu commands with the incorrect syntax
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit firstly, then delete the logical unit
# 		with the following incorrect options:
# 			- no specified GUID
# 			- wrong GUID
# 			- -k and GUID are out of order
# 	Test: 
# 		Verify the failure of each deletion attempt
# 	Cleanup:
# 		Delete the logical units
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	delete-lu
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
function delete002 {
	cti_pass
	tc_id="delete002"
	tc_desc="a series of delete-lu commmands with the incorrect syntax"
	print_test_case $tc_id - $tc_desc
	

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	sbdadm_delete_lu NEG 
	sbdadm_delete_lu NEG 6000000000000000
	eval guid=\$LU_${VOL[0]}_GUID
	sbdadm_delete_lu NEG $guid -k

	tp_cleanup
	clean_fs zdsk

}
