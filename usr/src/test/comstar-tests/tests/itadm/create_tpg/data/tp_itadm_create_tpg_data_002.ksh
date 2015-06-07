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
# A test purpose file to test functionality of the create-tpg
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_create_tpg_data_002
#
# DESCRIPTION:
#       Create two target portal groups with one shared portal among them to
#	see its fails.
#
# STRATEGY:
# 	Setup:
#
#	Test:
#		1. itadm create-tpg with
#			IP-address1:port1 IP-address2:port2
#
#		2. itadm create-tpg with
#			IP-address2:port2 IP-address3:port3
#
#		3. Verify that the second target portal group is not created 
#
#	Cleanup:
#		Delete the created tpgs
#
#	STRATEGY_NOTES:
#
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
function tp_itadm_create_tpg_data_002
{
	cti_pass

	typeset tc_id tc_desc 
        tc_id="tp_itadm_create_tpg_data_002"
	tc_desc="Create two target portal groups with one shared portal among"
	tc_desc="${tc_desc} them to see its fail"

	print_test_case "${tc_id} - ${tc_desc}"

	typeset p_list
	set -A p_list $(get_portal_list ${ISCSI_THOST})

	itadm_create POS tpg 1 "${p_list[0]}:3260" "${p_list[1]}:3261" 
	itadm_create NEG tpg 1 "${p_list[1]}:3261" "${p_list[0]}:3263" 

	tp_cleanup
}

