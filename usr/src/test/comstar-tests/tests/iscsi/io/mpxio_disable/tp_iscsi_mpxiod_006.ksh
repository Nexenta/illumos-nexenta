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
# A test purpose file to test functionality of the fault injection
#
#
# __stc_assertion_start
# 
# ID:iscsi_mpxiod_006 
# 
# DESCRIPTION:
# 	Target cable pulls with I/O and data validation
# 	by switch offline/online port when mpxio is disabled
# 
# STRATEGY:
# 
# 	Setup:
#               mpxio is disabled on initiator host
#               zvols (specified by VOL_MAX variable in configuration) are
#                   created in fc target host
#               map all the LUs can be accessed by all the target and host
#                   groups by stmfadm add-view option
#               create target portal groups with one portal per portal group
#               create one target node 1 with all the portal groups supported
#               create one target node 2 with all the portal groups supported
#               modify initiator target-param to allow all the initiator portals
#                   to create one session individually to support multi-pathing
#                   with the specified target node 1 and target node 2
#               add one target portal address into initiator discovery address
#                   list by iscsiadm add discovery-address option
#               modify initiator discovery method to Send-Target and enable
# 	Test: 
#               start diskomizer on the initiator host
#		unplumb switch port relating to the specified iscsi target
#		    on switch
#               sleep 24 seconds
#		plumb switch port realting to the specified iscsi target
#		    on switch
#               sleep 24 seconds
#               iterate all the switch ports then plumb/unplumb them from
#                   switch by switch management utility
#               repeat the plumb/unplumb operation for the specified rounds
#               check diskomizer error
# 	Cleanup:
# 		Stop the diskomizer
# 
# 	STRATEGY_NOTES:
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
function iscsi_mpxiod_006
{
	cti_pass
	tc_id="iscsi_mpxiod_006"
	tc_desc="I/O data validation with mpxio disabled by online/offline"
        tc_desc="$tc_desc switch ports"
	print_test_case $tc_id - $tc_desc

        msgfile_mark $ISCSI_IHOST START $tc_id
        msgfile_mark $ISCSI_THOST START $tc_id

        stmsboot_disable_mpxio $ISCSI_IHOST

        build_tpgt_1portal $ISCSI_THOST

        typeset tpg_list=$(get_tpgt_list)
	itadm_create POS target -n ${IQN_TARGET}.${TARGET[0]} -t $tpg_list
	itadm_create POS target -n ${IQN_TARGET}.${TARGET[1]} -t $tpg_list

	iscsiadm_modify POS $ISCSI_IHOST discovery -t disable
	iscsiadm_add POS $ISCSI_IHOST discovery-address $ISCSI_THOST
	iscsiadm_modify POS $ISCSI_IHOST discovery -t enable

        start_disko $ISCSI_IHOST

        switch_cable_pull_io $ISCSI_THOST $TS_SNOOZE $TS_MAX_ITER

        stop_disko $ISCSI_IHOST
        verify_disko $ISCSI_IHOST
	echo Done verify_disko

        msgfile_mark $ISCSI_IHOST STOP $tc_id
        msgfile_extract $ISCSI_IHOST $tc_id

        msgfile_mark $ISCSI_THOST STOP $tc_id
        msgfile_extract $ISCSI_THOST $tc_id

        env_iscsi_cleanup
        initiator_cleanup $ISCSI_IHOST
        host_reboot $ISCSI_IHOST -r
}

