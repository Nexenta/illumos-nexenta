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
# ID: itadm_create_tpg_n_syntax_001
#
# DESCRIPTION:
#	itadm create-tpg command fail to create the specified target portal
#	group with all invalid combinations of options
#
# STRATEGY:
# 	Create a dynamic test case that generates command and options
# 	combinations with a scope of invalid arguments.
#
#	Setup:
#
#	Test:
#		1. itadm create-tpg <tpg-tag> <IP-address:port>
#
#		   Invalid arguments:
#		   <tpg-tag>
#			"" (Empty String)
#
#		   <IP-address:port>
#			a.a.a.a
#			a.a.a.a:3260
#			127.0.0.1:-1
#			127.0.0.1:65537
#			"" (Empty String)
#
#		2. itadm list-tpg to make sure no new target portal group
#		   created.
#	Cleanup:
#		Delete the created target portal group
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

CMD="itadm_create NEG tpg ^SET_0" 

SET_0=" \
        ^SET_1  127.0.0.1 	| \
         1 ^SET_2 		| \
"

SET_1=" \
	-1		| \ 
	^STR_256	| \ 
	NULL
"

SET_2=" \
	a.a.a.a		| \
	a.a.a.a:3260	| \
	127.0.0.1:-1	| \
	127.0.0.1:65537	| \
	NULL
"

STR_256=" \
256_characters_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaa
"

set -A CMD_ARR

function itadm_create_tpg_n_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	
	
        tc_id="itadm_create_tpg_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm create-tpg command fails to create the specified target"
	tc_desc="${tc_desc} portal group with { "
	tc_desc="${tc_desc} ${CMD_ARR[${i}]} }"

	print_test_case $tc_id - $tc_desc

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_create_tpg_n_syntax"

