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
# ID: add014
# 
# DESCRIPTION:
# 	Attempt to add the conflict view with specified logical unit
# 
# STRATEGY:
# 
# 	Setup:
# 		Create the logical unit lu
# 		Create the host group hg1 hg2
# 		Create the target group tg1 tg2
# 		Add the view with hg1, tg1 and lun=0
# 		Attempt to add the same view with hg1, tg1 and lun=0
# 	Test: 
# 		Verify the view addition failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete the logical unit lu
# 		Delete the host group hg1 hg2
# 		Delete the target group tg1 tg2
# 		Delete the logical unit lu
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
function add014 {
	cti_pass
	tc_id="add014"
	tc_desc="Attempt to add the conflict view with specified logical unit"
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
	stmfadm_add NEG view -h ${HG[0]} -t ${TG[0]} -n 0 $guid
	
	tp_cleanup
	clean_fs zdsk

}
