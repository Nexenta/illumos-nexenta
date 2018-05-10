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
# ID: offline010
# 
# DESCRIPTION:
# 	Verify that add-tg-member can be operated even stmf smf is offlined
# 
# STRATEGY:
# 
# 	Setup:
#		stmf smf is enabled be default
# 		create one target group
# 	Test: 
#		Disable stmf smf service by svcadm
#		run "stmfadm add-tg-member" and verify its PASS
#       Cleanup:
#		Delete the existing target group
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
#	stmfadm add-tg-member
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
function offline010 {
	cti_pass
	tc_id="offline010"
	tc_desc="Verify stmfadm add-tg-member can be operated even stmf is offlined"
	print_test_case $tc_id - $tc_desc
	
	stmfadm_create POS tg ${TG[0]}
	stmf_smf_disable

	for port in $G_TARGET
	do
		stmfadm_add POS tg-member -g ${TG[0]} $port
	done

	tp_cleanup
}