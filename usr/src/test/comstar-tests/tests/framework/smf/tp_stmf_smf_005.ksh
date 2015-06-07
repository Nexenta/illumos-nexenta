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
# ID: smf005
# 
# DESCRIPTION:
# 	Verify that all the LUs will be offlined when stmf is disabled
# 
# STRATEGY:
# 
# 	Setup:
#		Build zpool for backing store
#		stmf smf is enabled be default
# 		Create two LUs with the default onlined state
#		Offline one LU
# 	Test: 
#		Disable stmf smf service by svcadm
#		Verify all the LUs are offlined
# 	Cleanup:
#		Delete the existing LU
#		Destroy the exising zpool	
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
#	svcadm disalbe stmf
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
function smf005 {
	cti_pass
	tc_id="smf005"
	tc_desc="Verify disable stmf service will offline all the onlined LUs"
	print_test_case $tc_id - $tc_desc
	
	build_fs zdsk
        fs_zfs_create -V 1g $ZP/${VOL[0]}
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
        fs_zfs_create -V 1g $ZP/${VOL[1]}
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}

	eval guid=\$LU_${VOL[0]}_GUID
	stmfadm_offline POS lu $guid

	stmf_smf_disable

	stmfadm_verify lu

	tp_cleanup
	clean_fs zfs
}
