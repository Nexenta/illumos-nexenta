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
# of the stmf framework.

#
# __stc_assertion_start
# 
# ID:stmfoffline002 
# 
# DESCRIPTION:
# 	Offline stmf service on the target side with I/O
# 
# STRATEGY:
# 
# 	Setup:
# 		zvols (specified by VOL_MAX variable in configuration) are
# 		created in fc target side,
# 		Create host groups. Put all the initiator FC ports 
# 		into their own group,
# 		Export different sets of LUNs to each initiator
# 		by stmfadm add-view,
# 		MPXIO is enabled on the host side.
# 	Test: 
# 		Start diskomizer on the host side,
# 		Offline the service using "svcadm disable stmf" on target side,
# 		Service offline should go offline in less than 10 seconds 
# 		on target side,
# 		All the Lus and ports should show offline 
# 		in their respective stmfadm outputs.
# 	Cleanup:
# 		Stop the diskomizer
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	fault injection
# 
# TESTABILITY: explicit
# 
# AUTHOR: John.Gu@Sun.COM
# 
# REVIEWERS:
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS (2008-02-14)
# 
# __stc_assertion_end
function stmfoffline002 {
	cti_pass
	tc_id="stmfoffline002"
	tc_desc="Offline stmf service on the target side with I/O"
	print_test_case $tc_id - $tc_desc

	stmf_smf_enable
	
	msgfile_mark $FC_IHOST START $tc_id

	stmsboot_enable_mpxio $FC_IHOST
		
	build_random_mapping $FC_IHOST
		
	start_disko $FC_IHOST

	stmf_smf_disable

	cti_report "sleep $SS_SNOOZE intervals after stmf smf disable"
	sleep $SS_SNOOZE
		
	typeset cmd="$STMFADM list-target -v | grep online"
	run_generic_cmd NEG "$cmd"
		
	typeset cmd="$STMFADM list-lu -v | grep online"
	run_generic_cmd NEG "$cmd"
		
	stop_disko $FC_IHOST

	verify_disko $FC_IHOST
	ret=$?

	stmf_smf_enable

	msgfile_mark $FC_IHOST STOP $tc_id
	msgfile_extract $FC_IHOST $tc_id

	cleanup_mapping
	[[ $ret -eq 0 ]] && cti_pass "tp_stmfoffline_fault_002: PASS"
}
