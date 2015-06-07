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
# A test purpose file to test functionality of the create-initiator
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_create_initiator_data_001
#
# DESCRIPTION:
#       itadm create-initiator command using a pre-existing initiator name
# 	fails to create the initiator and provides the expected error messages
#
# STRATEGY:
#
#	Setup:
#		itadm create-initiator with a given initiator name
#	Test:
#		1. itadm create-initiator with the pre-existing initiator name
#
# 		2. verify that the create command fails and provides the
#		   expected error messages.
#
#	Cleanup:
#		Delete the created initiator
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
function tp_itadm_create_initiator_data_001
{
	cti_pass

	typeset tc_id tc_desc 
        tc_id="tp_itadm_create_initiator_data_001"
	tc_desc="itadm create-initiator command using a pre-existing initiator name"
	tc_desc="${tc_desc} fails to create the initiator and provides the"
	tc_desc="${tc_desc} expected error messages"

	print_test_case "${tc_id} - ${tc_desc}"

	itadm_create POS initiator -u chap-user "${IQN_INITIATOR}"
	itadm_create NEG initiator -u chap-user "${IQN_INITIATOR}"

	tp_cleanup
}

