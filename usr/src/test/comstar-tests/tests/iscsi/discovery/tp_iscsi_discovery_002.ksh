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
# ID: iscsi_discovery_002
#
# DESCRIPTION:
#	iSCSI target port provider can register into the default discovery
#	domain of iSNS server and be visible by initiator node in the same
#	default discovery domain
#
# STRATEGY:
#	Setup:
#		Setup iSNS server ip address on initiator host
#		Modify default settings to isns enable and configure the isns
#		    server ip address and port on target host
#		Create target node with specified node name by
#		    itadm create-target option
#		Enable isns_server service on initiator host
#	Test:
#		Check that target node can be visible by initiator node
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
function iscsi_discovery_002
{
	cti_pass

        tc_id="iscsi_discovery_002"

	tc_desc="iSCSI target port provider can register into the default"
	tc_desc="${tc_desc} discovery domain of iSNS server and be visible by"
	tc_desc="${tc_desc}  initiator node in the same default discovery domain"
	print_test_case $tc_id - $tc_desc

	typeset t="${IQN_TARGET}.${TARGET[0]}"

	# Setup isns server ip address on initiator host
	iscsiadm_add POS "${ISCSI_IHOST}" isns-server "${ISNS_HOST}" 

	# Enable isns service on target host
	itadm_modify POS defaults -I "${ISNS_HOST}"
	itadm_modify POS defaults -i "enable"

	# Create target 
	itadm_create POS target -n ${t}

	# Enable isns discovery on initiator host
	iscsiadm_modify POS "${ISCSI_IHOST}" discovery -i "enable" 

	# sleep for a while to give initiator update its target
	# list from isns server
	sleep 5
	iscsiadm_verify ${ISCSI_IHOST} target

	initiator_cleanup "${ISCSI_IHOST}"

	tp_cleanup
}

