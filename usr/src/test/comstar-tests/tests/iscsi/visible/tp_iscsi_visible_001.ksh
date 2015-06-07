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
# A test purpose file to test data visibility related with
# iscsi target port provider
#

# __stc_assertion_start
#
# ID: iscsi_visible_001
#
# DESCRIPTION:
#	Once itadm crated a target, stmfadm can show the target
#	using stmfadm list-target
#
# STRATEGY:
#	Setup:
#		1. itadm create taget
#	Test:
#		1. stmfadm list target -v
#		2. Verify the target is in the list
#	Cleanup:
#		Delete the created target
#
#	STRATEGY_NOTES:
#
# TESTABILITY: explicit
#
# AUTHOR: zheng.he@sun.com
#
# REVIEWERS:
#
# ASSERTION_SOURCE:
#
# TEST_AUTOMATION_LEVEL: automated
#
# STATUS: IN_PROGRESS
#
# COMMENTS:
#
# __stc_assertion_end
#
function tp_iscsi_visible_001
{
	cti_pass

        tc_id="tp_iscsi_visible_001"
	tc_desc="Once itadm crated a target, stmfadm can show the target"
	tc_desc="${tc_desc} using stmfadm list-target"
	print_test_case $tc_id - $tc_desc

	itadm_create POS target -n ${IQN_TARGET}

	tp_cleanup

}

