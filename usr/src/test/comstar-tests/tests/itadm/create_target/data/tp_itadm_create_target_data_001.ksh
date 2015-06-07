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
# A test purpose file to test functionality of the create-target
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_create_target_data_001
#
# DESCRIPTION:
#       itadm creates target with one existing target portal group
#
# STRATEGY:
#
#	Setup:
#		Create one target portal group using itadm create-tgp command
#	Test:
#		1. itadm create-target -t 1 with the created tpg.
#
#	 	2. Verify that the correct target was created using the itadm
#	 	   list-target command
#
#	Cleanup:
#		Delete the created target ant target portal group
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
function tp_itadm_create_target_data_001
{
	cti_pass

	typeset tc_id tc_desc 
        tc_id="tp_itadm_create_target_data_001"
        tc_desc="itadm creates target with one existing target portal group"
	print_test_case "${tc_id} - ${tc_desc}"


	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})

	itadm_create POS tpg 1 "${portal_list[0]}"

	itadm_create POS target -t 1

	tp_cleanup
}

