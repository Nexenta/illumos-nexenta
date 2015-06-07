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
# ID: itadm_modify_target_p_syntax_001
#
# DESCRIPTION:
#	itadm modify-target command successfully modify the specified
#	target with valid option
#
# STRATEGY:
# 	Create a dynamic test case that generates command and options
# 	combinations with a scope of the valid arguments
#
#	Setup:
#		create a target with multiple supported options
#	Test:
#		1. itadm modify-target
#
#		   Valid arguments
#
#	 		-a -a
#				[chap|radius|none|default]
#	 		-s --chap-secret
#				valid-secret
#				a-16-characters-
#	 		-S --chap-secret-path
#				valid-secret     # secret contained in file
#				a-16-characters- # secret contained in file
#	 		-u --chap-user
#				test-user-name
#				A String of 255 characters
#	 		-n --node-name
#				iqn.1986-03.com.sun
#				iqn.1986-03.com.sun:**** (Total 223 characters)
#				eui.02004567A425678D
#	 		-l --alias
#				alias_name
#				A String of 255 characters
#
#		2. itadm list-target to verify that the command succeeds and
#		   the specified arguments are set.
#
#	Cleanup:
#		Delete the created target
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
#CMD="itadm_modify POS target ^SET_1 ^SET_2 ^SET_3 ^SET_4 ^SET_5 \
#        iqn.2004-06.sun.com" 
CMD="itadm_modify POS target ^SET_0 iqn.2004-06.sun.com" 

SET_0=" \
	^SET_1 | \
	^SET_2 | \
	^SET_3 | \
	^SET_4 | \
	^SET_5 | \
"

SET_1=" \
	-a chap | \ 
	-a radius | \ 
	-a none | \
	-a default | \
	NULL
"
SET_2=" \
	^SET_2_1 | \
	^SET_2_2 | \
	NULL
"

SET_2_1=" \
	-s valid-secret | \
	-s a-16-characters- | \
"
SET_2_2=" \
	-S valid-secret | \
	-S a-16-characters- | \
"

SET_3=" \
	-u test-user-name | \
	-u ^STR_255 | \ 
	NULL
"

SET_4=" \
	-n iqn.1986-03.com.sun | \
	-n iqn.1986-03.COM.SUN | \
	-n eui.02004567A425678D | \
	-n eui.02004567a425678d | \
	-n ^STR_223 |\
	NULL
"

SET_5=" \
	-l alias_name | \
	-l ^STR_255 | \
	NULL
"

STR_255=" \
iqn.1986-03.com.sun:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
Total-255-characters-aaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaa
"

STR_223=" \
iqn.1986-03.com.sun:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
Total-223-characters-aaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaa"

set -A CMD_ARR

function itadm_modify_target_p_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_modify_target_p_syntax_${TET_TPNUMBER}"
	tc_desc="itadm modify-target successfully modify target"
	tc_desc="${tc_desc} with { ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc

	itadm_create POS target -n iqn.2004-06.sun.com

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_modify_target_p_syntax"

