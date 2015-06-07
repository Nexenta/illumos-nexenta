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
# ID: create005
# 
# DESCRIPTION:
# 	Attempt to create a logical unit that is not modulus 1024 
# 	and verify that the creation fails.
# 
# STRATEGY:
# 
# 	Setup:
# 		Attempt to create a logical unit with a size 
# 		that is NOT divisible by 1024
# 	Test: 
# 		Verify the creation of the logical unit fails
# 	Cleanup:
# 		Delete the logical unit if it was created
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
function create005 {
	cti_pass
	tc_id="create005"
	tc_desc="Attempt to create a logical unit that is not modulus 1024"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}

	sbdadm_create_lu NEG -s 1048577 $DEV_ZVOL/$ZP/${VOL[0]}

	tp_cleanup
	clean_fs zdsk
	
}




