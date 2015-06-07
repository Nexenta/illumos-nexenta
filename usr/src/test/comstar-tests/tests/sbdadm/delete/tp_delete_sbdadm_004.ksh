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
# ID: delete004
# 
# DESCRIPTION:
# 	Verify delete-lu option will delete the logical unit from sbd depository
# 	all the relating views will be deleted automatically in stmf depository
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit 
# 		Create a target group by stmfadm
# 		Create a host group by stmfadm
# 		Add the view with the three association into stmf depository
# 		Delete the logical unit by sbdadm
# 	Test: 
# 		Verify the logical unit is deleted
# 		Verify the logical unit views are deleted in stmf depository
# 	Cleanup:
# 		Delete the view
# 		Delete the logical unit 
# 		Delete the target group
# 		Delete the host group
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
function delete004 {
	cti_pass
	tc_id="delete004"
	tc_desc="Verify delete-lu without -k opotion"
	tc_desc="$tc_desc delete the views in stmf repository"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	stmfadm_create POS hg ${HG[0]}
	stmfadm_create POS tg ${TG[0]}	

	eval guid=\$LU_${VOL[0]}_GUID
	stmfadm_add POS view -t ${TG[0]} -h ${HG[0]} $guid
	
	sbdadm_delete_lu POS $guid

	tp_cleanup
	clean_fs zdsk

}

