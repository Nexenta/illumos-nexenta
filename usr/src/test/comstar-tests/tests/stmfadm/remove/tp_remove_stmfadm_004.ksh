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
# ID: remove004
# 
# DESCRIPTION:
# 	A series of misconfigured command line arguments
# 
# STRATEGY:
# 
# 	Setup:
# 		Attempt to remove the target member 
# 		with the follwoing misconfigured command
# 		line options:
# 			- a non-existing target member
# 			- a non-existing target group
# 			- no target group name specified
# 			- target member and -g option are out of order
# 	Test: 
# 		Verify the removal failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete any existing target group
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
# CODING_STATUS: IN_PROGRESS (2008-02-14)
# 
# __stc_assertion_end
function remove004 {
	cti_pass
	tc_id="remove004"
	tc_desc="A series of misconfigured command line arguments"
	print_test_case $tc_id - $tc_desc

	stmfadm_create POS tg ${TG[0]}

	stmfadm_remove NEG tg-member -g ${TG[0]} wwn.200000e08b909220
	stmfadm_remove NEG tg-member -g ${TG[0]} iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG tg-member -g ${TG[0]} eui.200000e08b909229
	stmfadm_remove NEG tg-member -g ${TG[0]} iqn.1986-03.com.sun:01.46f7e269
	
	stmfadm_remove NEG tg-member -g ${TG[1]} wwn.200000e08b909220
	stmfadm_remove NEG tg-member -g ${TG[1]} .iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG tg-member -g ${TG[1]} eui.200000e08b909229
	stmfadm_remove NEG tg-member -g ${TG[1]} iqn.1986-03.com.sun:01.46f7e269

	stmfadm_remove NEG tg-member -g          wwn.200000e08b909220
	stmfadm_remove NEG tg-member -g          iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG tg-member -g          eui.200000e08b909229
	stmfadm_remove NEG tg-member -g          iqn.1986-03.com.sun:01.46f7e269

	stmfadm_remove NEG tg-member wwn.200000e08b909220 -g ${TG[1]}
	stmfadm_remove NEG tg-member iqn.1986-03.com.sun:01.46f7e260 -g ${TG[1]}
	stmfadm_remove NEG tg-member eui.200000e08b909229 -g ${TG[1]}
	stmfadm_remove NEG tg-member iqn.1986-03.com.sun:01.46f7e269 -g ${TG[1]}

	tp_cleanup

}
