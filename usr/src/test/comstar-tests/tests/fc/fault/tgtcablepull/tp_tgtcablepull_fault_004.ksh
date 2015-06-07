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
# ID:tgtcablepull004 
# 
# DESCRIPTION:
# 	Target cable pullss with I/O and data validation
# 	by switch offline/online port
# 
# STRATEGY:
# 
# 	Setup:
# 		zvols (specified by VOL_MAX variable in configuration) are
# 		created in fc target side,
# 		Create initiator groups. Put all the initiator FC ports
# 		into their own group,
# 		Export different sets of LUNs to each initiator 
# 		by stmfadm add-view,
# 		MPXIO is enabled on the host side,
# 		Test duration will 24 hours,
# 		Target cable pull gap will 5 minutes.
# 	Test: 
# 		Start diskomizer on the host side,
# 		Pull one cable from target side (by switch offline port),
# 		After 5 minutes,
# 		Restore the cable from target side (by switch online port),
# 		Iterate all the target ports,
# 		Repeat the offline/online operation for 24 hours,
# 		Check diskomizer error.
# 	Cleanup:
# 		Stop the diskomizer
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	offline-target online-target
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
function tgtcablepull004 {
	cti_pass
	tc_id="tgtcablepull004"
	tc_desc="Target cable pullss with I/O  by switch offline/online port"
	print_test_case $tc_id - $tc_desc

	msgfile_mark $FC_IHOST START $tc_id

	build_fabric_topo $FC_IHOST

	stmsboot_enable_mpxio $FC_IHOST
	
	build_random_mapping $FC_IHOST
	
	start_disko $FC_IHOST

	switch_cable_pull_io $FC_IHOST $TS_SNOOZE $TS_MAX_ITER
	
	stop_disko $FC_IHOST

	verify_disko $FC_IHOST
	ret=$?

	msgfile_mark $FC_IHOST STOP $tc_id
	msgfile_extract $FC_IHOST $tc_id

	cleanup_mapping
	[[ $ret -eq 0 ]] && cti_pass "tp_tgtcablepull_fault_004: PASS"
}

