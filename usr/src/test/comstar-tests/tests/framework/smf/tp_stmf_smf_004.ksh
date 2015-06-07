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
# ID: smf004
# 
# DESCRIPTION:
# 	Verify that all the targets will be offlined when stmf is disabled
# 
# STRATEGY:
# 
# 	Setup:
#		stmf smf is enabled be default
# 		Create one target group
# 	Test: 
#		Disable stmf smf service by svcadm
#		run "stmfadm delete-tg " and verify its PASS
# 	Cleanup:
#		Delete the existing LU
#		Destroy the exising zpool	
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
#	stmfadm delete-tg
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
function smf004 {
	cti_pass
	tc_id="smf004"
	tc_desc="Verify disable stmf service will offline all the onlined targets"
	print_test_case $tc_id - $tc_desc
	
	stmf_smf_disable

	stmfadm_verify target

	tp_cleanup
}
