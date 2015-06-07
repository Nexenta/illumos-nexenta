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
# A test purpose file to test functionality of the remove-tg-member subfunction
# of the stmfadm command with iscsi target node.
#
# __stc_assertion_start
# 
# ID: tgmember010
# 
# DESCRIPTION:
# 	Verify that remove an iscsi target node from target group 
#	when stmf is disabled and iscsi/target is disabled
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is enabled
# 		iscsi/target service is enabled
# 		Create a target group with specified name
#		Create a default iscsi target node
#		Online the iscsi target node by stmfadm online-target operation
# 		Add the iscsi target node into the target group
#		Disable stmf service
#		Disable iscsi/target service
#		Remove the iscsi target node from the target group
# 	Test: 
# 		Verify the removal success
# 		Verify the return code               
# 	Cleanup:
# 		Delete target group
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	remove-tg-member
# 
# TESTABILITY: explicit
# 
# AUTHOR: John.Gu@Sun.COM
# 
# REVIEWERS:
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS
# 
# __stc_assertion_end
function tgmember010 {
	cti_pass
	tc_id="tgmember010"
	tc_desc="Verify that remove an target from target group with stmf disabled"
	tc_desc="$tc_desc and iscsi/target disabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	iscsi_target_smf_enable

	stmfadm_create POS tg ${TG[0]}
	itadm_create POS target -n "${IQN_TARGET}"

	stmfadm_offline POS target "${IQN_TARGET}"
	stmfadm_add POS tg-member -g ${TG[0]} "${IQN_TARGET}"

	stmf_smf_disable
	iscsi_target_smf_disable
	stmfadm_remove POS tg-member -g ${TG[0]} "${IQN_TARGET}"

	stmf_smf_enable
	iscsi_target_smf_enable
	tp_cleanup

}

