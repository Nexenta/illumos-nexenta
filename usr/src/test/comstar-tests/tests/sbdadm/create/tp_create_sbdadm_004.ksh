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
# A test purpose file to test functionality of the create-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: create004
# 
# DESCRIPTION:
# 	Create the logical unit using the values listed multiplied by
# 	the 1024 multiplier and verify that the luns were created correctly
# 
# STRATEGY:
# 
# 	Setup:
# 		Create the logical units
# 	Test: 
# 		Verify the logical unit is created 
# 		Verify the return code               
# 	Cleanup:
# 		Delete all the logical units
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	create-lu
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
function create004 {
	cti_pass
	tc_id="create004"
	tc_desc="Create logical units with a size being a multiple of 1024,"
	tc_desc="$tc_desc without using a multiplier(e.g 20m)"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 20m $DEV_ZVOL/$ZP/${VOL[0]}

	tp_cleanup
	clean_fs zdsk

	
}



