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
# ID:forcelip002 
# 
# DESCRIPTION:
# 	Luxadm -e forcelips on the host side with I/O and data validation
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
# 		MPXIO is enabled on the host side,
# 		Start diskomizer on the host side,
# 		Issue luxadm -e forcelip from hostside 
# 		with I/O with 5 minutes gap,
# 		Test duration will be 24 hours
# 	Test: 
# 		target port should show up in the mpathadm output
# 		on the host side,
# 		initiator should show up in the stmfadm list-target -v 
# 		output on the target side,
# 		Diskomizer should have no errors.
# 	Cleanup:
# 		Stop the diskomizer
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	luxadm forcelip
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
function forcelip002 {
	cti_pass
	tc_id="forcelip002"
	tc_desc="Luxadm -e forcelips on the host side with I/O and data validation"
	print_test_case $tc_id - $tc_desc

	msgfile_mark $FC_IHOST START $tc_id

	build_fabric_topo $FC_IHOST

	stmsboot_enable_mpxio $FC_IHOST
		
	build_random_mapping $FC_IHOST
		
	start_disko $FC_IHOST

	luxadm_forcelip $FC_IHOST
		
	stop_disko $FC_IHOST

	verify_disko $FC_IHOST
	ret=$?

	msgfile_mark $FC_IHOST STOP $tc_id
	msgfile_extract $FC_IHOST $tc_id

	cleanup_mapping
	[[ $ret -eq 0 ]] && cti_pass "tp_forcelip_fault_002: PASS"
}

