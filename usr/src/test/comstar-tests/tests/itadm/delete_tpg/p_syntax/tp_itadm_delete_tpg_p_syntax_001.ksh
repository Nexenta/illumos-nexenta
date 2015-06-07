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
# ID: itadm_delete_tpg_p_syntax_001
#
# DESCRIPTION:
# 	itadm delete-tpg command successfully deletes the specified
# 	target portal group
#
# STRATEGY:
#	Setup:
#		1. Create three tpg
#
#		2. list the tags to verify they exist and are as expected
#
#	Test:
# 		1. itadm delete-tpg <tpg-tag> for an exiting tag
#
# 		2. verify that the specified portal group gets deleted but it does
#		   not impact the remaining portal groups
#	Cleanup:
#		Delete the rest tpg
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
CMD="itadm_delete POS tpg ^SET_1"

SET_1=" 1 "

set -A CMD_ARR

function itadm_delete_tpg_p_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_delete_tpg_p_syntax_${TET_TPNUMBER}"
	tc_desc="itadm delete-tpg command successfully delete the specified "
	tc_desc="${tc_desc} target portal group with {"
	tc_desc="${tc_desc} ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc
	
	itadm_create POS tpg 1 127.0.0.1:3261
	itadm_create POS tpg 2 127.0.0.1:3262
	itadm_create POS tpg 3 127.0.0.1:3263

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_delete_tpg_p_syntax"


