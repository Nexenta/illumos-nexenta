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
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: remove008
# 
# DESCRIPTION:
# 	Attempt to remove an online target group member from a target group 
#	when stmf is enabled and verify its failure
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is enabled
# 		Create a target group with specified name
#		Online the FC targets by stmfadm online-target operation
# 		Add these FC targets port wwn into the target group
#		Remove the FC targets from the target group
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
function remove008 {
	cti_pass
	tc_id="remove008"
	tc_desc="Attempt to remove an online target from target group with stmf enabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable

	stmfadm_create POS tg ${TG[0]}

	for port in $G_TARGET
	do
		stmfadm_online POS target $port 
		stmfadm_add POS tg-member -g ${TG[0]} $port
	done
	for port in $G_TARGET
	do
		stmfadm_remove NEG tg-member -g ${TG[0]} $port
	done

	tp_cleanup

}

