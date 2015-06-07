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
# A test purpose file to test functionality of the list-hg subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: list002
# 
# DESCRIPTION:
# 	Attempt to list host group and member elememts attribute 
# 	with wrong arguments
# 
# STRATEGY:
# 
# 	Setup:
# 		List the host group by non-existing group name
# 		List the host group with -v by non-existing group name
# 	Test: 
# 		Verify the list failure
# 		Verify the return code               
# 	Cleanup:
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	list-hg
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
function list002 {
	cti_pass
	tc_id="list002"
	tc_desc="Attempt to list host group and member elememts"
	tc_desc="$tc_desc attribute with wrong arguments"
	print_test_case $tc_id - $tc_desc

	stmfadm_list NEG hg ${HG[0]}
	stmfadm_list NEG hg -v ${HG[0]}	
	
	tp_cleanup

	

}
