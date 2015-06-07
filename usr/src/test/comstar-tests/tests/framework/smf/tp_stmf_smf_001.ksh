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
# A test purpose file to test functionality of the stmf service
# of the stmf framework.

#
# __stc_assertion_start
# 
# ID:smf001 
# 
# DESCRIPTION:
# 	Verify that stmf service can start and stop correctly
# 
# STRATEGY:
# 
# 	Setup:
# 		Enable stmf smf service
# 		Disable stmf smf service
# 	Test: 
# 		Verify the service status as expected
# 		Enable and Disable is supported
# 	Cleanup:
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	stmf smf
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
function smf001 {
	cti_pass
	tc_id="smf001"
	tc_desc="Verify that stmf service can start and stop correctly"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	
	stmf_smf_disable

	stmf_smf_disable

	stmf_smf_enable
	
}
