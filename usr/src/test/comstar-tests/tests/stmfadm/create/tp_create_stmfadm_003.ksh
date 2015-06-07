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
# A test purpose file to test functionality of the create-hg subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: create003
# 
# DESCRIPTION:
# 	Attempt to create a host group with specified name 
# 	which is already existed
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a host group with specified name
# 		Repeat the same creation instruction
# 	Test: 
# 		Verify the creation failure
# 		Verify the return code               
# 	Cleanup:
# 		Delete the created host group
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	create-hg
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
function create003 {
	cti_pass
	tc_id="create003"
	tc_desc="Attempt to create a duplicated host group" 
	print_test_case $tc_id - $tc_desc

	stmfadm_create POS hg ${HG[0]}
	
	stmfadm_create NEG hg ${HG[0]}

	tp_cleanup

}
