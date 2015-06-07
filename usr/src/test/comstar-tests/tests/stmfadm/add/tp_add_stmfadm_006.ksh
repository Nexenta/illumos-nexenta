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
# ID: add006
# 
# DESCRIPTION:
# 	Attempt to add a target group member to two different target groups 
# 
# STRATEGY:
# 
# 	Setup:
# 		stmf service is disabled
# 		Create the target group A with specified name
# 		Create the target group B with specified name
# 		Add a fibre channel initiator port wwn into the target group A
# 		Add an iSCSI initiator node name into the target group A
# 		Add the same fibre channel initiator port wwn into the target group B
# 		Add the same iSCSI initiator node name into the target group B
# 	Test: 
# 		Verify the addition failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete the target group A
# 		Delete the target group B
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
function add006 {
	cti_pass
	tc_id="add006"
	tc_desc="Attempt to add a target group member to two different target groups"
	print_test_case $tc_id - $tc_desc

	stmf_smf_disable
	
	stmfadm_create POS tg ${TG[0]}
	stmfadm_create POS tg ${TG[1]}

	stmfadm_add POS tg-member -g ${TG[0]} wwn.200000e08b909220
	stmfadm_add POS tg-member -g ${TG[0]} eui.200000e08b909220
	stmfadm_add POS tg-member -g ${TG[0]} iqn.1986-03.com.sun:01.46f7e260
	
	stmfadm_add NEG tg-member -g ${TG[1]} wwn.200000e08b909220
	stmfadm_add NEG tg-member -g ${TG[1]} eui.200000e08b909220
	stmfadm_add NEG tg-member -g ${TG[1]} iqn.1986-03.com.sun:01.46f7e260

	stmf_smf_enable
	tp_cleanup

}
