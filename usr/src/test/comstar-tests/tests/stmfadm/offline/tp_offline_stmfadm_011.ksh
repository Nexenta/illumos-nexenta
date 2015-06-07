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
# A test purpose file to test the behavior of stmfadm sub-command operation
# when stmf is offlined.

#
# __stc_assertion_start
# 
# ID: offline011
# 
# DESCRIPTION:
# 	Verify that add-view subcommand can be operated even stmf is offlined
# 
# STRATEGY:
# 
# 	Setup:
#		Build zpool for backing store
#		stmf smf is enabled be default
# 		Create one LU, which is onlined by default 
#		Create one host group and target group
# 	Test: 
#		Disable stmf smf service by svcadm
#		run "stmfadm add-view" and verify its PASS
# 	Cleanup:
#		Delete the existing LU
#		Delete the existing host and target group
#		Destroy the exising zpool	
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
#	stmfadm add-view
# 
# TESTABILITY: explicit
# 
# AUTHOR: John.Gu@Sun.COM
# 
# REVIEWERS:
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS (2009-04-23)
# 
# __stc_assertion_end
function offline011 {
	cti_pass
	tc_id="offline011"
	tc_desc="Verify add-view subcommand can be operated even stmf is offlined"
	print_test_case $tc_id - $tc_desc
	
	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	eval guid=\$LU_${VOL[0]}_GUID

	stmfadm_create POS hg ${HG[0]}
	stmfadm_create POS tg ${TG[0]}
	stmf_smf_disable

	stmfadm_add POS view -t ${TG[0]} -h ${HG[0]} $guid

	tp_cleanup
	clean_fs zfs
}
