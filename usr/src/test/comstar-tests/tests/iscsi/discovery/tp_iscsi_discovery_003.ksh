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
# A test purpose file to test functionality of target discovery
#

# __stc_assertion_start
#
# ID: iscsi_discovery_003
#
# DESCRIPTION:
#	Verify that iscsi target node can support the send-target discovery
#	by iscsi initiator node
#
# STRATEGY:
#	Setup:
#		Create target portal group with specified tag 1 and ip address 1
#		Create target node 1 with tpgt 1 and specified node name 1
#		Create target node 2 with tpgt 1 and specified node name 2
#		Setup initiator node to enable send-target discovery
#		Add the discovery-address to initiator node by iscsiadm
#		    add discovery-address option
#		    with specified ip address 1
#	Test:
#		Check that target node 1 can be visible by initiator node
#		Check that target node 2 can be visible by initiator node
#	Cleanup:
#		Delete the target node
#		Delete the configuration information in initiator and target
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
function iscsi_discovery_003
{
	cti_pass

        tc_id="iscsi_discovery_003"

	tc_desc="Verify that iscsi target node can support the send-target"
	tc_desc="${tc_desc} discovery by iscsi initiator node"
	print_test_case $tc_id - $tc_desc
	
	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})
	# Create target portal
	itadm_create POS tpg 1 "${portal_list[0]}"

	# Create target node
	itadm_create POS target -n "${IQN_TARGET}.${TARGET[0]}" -t 1
	itadm_create POS target -n "${IQN_TARGET}.${TARGET[1]}" -t 1
	
	# Enable sendTargets discovery on initiator host
	iscsiadm_modify POS "${ISCSI_IHOST}" discovery -t "enable" 
	iscsiadm_add POS "${ISCSI_IHOST}" discovery-address "${portal_list[0]}" 

	iscsiadm_verify ${ISCSI_IHOST} target

	tp_cleanup
	initiator_cleanup "${ISCSI_IHOST}"
}

