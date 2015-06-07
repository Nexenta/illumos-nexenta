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
# A test purpose file to test functionality of the remove-hg-member subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: remove003
# 
# DESCRIPTION:
# 	A series of misconfigured command line arguments
# 
# STRATEGY:
# 
# 	Setup:
# 		Attempt to remove the host member 
# 		with the follwoing misconfigured command
# 		line options:
# 			- a non-existing host member
# 			- a non-existing host group
# 			- no host group name specified
# 			- host member and -g option are out of order
# 	Test: 
# 		Verify the removal failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete any existing host group
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	remove-hg-member
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
function remove003 {
	cti_pass
	tc_id="remove003"
	tc_desc="A series of misconfigured command line arguments"
	print_test_case $tc_id - $tc_desc

	stmfadm_create POS hg ${HG[0]}

	stmfadm_remove NEG hg-member -g ${HG[0]} wwn.200000e08b909220
	stmfadm_remove NEG hg-member -g ${HG[0]} iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG hg-member -g ${HG[0]} eui.200000e08b909229
	stmfadm_remove NEG hg-member -g ${HG[0]} iqn.1986-03.com.sun:01.46f7e269
	
	stmfadm_remove NEG hg-member -g ${HG[1]} wwn.200000e08b909220
	stmfadm_remove NEG hg-member -g ${HG[1]} iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG hg-member -g ${HG[1]} eui.200000e08b909229
	stmfadm_remove NEG hg-member -g ${HG[1]} iqn.1986-03.com.sun:01.46f7e269

	stmfadm_remove NEG hg-member -g          wwn.200000e08b909220
	stmfadm_remove NEG hg-member -g          iqn.1986-03.com.sun:01.46f7e260
	stmfadm_remove NEG hg-member -g          eui.200000e08b909229
	stmfadm_remove NEG hg-member -g          iqn.1986-03.com.sun:01.46f7e269

	stmfadm_remove NEG hg-member wwn.200000e08b909220 -g ${HG[1]}
	stmfadm_remove NEG hg-member iqn.1986-03.com.sun:01.46f7e260 -g ${HG[1]}
	stmfadm_remove NEG hg-member eui.200000e08b909229 -g ${HG[1]}
	stmfadm_remove NEG hg-member iqn.1986-03.com.sun:01.46f7e269 -g ${HG[1]}

	tp_cleanup

	

}
