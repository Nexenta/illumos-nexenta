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
# ID:smf002 
# 
# DESCRIPTION:
# 	Verify that modules can not be unloaded while stmf service is enabled
# 
# STRATEGY:
# 
# 	Setup:
# 		Enable stmf smf service
# 		Create LU
# 	Test: 
# 		Attempt to unload module sbd and verify its failure
# 		Delete LU
# 		Unload module sbd and verify its success
# 		Reload module sbd 
# 	Cleanup:
# 		Clean up 
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
function smf002 {
	cti_pass
	tc_id="smf002"
	tc_desc="Verify that modules can not be unloaded "
	tc_desc="$tc_desc while stmf service is enabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}
	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	typeset module_id=`/usr/sbin/modinfo | grep -w sbd |awk '{print \$1}'`
	if [ -n "$module_id"  ]; then
		cmd="/usr/sbin/modunload -i $module_id"
		run_generic_cmd NEG "$cmd"

		eval guid=\$LU_${VOL[0]}_GUID
		sbdadm_delete_lu POS $guid

		cmd="/usr/sbin/modunload -i $module_id"
		run_generic_cmd POS "$cmd"

		typeset bit=`isainfo -b`
		typeset uname=`uname -p`

		if [ $bit -eq 64 -a "$uname" = "i386" ];then
			cmd="/usr/sbin/modload /kernel/drv/amd64/sbd"
		elif [ $bit -eq 64 -a "$uname" = "sparc" ];then
			cmd="/usr/sbin/modload /kernel/drv/sparcv9/sbd"
		else
			cmd="/usr/sbin/modload /kernel/drv/sbd"
		fi

		run_generic_cmd POS "$cmd"
	fi

	tp_cleanup
	clean_fs zdsk
	
}
