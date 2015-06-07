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
# ID:tgtcablepull003 
# 
# DESCRIPTION:
# 	Target cable pulls without I/O by switch offline/online port
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
# 		MPXIO is enabled on the host side.
# 	Test: 
# 		Pull one cable from target side (by switch offline port),
# 		After 20 seconds, the path status on the host side
# 		will show the path is gone,
# 		Restore the cable from target side (by switch online port),
# 		The path should come back pretty quickly within 
# 		a few seconds on the host side.
# 	Cleanup:
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
function tgtcablepull003 {
	cti_pass
	tc_id="tgtcablepull003"
	tc_desc="Target cable pulls without I/O by switch offline/online port"
	print_test_case $tc_id - $tc_desc

	msgfile_mark $FC_IHOST START $tc_id

	stmsboot_enable_mpxio $FC_IHOST
	
	build_random_mapping $FC_IHOST

	switch_cable_pull $FC_IHOST $TS_SNOOZE $TS_MAX_ITER

	msgfile_mark $FC_IHOST STOP $tc_id
	msgfile_extract $FC_IHOST $tc_id

	cleanup_mapping
}
