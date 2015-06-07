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
# ID:smf003 
# 
# DESCRIPTION:
# 	Verify that modules can be loaded/unloaded while stmf service is disabled
# 
# STRATEGY:
# 
# 	Setup:
# 		Disable stmf smf service
# 		unload and reload sbd module
# 		unload and reload fct module
# 		unload and reload qlt module
# 		unload and reload stmf module
# 	Test: 
# 		Verify the module load and unload success
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
function smf003 {
	cti_pass
	tc_id="smf003"
	tc_desc="Verify that modules can be loaded/unloaded"
	tc_desc="$tc_desc while stmf service is disabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_disable

	typeset module_id=`/usr/sbin/modinfo | grep -w sbd |awk '{print \$1}'`
	if [ -n "$module_id"  ]; then
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

	stmf_smf_enable
}
