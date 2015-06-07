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
# A test purpose file to test functionality of the list-lu subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: list005
# 
# DESCRIPTION:
# 	List logical unit and its attributes
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit by sbdadm
# 		List the logical unit without arguments
# 		List the logical unit with -?
# 		List the logical unit with -v 
# 		List the logical unit specified logical unit name
# 		List the logical unit with -v and specified logical unit name
# 	Test: 
# 		Verify the list success
# 		Verify the return code               
# 	Cleanup:
# 		Delete the logical unit
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	list-lu
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
function list005 {
	cti_pass
	tc_id="list005"
	tc_desc="List logical unit and its attributes"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		
	fs_zfs_create -V 1g $ZP/${VOL[1]}		
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}

	eval guid0=\$LU_${VOL[0]}_GUID
	eval guid1=\$LU_${VOL[1]}_GUID

	stmfadm_list POS lu
	stmfadm_list POS lu -?
	stmfadm_list POS lu -v
	stmfadm_list POS lu $guid0 $guid1
	stmfadm_list POS lu -v $guid0 $guid1
	
	tp_cleanup
	clean_fs zdsk


}
