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
# ID: add020
# 
# DESCRIPTION:
# 	Verify to add a target group member to a target group when stmf enabled
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is enabled
# 		Create a target group A
# 		Add a fibre channel initiator port wwn into target group A
# 		Add an iSCSI initiator node name into target group A
# 	Test: 
# 		Verify the addition success
# 		Verify the return code               
# 	Cleanup:
# 		Delete the target group A and its members
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
function add020 {
	cti_pass
	tc_id="add020"
	tc_desc="Verify to add a target group member to"
	tc_desc="$tc_desc target group successfully when stmf enabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	stmfadm_create POS tg ${TG[0]}

	stmfadm_add POS tg-member -g ${TG[0]} wwn.200000e08b909220
	stmfadm_add POS tg-member -g ${TG[0]} iqn.1986-03.com.sun:01.46f7e260
	stmfadm_add POS tg-member -g ${TG[0]} eui.200000e08b909229
	stmfadm_add POS tg-member -g ${TG[0]} iqn.1986-03.com.sun:01.46f7e269

	tp_cleanup

}
