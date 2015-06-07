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
# A test purpose file to test functionality of the modify-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: modify001
# 
# DESCRIPTION:
# 	Modify the attribute size to the new size of the existing logical unit
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit
# 		Modify the size attribute 
# 	Test: 
# 		The existing size of the logical unit is modified to the new size
# 	Cleanup:
# 		Delete the logical unit
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	modify-lu
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
function modify001 {
	cti_pass
	tc_id="modify001"
	tc_desc="Modify the attribute size to the new size"
	tc_desc="$tc_desc of the existing logical unit"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 2g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 512m $DEV_ZVOL/$ZP/${VOL[0]}
	sbdadm_modify_lu POS -s 1g $DEV_ZVOL/$ZP/${VOL[0]}	

	tp_cleanup
	clean_fs zdsk

}
