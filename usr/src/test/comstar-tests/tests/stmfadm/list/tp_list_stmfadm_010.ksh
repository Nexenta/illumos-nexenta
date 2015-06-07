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
# A test purpose file to test functionality of the list-view subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: list010
# 
# DESCRIPTION:
# 	Attempt to list view entry and its attributes with wrong arguments
# 
# STRATEGY:
# 
# 	Setup:
# 		Create host group hg
# 		Create target group tg
# 		Create logical unit lu
# 		Add the view with hg, tg and lu
# 		List the view with -l with wrong logical unit name
# 		List the view with wrong logical unit name
# 	Test: 
# 		Verify the list failure
# 		Verify the return code               
# 	Cleanup:
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	list-view
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
function list010 {
	cti_pass
	tc_id="list010"
	tc_desc="Attempt to list view entry and attributes with wrong arguments"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		
	fs_zfs_create -V 1g $ZP/${VOL[1]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}

	eval guid0=\$LU_${VOL[0]}_GUID
	eval guid1=\$LU_${VOL[1]}_GUID

	stmfadm_create POS hg ${HG[0]}

	stmfadm_create POS tg ${TG[0]}
	
	stmfadm_add POS view -h ${HG[0]} -t ${TG[0]} -n 0 $guid0
	sbdadm_delete_lu POS $guid1
	
	stmfadm_list NEG view -l $guid1	
	
	tp_cleanup
	clean_fs zdsk
}
