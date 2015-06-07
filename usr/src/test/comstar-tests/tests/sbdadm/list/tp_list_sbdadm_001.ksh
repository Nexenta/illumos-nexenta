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
# ID: list001
# 
# DESCRIPTION:
# 	List all logical units that were created using sbdadm create-lu command
# 
# STRATEGY:
# 
# 	Setup:
# 		Create the n logical units
# 		Run the subcommand with -? option
# 		List all the existing logical units
# 	Test: 
# 		The output is equal to what were created
# 	Cleanup:
# 		Delete the logical units
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
function list001 {
	cti_pass
	tc_id="list001"
	tc_desc="List all logical units that were created"
	tc_desc="$tc_desc using sbdadm create-lu command"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk

	fs_zfs_create -V 1g $ZP/${VOL[0]}	
	sbdadm_create_lu POS -s 1m $DEV_ZVOL/$ZP/${VOL[0]}
	
	fs_zfs_create -V 1g $ZP/${VOL[1]}	
	sbdadm_create_lu POS -s 1m $DEV_ZVOL/$ZP/${VOL[1]}

	sbdadm_list_lu POS
	sbdadm_list_lu POS -?
	
	tp_cleanup
	clean_fs zdsk


}
