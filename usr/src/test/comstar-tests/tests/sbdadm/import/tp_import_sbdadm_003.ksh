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
# A test purpose file to test functionality of the import-lu subfunction
# of the sbdadm command.

#
# __stc_assertion_start
# 
# ID: import003
# 
# DESCRIPTION:
# 	Import the logical unit which is deleted by option -k previously
# 	by filename to be available again 
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a logical unit
# 		Delete the logical unit with option -k
# 		Import the same logical unit by source 
# 	Test: 
# 		the logical unit is again made available to stmf
# 		the logical unit name is kept same
# 	Cleanup:
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	import-lu
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
function import003 {
	cti_pass
	tc_id="import003"
	tc_desc="Import the logical unit deleted by option -k "
	tc_desc="$tc_desc previously to be available again"
	print_test_case $tc_id - $tc_desc

	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	eval guid=\$LU_${VOL[0]}_GUID
	sbdadm_delete_lu POS -k $guid
	sbdadm_import_lu POS $DEV_ZVOL/$ZP/${VOL[0]}

	tp_cleanup
	clean_fs zdsk


}