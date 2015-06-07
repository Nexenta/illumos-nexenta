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
# ID: itadm_create_target_n_syntax_001
#
# DESCRIPTION:
#	itadm create-target command fails to create the target with all
#	invalid combinations of options and provides the proper error messages
#
# STRATEGY:
# 	Create a dynamic test case that generates command and argument
# 	combinations with a scope of the invalid arguments
#
#	Setup:
#
#	Test:
#	 	1. itadm create-target
#
#		   Invalid agruments
#
#	 		-a --auth-method
#				CHap (Invalid auth method)
#				"" (Empty string)
#	 		-s --chap-secret
#				abcd (A string less then 12 characters)
#				256-characters
#				"" (Empty string)
#	 		-S --chap-secret-path
#				# secret contained in file
#				abcd (A string less then 12 characters)
#
#				# secret contained in file
#				256-characters 
#
#				# secret contained in file
#				"" (Empty string)
#
#	 		-u --chap-user
#				"" (Empty string)
#	 		-n --node-name
#				iqn.com.sun
#				iqn.2004-04.com.sun:cli_initiator_test
#				iqn.2004-04.com.sun:cli}initiator_test
#				iqn.2004-04.com.sun:cli{initiator_test
#				iqn.2004-04.com.sun:cli,initiator_test
#				iqn.2004-4.com.sun
#				eui.02004567A425678 
#						(Wrong IEEE EUI-64 identifier)
#				224-characters 
#				"" (Empty string)
#	 		-l --alias
#				"" (Empty string)
#	 		-t --tpg
#				100 (Not existed target portal group)
#				100,200 (Not existed target portal group)
#				a,b (Invalid tpg tag)
#				"" (Empty string)
#
#	 	2. Verify that no target was created using the itadm
#	 	   list-target command
#	Cleanup:
#		Delete the target if any one is created
#
# 	STRATEGY_NOTES:
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

# nagetive combinations
CMD="itadm_create NEG target ^SET_0" 

SET_0=" \
	^SET_1 | \
	^SET_2 | \
	^SET_3 | \
	^SET_4 | \
	^SET_5 | \
	^SET_6 |\
	^SET_7 \
"

SET_1=" \
	-a CHap | \ 
	-a
"

SET_2=" \
	-s abcd | \
	-s ^STR_256 | \
	-s EMPTY
"

SET_3=" \
	-S abcd | \
	-S ^STR_256 | \
	-S EMPTY
"

SET_4=" \
	-u
"

SET_5=" \
	-n iqn.com.sun | \
	-n iqn.2004-04.com.sun:cli_initiator_test | \
	-n iqn.2004-04.com.sun:cli}initiator_test | \
	-n iqn.2004-04.com.sun:cli{initiator_test | \
	-n iqn.2004-04.com.sun:cli,initiator_test | \
	-n iqn.2004-4.com.sun | \
	-n eui.02004567A425678 | \
	-n ^STR_224 | \
	-n 
"

SET_6=" \
	-l
"

SET_7=" \
	-t 100 | \
	-t 100,200 | \
	-t a,b | \
	-t 
"

STR_256=" \
256-characters-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaa
"
STR_224=" \
iqn.19836-03.sun.com:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaa\
"
set -A CMD_ARR

function itadm_create_target_n_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_create_target_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm create-target command fails to create the target with { "
	tc_desc="${tc_desc} ${CMD_ARR[${i}]} }"

	print_test_case $tc_id - $tc_desc

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_create_target_n_syntax"

