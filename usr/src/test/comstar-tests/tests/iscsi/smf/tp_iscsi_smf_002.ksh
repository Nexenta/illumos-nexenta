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
# A test purpose file to test functionality of iscsi/target smf
#

# __stc_assertion_start
#
# ID: iscsi_smf_002
#
# DESCRIPTION:
#	Verify itadm can not create obejcts when iscsi/target disabled
#
# STRATEGY:
#	Setup:
#		Enable stmf smf
#		Disable iscsi/target smf
#	Test:
#		Attempt to create target portal group tag 1
#		Attempt to create target node with tag 1
#			
#	Cleanup:
#		Delete the target portal group
#		Delete the target node
#
#	STRATEGY_NOTES:
#
# TESTABILITY: explicit
#
# AUTHOR: john.gu@sun.com
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
function iscsi_smf_002
{
	cti_pass

        tc_id="iscsi_smf_002"
	tc_desc="Verify itadm can not create obejcts when iscsi/target disabled"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	iscsi_target_smf_disable

	eval set -A portal $(get_portal_list $ISCSI_THOST)

	itadm_create NEG tpg 1 ${portal[0]}
	itadm_create NEG target -t 1

	iscsi_target_smf_enable
	tp_cleanup
}
