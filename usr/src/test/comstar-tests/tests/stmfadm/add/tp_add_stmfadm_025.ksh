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
# ID: add025
# 
# DESCRIPTION:
# 	Add an offline target group member to a target group when stmf is enabled
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is enabled
# 		Create a target group with specified name
#		Offline the FC targets by stmfadm offline-target operation
# 		Add these FC targets port wwn into the target group
# 	Test: 
# 		Verify the addition success
# 		Verify the return code               
# 	Cleanup:
# 		Delete target group
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
# CODING_STATUS: IN_PROGRESS
# 
# __stc_assertion_end
function add025 {
	cti_pass
	tc_id="add025"
	tc_desc="Verify the offline target can be added into target group with stmf enabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable

	stmfadm_create POS tg ${TG[0]}

	for port in $G_TARGET
	do
		stmfadm_offline POS target $port
		stmfadm_add POS tg-member -g ${TG[0]} $port
	done

	tp_cleanup

}

