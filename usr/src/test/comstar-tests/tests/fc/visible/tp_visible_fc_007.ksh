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
# A test purpose file to test functionality of the add-tg-member subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: visible007
# 
# DESCRIPTION:
# 	Add a target group member to an empty target group which is already 
# 	added into some specified view to verify the lu visibility 
# 	from initiator host side 
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is disabled
# 		Create target group tg without members
# 		Create the logical unit lu
# 		Add the view with tg and lu( by default host group is All)
# 		Add a fibre channel target port wwn into the target group 
# 	Test: 
# 		Verify the logical unit lu is visible in initiator host side
# 		Verify the return code               
# 	Cleanup:
# 		Delete target group tg
# 		Delete the logical unit lu
# 		Delete the view with tg and lu
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	add-tg-member
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
function visible007 {
	cti_pass
	tc_id="visible007"
	tc_desc="Verify initiator can visit the logical unit in the same view"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	eval guid=\$LU_${VOL[0]}_GUID

	stmfadm_create POS tg ${TG[0]}
	stmfadm_add POS view -t ${TG[0]} $guid

	stmf_smf_disable
	for port in $G_TARGET
	do
		stmfadm_add POS tg-member -g ${TG[0]} $port
	done
	stmf_smf_enable

	stmsboot_enable_mpxio $FC_IHOST

	stmfadm_verify initiator

	tp_cleanup
	clean_fs zdsk

}
