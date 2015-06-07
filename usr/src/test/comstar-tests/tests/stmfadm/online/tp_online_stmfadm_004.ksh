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
# A test purpose file to test functionality of the online-target subfunction
# of the stmfadm command.

#
# __stc_assertion_start
# 
# ID: online004
# 
# DESCRIPTION:
# 	Switch the state of specified fc target from offline to online
# 
# STRATEGY:
# 
# 	Setup:
# 		Offline the specified fc target 
# 		Online the specified fc target 
# 	Test: 
# 		Verify that list-target shows the online/offline state switch
# 		Verify that fcinfo hba-port shows the online/offline state switch
# 		Verify the return code               
# 	Cleanup:
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	online-target
# 	offline-target
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
function online004 {
	cti_pass
	tc_id="online004"
	tc_desc="Switch the state of specified fc target from offline to online"
	print_test_case $tc_id - $tc_desc
	
	for portWWN in $G_TARGET
	do
		stmfadm_online POS target $portWWN
		stmfadm_offline POS target $portWWN
	done
	
	for portWWN in $G_TARGET
	do
		stmfadm_online POS target $portWWN
	done

}
