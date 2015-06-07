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
# A test purpose file to test functionality of backing storage
#

# __stc_assertion_start
#
# ID: iscsi_fs_004
#
# DESCRIPTION:
#	Running I/O data validation on RAW DEVICE backing store
#
# STRATEGY:
#	Setup:
#		MPXIO is enable on initiator host
#		Raw device LUs are created in iSCSI target host 
#		Map all the LUs can be accessed by all the target and host groups
#		    by stmfadm add-view option
#		Create one target portal group 1 with all the portals included
#		Create one target node with tpgt 1
#		Modify initiator target-param to allow all the initiator portals
#		    to create one session individually to support mutlti-pathing 
#		    with each target node
#		Setup initiator node to enable "SendTarget" method
#		Setup SendTarget with discovery address on initiator host
#	Test:
#		Start diskomizer on the initiator host
#		Running I/O for 5 minutes
#			
#	Cleanup:
#		Stop the diskomizer
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
function iscsi_fs_004
{
	cti_pass

        tc_id="iscsi_fs_004"
	tc_desc="verify I/O data validation can pass RAW DEVICE backing store"
	print_test_case $tc_id - $tc_desc

	msgfile_mark $ISCSI_IHOST START $tc_id
	msgfile_mark $ISCSI_THOST START $tc_id

	stmsboot_enable_mpxio $ISCSI_IHOST

	set -A rdevs $RDEVS
	typeset index=0
	while [ $index -lt ${#rdevs[@]} ]
	do
		sbdadm_create_lu POS -s ${VOL_SIZE} ${rdevs[$index]}
		(( index+=1 ))
	done

	build_full_mapping

	build_tpgt_portals $ISCSI_THOST 1

	itadm_create POS target -t 1

	iscsiadm_modify POS $ISCSI_IHOST discovery -t disable
        iscsiadm_add POS $ISCSI_IHOST discovery-address $ISCSI_THOST
        iscsiadm_modify POS $ISCSI_IHOST discovery -t enable

	DEV_TYPE=R
	start_disko $ISCSI_IHOST

	sleep $FS_SECONDS

	stop_disko $ISCSI_IHOST
        verify_disko $ISCSI_IHOST  
	ret=$?
	echo Done verify_disko

	msgfile_mark $ISCSI_IHOST STOP $tc_id
	msgfile_extract $ISCSI_IHOST $tc_id
	msgfile_mark $ISCSI_THOST STOP $tc_id
	msgfile_extract $ISCSI_THOST $tc_id

	host_reboot $ISCSI_IHOST
	tp_cleanup
	initiator_cleanup $ISCSI_IHOST
	[[ $ret -eq 0 ]] && cti_pass "tp_iscsi_fs_004: PASS"
}

