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
# A test purpose file to test functionality of the remove-view subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: remove007
# 
# DESCRIPTION:
# 	Attempt to remove the view with wrong options to verify
# 	the view removal functionality
# 
# STRATEGY:
# 
# 	Setup:
# 		Create the logical unit lu
# 		Create the target group tg1 tg2
# 		Create the host group hg1 hg2
# 		Add the view with hg1, tg1 and lun=0
# 		Add the view with hg1, tg2 and lun=1
# 		Add the view with hg2, tg1  
# 		Add the view with tg2, tg2 
# 		Remove the view with ve=0
# 		Attempt to remove the view with ve=0 ve=1
# 		Remove the view with -a
# 		Attempt to remove the view with ve=2 ve=4
# 		Attempt to remove the view with wrong sort of -a and -l
# 	Test: 
# 		Verify the view removal failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete the logical unit lu
# 		Delete the host group hg1 hg2
# 		Delete the target group tg1 tg2
# 		Delete the logical unit lu
# 		Remove the existing views 
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
function remove007 {
	cti_pass
	tc_id="remove007"
	tc_desc="Remove the view with wrong options"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	eval guid=\$LU_${VOL[0]}_GUID

	stmfadm_create POS hg ${HG[0]}
	stmfadm_create POS hg ${HG[1]}

	stmfadm_create POS tg ${TG[0]}
	stmfadm_create POS tg ${TG[1]}
	
	stmfadm_add POS view -h ${HG[0]} -t ${TG[0]} -n 0 $guid
	stmfadm_add POS view -h ${HG[0]} -t ${TG[1]} -n 1 $guid
	stmfadm_add POS view -h ${HG[1]} -t ${TG[0]} $guid
	stmfadm_add POS view -h ${HG[1]} -t ${TG[1]} $guid

	stmfadm_remove POS view -l $guid 0
	stmfadm_remove NEG view -l $guid 0 1

	stmfadm_remove POS view -l $guid -a
	stmfadm_remove NEG view -l $guid 2 4
	stmfadm_remove NEG view -l -a $guid 
	
	tp_cleanup
	clean_fs zdsk

}

