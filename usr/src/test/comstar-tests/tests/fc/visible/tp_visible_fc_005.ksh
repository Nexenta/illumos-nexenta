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
# A test purpose file to test view visibility of the stmf framework.

#
# __stc_assertion_start
# 
# ID: visible005
# 
# DESCRIPTION:
# 	Verify the view visibility with all the host and target groups by default
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit lu
# 		Add the view entry with the logical unit lu
# 	Test: 
# 		Verify that initiator can visit the logical unit
# 	Cleanup:
# 		Delete the host group
# 		Delete the target group
# 		Delete the logical unit
# 		Delete the view entry
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	stmfadm add-view
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
function visible005 {
	cti_pass
	tc_id="visible005"
	tc_desc="Verify the view visibility with all the host"
	tc_desc="$tc_desc and target groups by default"
	print_test_case $tc_id - $tc_desc
	
	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		
	fs_zfs_create -V 1g $ZP/${VOL[1]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}
	eval guid0=\$LU_${VOL[0]}_GUID
	eval guid1=\$LU_${VOL[1]}_GUID

	stmsboot_enable_mpxio $FC_IHOST

	stmfadm_add POS view $guid0
	stmfadm_add POS view $guid1


	stmfadm_verify initiator

	tp_cleanup
	clean_fs zdsk

}
