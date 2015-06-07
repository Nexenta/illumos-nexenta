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
# A test purpose file to test functionality of the list-target
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_list_target_p_syntax_001
#
# DESCRIPTION:
# 	itadm list-target command successfully lists the specified
#	target with valid options
#
# STRATEGY:
# 	Create a dynamic test case that generates command and options
# 	combinations with a scope of the valid arguments
#
#	Setup:
#		itadm create targets
#
#	Test:
#		1. itadm list-target
#
#		   Valid arguments:
#			[-v]
#				-v
#				"" (Empty string)
#
#			<target-node-name>
#				iqn.1986-03.com.sun (Existing node name)
#				"" (Empty string)
#
#
# 		2. verify that the expected target information is returned
#
#	Cleanup:
#		Delete the created targets
#
#	STRATEGY_NOTES:
#		This information should have been tested and verified during
#		the create and modify target operations
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

CMD="itadm_list POS target ^SET_1 ^SET_2"

SET_1=" \
	-v	| \
	NULL	| \
"

SET_2=" \
	iqn.1986-03.com.sun	| \
	NULL			| \
"

set -A CMD_ARR

function itadm_list_target_p_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_list_target_p_syntax_${TET_TPNUMBER}"
	tc_desc=" itadm list-target command successfully list target"
	tc_desc="${tc_desc} with { ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc

	itadm_create POS target -n iqn.1986-03.com.sun

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_list_target_p_syntax"

