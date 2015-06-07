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
# A test purpose file to test functionality of the modify-target
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_modify_target_data_001
#
# DESCRIPTION:
#	itadm modify-target command fails to modify the target node name to
#	existing one
#
# STRATEGY:
#
#	Setup:
# 		1. itadm create-target with a node name <one-name>
#
# 		2. itadm create-target with <target-node-name>
#
#	Test:
#		1. itadm modify-target --node-name <one-name> <target-node-name>
#
#         	2. Verify that the command fails and provide expected error
#		   messages
#
#	Cleanup:
#		Delete the created targets
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
function tp_itadm_modify_target_data_001
{
	cti_pass

	typeset tc_id tc_desc 

        tc_id="tp_itadm_modify_target_data_001"
	tc_desc="itadm modify-target command fails to modify the target node"
	tc_desc="${tc_desc} name to existing one"

	print_test_case "${tc_id} - ${tc_desc}"

	itadm_create POS target -n "${IQN_TARGET}.${TARGET[0]}" 
	itadm_create POS target -n "${IQN_TARGET}.${TARGET[1]}" 

	itadm_modify NEG target -n "${IQN_TARGET}.${TARGET[0]}" \
				 "${IQN_TARGET}.${TARGET[1]}"

	tp_cleanup

}

