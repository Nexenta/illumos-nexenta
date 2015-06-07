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
# A test purpose file to test functionality of the add-view subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: add023
# 
# DESCRIPTION:
# 	Attempt to add the valid view with specified logical unit 
# 	and without lu number
# 
# STRATEGY:
# 
# 	Setup:
# 		Create the logical unit lu1 lu2
# 		Create the host group hg1 hg2
# 		Create the target group tg1 tg2
# 		Add the view with hg1, tg1 on lu1
# 		Add the view with hg2, tg2 on lu1
# 		Add the conflict view with hg2, tg2 and lun=0 on lu2
# 		Add the conflict view with hg2, and lun=0 on lu2
# 		Add the valid view with hg2, tg2 on lu2
# 	Test: 
# 		Verify the last view addition success
# 		Verify the return code               
# 	Cleanup:
# 		Delete the logical unit lu1 lu2
# 		Delete the host group hg1 hg2
# 		Delete the target group tg1 tg2
# 		Remove the existing view 
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	add-view
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
function add023 {
	cti_pass
	tc_id="add023"
	tc_desc="Add another view with different lu number for specified lu"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		
	fs_zfs_create -V 1g $ZP/${VOL[1]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}

	eval guid0=\$LU_${VOL[0]}_GUID
	eval guid1=\$LU_${VOL[1]}_GUID

	stmfadm_create POS hg ${HG[0]}
	stmfadm_create POS hg ${HG[1]}

	stmfadm_create POS tg ${TG[0]}
	stmfadm_create POS tg ${TG[1]}
	
	stmfadm_add POS view -h ${HG[0]} -t ${TG[0]}      $guid0
	stmfadm_add POS view -h ${HG[1]} -t ${TG[1]}      $guid0
	stmfadm_add NEG view -h ${HG[1]} -t ${TG[1]} -n 0 $guid1
	stmfadm_add NEG view -h ${HG[1]}             -n 0 $guid1
	stmfadm_add POS view -h ${HG[1]} -t ${TG[1]}      $guid1
	
	
	tp_cleanup
	clean_fs zdsk

}
