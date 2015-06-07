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
# A test purpose file to test functionality of the list-tpg
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_list_tpg_n_syntax_001
#
# DESCRIPTION:
#	itadm list-tpg command with an invalid tpg tag provides an error
#	message and return error code
#
# STRATEGY:
#	Setup:
#		Create a tpg with <IP-address[:port]>
#	Test:
#		1. itadm list-tpg <tpg-tag> with a tpg tag that does not exist
#
#		2. verify that the command returns an error message like
#		   invalid tpg tag or something suitable.
#	Cleanup:
#		Delete the tpg
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

CMD="itadm_list NEG tpg ^SET_1"


SET_1=" \
	600	| \
	-1	| \
	65536	| \
"

set -A CMD_ARR

function itadm_list_tpg_n_syntax 
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_list_tpg_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm list-tpg command fails to list target portal group"
	tc_desc="${tc_desc} with { ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc

	typeset portal_list
	set -A portal_list $(get_portal_list ${ISCSI_THOST})

	itadm_create POS tpg 1 ${portal_list[0]}:3261

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_list_tpg_n_syntax"

