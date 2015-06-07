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
# A test purpose file to test functionality of the modify-defaults
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_modify_defaults_n_syntax_001
#
# DESCRIPTION:
#	itadm modify-defaults command with invalid arguments fails to modify
#	the default options and provides the proper error messages
#
# STRATEGY:
# 	Create a dynamic test case that generates command and options
# 	combinations with a scope of the invalid arguments
#
#	Setup:
# 		Collect the default values of each attribute
#	Test:
#		1. itadm modify-defaults with invalid arguments:
#
#		   Invalid arguments
#			-a --auth-method
#				RADius
#				"" (Empty string)
#			-r --radius-server
#				radius-server-ip:65536
#				radius-server-ip:-1
#				a.b.c.d
#				"" (Empty string)
#			-d --radius-secret
#				"" (Empty string)
#			-i --isns
#				able
#				"" (Empty string)
#			-I --isns-server
#				isns-server-ip:65536
#				isns-server-ip:-1
#				,,
#				isns-server-ip:port,a.b.c.d
#				"" (Empty string)
#
#		2. verify that the expected error message is returned.
#
#		3. itadm list-default to check no attribute is changed
#	Cleanup:
#		Restore the default value
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
# 	http://www.opensolaris.org/os/project/iser/itadm_1m_v4.pdf
#
# TEST_AUTOMATION_LEVEL: automated
#
# STATUS: IN_PROGRESS
#
# COMMENTS:
#
# __stc_assertion_end
#

CMD="itadm_modify NEG defaults ^SET_0" 

SET_0=" \
	^SET_1 | \
	^SET_2 | \
	^SET_3 | \
	^SET_4 | \
	^SET_5 | \
"

SET_1=" \
	-a RADius	| \
	-a		| \
"

SET_2=" \
	-r ${RADIUS_HOST}:65536	| \
	-r ${RADIUS_HOST}:-1	| \
	-r a.b.c.d			| \
	-r 				| \
"

SET_3=" \
	-d EMPTY | \
"

SET_4=" \
	-i able	| \
	-i	| \
"

SET_5=" \
	-I ${ISNS_HOST}:65536		| \
	-I ${ISNS_HOST}:-1		| \
	-I ${ISNS_HOST},a.b.c.d		| \
	-I ,,				| \
	-I				| \
"

set -A CMD_ARR

function itadm_modify_defaults_n_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_modify_defaults_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm modify_defaults command fails to modify defaults "
	tc_desc="${tc_desc} with { ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_modify_defaults_n_syntax"


