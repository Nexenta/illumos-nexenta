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
# ID: iscsi_visible_005
#
# DESCRIPTION:
#	initiator can update its target list when target are removed on target
#	side
#
# STRATEGY:
#	Setup:
#		1. Configure discovery address with <target side ip address>
#		   for initiator using iscsiadm add discovery-address
#
#		2. itadm create a target portal group with proper ip address
#
#		3. itadm create 3 targets with the created target portal group
#
#		4. Enable "SentTarget" discovery method on initiator using
#		   iscsiadm modify discovery -t enable
#
#		5. Check that the initiator have the 3 new created target in
#		   its target list
#	Test:
#		1. itadm delete the 2 targets on target side.
#
#		2. Wait a few second for initiator to update the information.
#		   (Is there any specification on how long should wait ?)
#
#		3. Verify that the initiator only have one target in its list
#
#	Cleanup:
#		1. Delete the targets, target portal group
#
#		2. Disable the discovery method on initiator and remove the
#		   discovery address
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
function tp_iscsi_visible_005
{
	cti_pass

        tc_id="tp_iscsi_visible_005"

	tc_desc="initiator can update its target list when target are"
	tc_desc="${tc_desc} removed on target side"
	print_test_case $tc_id - $tc_desc

	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})

	iscsiadm_add POS "${ISCSI_IHOST}" discovery-address "${portal_list[0]}"

	itadm_create POS tpg 1 "${portal_list[0]}"
	itadm_create POS target -n ${IQN_TARGET}:${TARGET[1]} -t 1
	itadm_create POS target -n ${IQN_TARGET}:${TARGET[2]} -t 1
	itadm_create POS target -n ${IQN_TARGET}:${TARGET[3]} -t 1

	iscsiadm_modify POS "${ISCSI_IHOST}" discovery -t enable
	iscsiadm_verify "${ISCSI_IHOST}" target 

	#iscsiadm_verify target 
	itadm_delete POS target -f ${IQN_TARGET}:${TARGET[1]}
	itadm_delete POS target -f ${IQN_TARGET}:${TARGET[2]}

	iscsiadm_modify POS "${ISCSI_IHOST}" discovery -t disable
	iscsiadm_modify POS "${ISCSI_IHOST}" discovery -t enable
	iscsiadm_verify "${ISCSI_IHOST}" target 

	tp_cleanup
	initiator_cleanup "${ISCSI_IHOST}"
}

