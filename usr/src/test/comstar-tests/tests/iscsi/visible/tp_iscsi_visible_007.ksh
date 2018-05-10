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
# ID: iscsi_visible_007
#
# DESCRIPTION:
#	initiator keep update the lun information through the target when
#	the luns are changed on the target side.
#
# STRATEGY:
#	Setup:
#		1. Configure discovery address with <target side ip address>
#		   for initiator using iscsiadm add discovery-address
#
#		2. itadm create a target portal group with proper ip address
#
#		3. itadm create 1 target with the created target portal group
#
#		4. Create and online 3 luns and bound it to the target in stmf
#	 	   frame.
#
#		5. Enable "SentTarget" discovery method on initiator using
#		   iscsiadm modify discovery -t enable
#
#		6. Check that the initiator can see the three new created
#		   luns with online status
#
#	Test:
#		1. Delete lun 1 in stmf frame
#
#		2. Offline lun 2 in stmf frame
#
#		3. Verify that the initiator have lun 2 and lun 3 under the target
#		   lun list
#	Cleanup:
#		1. Delete the target luns, target, target portal group
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
function tp_iscsi_visible_007
{
	cti_pass

        tc_id="tp_iscsi_visible_007"

	tc_desc="initiator keep update the lun information through the target"
	tc_desc="${tc_desc} when the luns are changed on the target side."
	print_test_case $tc_id - $tc_desc

	# Set discover address
	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})

	iscsiadm_add POS ${ISCSI_IHOST} discovery-address \
		 "${portal_list[0]}"

	# Create target and target protal group
	itadm_create POS tpg 1 "${portal_list[0]}"
	itadm_create POS target -n ${IQN_TARGET}.${TARGET[0]} -t 1

	#Create lu 	
        build_fs zdsk
        fs_zfs_create -V 1g $ZP/${VOL[0]}    
        fs_zfs_create -V 1g $ZP/${VOL[1]}    
        fs_zfs_create -V 1g $ZP/${VOL[2]}    
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[1]}
        sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[2]}

	typeset guid1 guid2 guid3

	eval guid1="\$LU_${VOL[0]}_GUID"
	eval guid2="\$LU_${VOL[1]}_GUID"
	eval guid3="\$LU_${VOL[2]}_GUID"

	# Add view
	stmfadm_add POS view "${guid1}"
	stmfadm_add POS view "${guid2}"
	stmfadm_add POS view "${guid3}"

	# Enable sendTargets discovery method
	iscsiadm_modify POS ${ISCSI_IHOST} discovery -t enable
	# Verify the lun on initiator host
	iscsiadm_verify ${ISCSI_IHOST} lun
	
	sbdadm_delete_lu POS "${guid1}"
	stmfadm_offline POS lu "${guid3}"
	
	# Enable sendTargets discovery method to update information
	iscsiadm_modify POS ${ISCSI_IHOST} discovery -t enable
	# Verify the lun on initiator host
	iscsiadm_verify ${ISCSI_IHOST} lun

	tp_cleanup
        clean_fs zdsk
	initiator_cleanup "${ISCSI_IHOST}"

}
