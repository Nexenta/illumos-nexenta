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
# A test purpose file to test functionality of the delete-tpg
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_delete_tpg_data_002
#
# DESCRIPTION:
#	Create two tpg <tpg1> and <tpg2>, delete <tpg1> first. then
#	itadm delete-target <tpg1> <tpg2>. Verify that the command fails, and
#	<tpg2> are not deleted.
#
# STRATEGY:
#
#	Setup:
#		1. Create two target portal group <tpg1> <tpg2>
#
#		2. itadm delete-tpg <tpg1>
#	Test:
#
#		1. itadm delete-tpg <tpg1> <tpg2>
#
#		2. ensure that the command fails with an appropriate error
#		   message
#
#		3. itadm list-target shows that <tpg2> were not impacted.
#
#	Cleanup:
#		Delete the created target portal groups
#
#	STRATEGY_NOTES:
#
# TESTABILITY: explicit
#
# AUTHOR: bobbie.long@sun.com zheng.he@sun.com
#
# REVIEWERS:
#
# ASSERTION_SOURCE:
#	http://www.opensolaris.org/os/project/iser/itadm_1m_v4.pdf
#
# TEST_AUTOMATION_LEVEL: automated
#
# STATUS: IN_PROGRESS
#
# COMMENTS:
#
# __stc_assertion_end
#
function tp_itadm_delete_tpg_data_001
{
	cti_pass

	typeset tc_id tc_desc 
        tc_id="tp_itadm_delete_tpg_data_001"
	tc_desc="Create two tpg <tpg1> and <tpg2>, delete <tpg1> first. then"
	tc_desc="${tc_desc} itadm delete-target <tpg1> <tpg2>. Verify that the"
	tc_desc="${tc_desc} command fails, and <tpg2> are not deleted."

	print_test_case "${tc_id} - ${tc_desc}"

	typeset p_list
	set -A p_list $(get_portal_list ${ISCSI_THOST})

	itadm_create POS tpg 1 "${p_list[0]}"
	itadm_create POS tpg 2 "${p_list[1]}"
	
	itadm_delete POS tpg 1 
	itadm_delete NEG tpg 1 2	

	tp_cleanup

}
