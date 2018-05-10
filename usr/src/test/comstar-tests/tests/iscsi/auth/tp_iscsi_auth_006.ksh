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
# A test purpose file to test functionality of chap authentication
#

# __stc_assertion_start
#
# ID: iscsi_auth_006
#
# DESCRIPTION:
#	Attempt to establish TCP connection and discovery the LU with
#	bi-directional "CHAP" authentication configured when any
#	uni-directional authentication fails and
#	verify its failure on initiator host
#
# STRATEGY:
#	Setup:
#		Create target portal group with specified tag 1 and ip address
#		Create target node with tpgt 1 with specified auth-method of
#		    "chap" authentication
#		Modify initiator node authentication property with specified
#		    chap user1 and secret1 on initiator host by iscsiadm
#		    modify initiator-node option
#		Modify the specified initiator node authentication property on
#		    target host by the same chap user1 and secret1 on initiator
#		    host by itadm modify-initiator option
#		Modify target node authentication property with specified
#		    chap user3 and secret3 on target host by itadm modify-target
#		    option
#		Modify the specified target node authentication property on
#		    initiator host by the same chap user4 and secret4 on target
#		    host by iscsiadm modify target-param option
#		Create a LU on target host by zfs file system
#		Create the view of LU by default to all target and host groups
#		Setup initiator node to enable "SendTarget" method
#		Setup SendTarget with discovery address on initiator host
#	Test:
#		Check that device path of specified LU can NOT be visible by
#		    iscsi initiator node
#		Check that iscsi initiator node has no active connection
#	Cleanup:
#		Delete the target portal group
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
function iscsi_auth_006
{
	cti_pass

        tc_id="iscsi_auth_006"

	tc_desc="Attempt to establish TCP connection and discovery the LU with"
	tc_desc="${tc_desc} bi-directional CHAP authentication configured when"
	tc_desc="${tc_desc} any uni-directional authentication fails and verify"
	tc_desc="${tc_desc} its failure on initiator host"
	print_test_case $tc_id - $tc_desc

	stmsboot_enable_mpxio $ISCSI_IHOST

	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})

	typeset t="${IQN_TARGET}.${TARGET[1]}"
	# Create target and target protal group
	itadm_create POS tpg 1 "${portal_list[0]}"
	itadm_create POS target -n ${t} -t 1 -a chap

	# Set initiator chap properities on initiator host
	iscsiadm_modify POS "${ISCSI_IHOST}" initiator-node -C "123456789012" 
	iscsiadm_modify POS "${ISCSI_IHOST}" initiator-node -H "i_chap_user" 

	# Set initiator chap properities on target host
	typeset i_node_name="$(iscsiadm_i_node_name_get ${ISCSI_IHOST})"
	itadm_create POS initiator -s "123456789012" "${i_node_name}" 
	itadm_modify POS initiator -u "i_chap_user" "${i_node_name}" 

	# Set target chap properities on target host
	itadm_modify POS target -s "120123456789" "${t}" 
	itadm_modify POS target -u "t_chap_user" "${t}" 

	# Set target chap properities on initiator host
	iscsiadm_modify POS "${ISCSI_IHOST}" target-param -C "120123456789_2" ${t}
	iscsiadm_modify POS "${ISCSI_IHOST}" target-param -H "t_chap_user_2" ${t}
	iscsiadm_modify POS "${ISCSI_IHOST}" target-param -B "enable" ${t}
	iscsiadm_modify POS "${ISCSI_IHOST}" target-param -a "CHAP" ${t}

	#Create lu 	
        build_fs zdsk
        fs_zfs_create -V 1g $ZP/${VOL[0]}    
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}

	typeset guid
	eval guid=\$LU_${VOL[0]}_GUID
	# Add view
	stmfadm_add POS view "${guid}"
	# Online lu
	stmfadm_online POS lu "${guid}"
	# Online target
	stmfadm_online POS target "${IQN_TARGET}.${TARGET[1]}"

	# Set discover address
	iscsiadm_add POS ${ISCSI_IHOST} discovery-address "${portal_list[0]}"

	# Enable sendTargets discovery method
	iscsiadm_modify POS ${ISCSI_IHOST} discovery -t enable

	# Verify the lun on initiator host
	iscsiadm_verify ${ISCSI_IHOST} lun

	tp_cleanup
        clean_fs zdsk
	initiator_cleanup "${ISCSI_IHOST}"
}
