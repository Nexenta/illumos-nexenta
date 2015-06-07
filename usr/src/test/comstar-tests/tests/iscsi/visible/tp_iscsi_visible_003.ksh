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
# ID: iscsi_visible_003
#
# DESCRIPTION:
#	itadm delete-target command fails to delete a target which already been
#	added into a target group by stmfadm add-tg-member command.
#
# STRATEGY:
#	Setup:
#		1. itadm create a target
#		2. stmfadm create a target group and add the target into the
#		   group
#	Test:
#		1. itadm delete the target
#
#		2. Verify that the no target is deleted and returns an
#		   appropriate error message
#
#	Cleanup:
#		1. Remove the target group
#		1. Delete the target
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
function tp_iscsi_visible_003
{
	cti_pass

        tc_id="tp_iscsi_visible_003"
	tc_desc="itadm delete-target command fails to delete a target which"
	tc_desc="${tc_desc} already been added into a target group by stmfadm"
	tc_desc="${tc_desc} add-tg-member command."

	print_test_case $tc_id - $tc_desc

	itadm_create POS target -n ${IQN_TARGET}
	stmfadm_create POS tg ${TG[0]}
	stmf_smf_disable
	stmfadm_add POS tg-member -g ${TG[0]} ${IQN_TARGET}
	stmf_smf_enable
	itadm_delete NEG target ${IQN_TARGET}

	tp_cleanup

}

