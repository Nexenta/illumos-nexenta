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
# A test purpose file to test functionality of fault injection
#

# __stc_assertion_start
#
# ID: iscsi_mpxiod_007
#
# DESCRIPTION:
#	Online/offline iscsi target port by stmfadm on the target side 
#	without I/O when mpxio is disabled
#
# STRATEGY:
#	Setup:
#		mpxio is disabled on initiator host
#		zvols (specified by VOL_MAX variable in configuration) are
#		    created in fc target host
#		map all the LUs can be accessed by all the target and host 
#		    groups by stmfadm add-view option
#		create target portal groups with one portal per portal group
#		create target nodes (specified by TARGET_MAX variable in
#		    (configuration)  with all the portal groups supported
#	Test:
#		iterate all the target nodes then offline them from 
#		    target host by stmfadm offline-target option
#		sleep 24 seconds
#		check all the target nodes are offline
#		iterate all the other target nodes then online them from 
#		    target host by stmfadm online-target option
#		sleep 24 seconds
#		check all the target nodes are online
#		repeat the online/offline operation for the specified rounds
#	Cleanup:
#		delete all the target nodes
#		delete all the target portal groups
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
function iscsi_mpxiod_007
{
	cti_pass
	tc_id="iscsi_mpxiod_007"
	tc_desc="Without I/O running and with mpxio disabled by"
	tc_desc="$tc_desc stmfadm online/offline target port on target host"
	print_test_case $tc_id - $tc_desc

        msgfile_mark $ISCSI_IHOST START $tc_id
        msgfile_mark $ISCSI_THOST START $tc_id

        stmsboot_disable_mpxio $ISCSI_IHOST

	build_tpgt_1portal $ISCSI_THOST

	typeset tpg_list=$(get_tpgt_list)

	typeset idx=0
	while [ $idx -lt $TARGET_MAX ]
	do
		itadm_create POS target -t $tpg_list
		(( idx+=1 ))
	done

	iscsiadm_modify POS $ISCSI_IHOST discovery -t disable
	iscsiadm_add POS $ISCSI_IHOST discovery-address $ISCSI_THOST
	iscsiadm_modify POS $ISCSI_IHOST discovery -t enable

	iscsi_target_port_online_offline $ISCSI_THOST $FT_SNOOZE $TS_MAX_ITER

        msgfile_mark $ISCSI_IHOST STOP $tc_id
        msgfile_extract $ISCSI_IHOST $tc_id
        
	msgfile_mark $ISCSI_THOST STOP $tc_id
        msgfile_extract $ISCSI_THOST $tc_id

	env_iscsi_cleanup
	initiator_cleanup $ISCSI_IHOST
        host_reboot $ISCSI_IHOST -r

}

