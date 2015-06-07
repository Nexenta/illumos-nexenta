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
#	itadm delete-tpg command fails to delete a target portal group which
#	has already been configured with a target
#
# STRATEGY:
#	Setup:
#		1. Create a tpg
#
#		2. Create a target with the tpg
#
#	Test:
#		1. itadm delete-tpg the created tpg
#
#		2. verify that no portal group gets deleted but it does
#		   not impact the remaining portal groups and that it returns
#		   an error message of can not be delete or something similar
#
#	Cleanup:
#		Delete the target and the tpg
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
function tp_itadm_delete_tpg_data_002
{
	cti_pass

	typeset tc_id tc_desc 
        tc_id="tp_itadm_delete_tpg_data_002"
	tc_desc="itadm delete-tpg command fails to delete a target portal group"
	tc_desc="${tc_desc} which has already been configured with a target"

	print_test_case "${tc_id} - ${tc_desc}"

	typeset p_list
	set -A p_list $(get_portal_list ${ISCSI_THOST})

	itadm_create POS tpg 1 "${p_list[0]}"
	itadm_create POS target -t 1 

	itadm_delete NEG tpg 1 

	tp_cleanup

}

