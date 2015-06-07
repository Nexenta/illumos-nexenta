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
# ID: itadm_create_initiator_n_syntax_001
#
# DESCRIPTION:
#	itadm create-initiator command fails to create the initiator with all
#	invalid combinations of options and provides the proper error messages
#
# STRATEGY:
# 	Create a dynamic test case that generates command and argument
# 	combinations with a scope of the invalid arguments
#
#	Setup:
#
#	Test:
#	 	1. itadm create-initiator
#
#		   Invalid agruments
#	 		-u --chap-user
#				256-characters 
#				"" (Empty string)
#	 		-s --chap-secret
#				abcd (A string less then 12 characters)
#				256-characters 
#				"" (Empty string)
#	 		-S --chap-secret-path
#
#				# secret contained in file
#				abcd (A string less then 12 characters)
#
#				# secret contained in file
#				256-characters
#
#				# secret contained in file
#				"" (Empty string)
#			node-name
#				224-characters
#
#	 	2. Verify that no initiator was created using the itadm
#	 	   list-initiator command
#	Cleanup:
#		Delete the initiator if any one is created
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
CMD="itadm_create NEG initiator ^SET_0 ${IQN_INITIATOR} | \
	itadm_create NEG initiator ^STR_224 | \
" 

SET_0=" \
	^SET_1 | \
	^SET_2 | \
	^SET_3 | \
"

SET_1=" \
	-u ^STR_256 | \ 
	-u 
"

SET_2=" \
	-s abcd | \
	-s 256-characters | \
	-s EMPTY
"

SET_3=" \
	-S abcd | \
	-S 256-characters | \
	-S EMPTY
"

STR_256="\
256-characters-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaa"

STR_224="\
iqn.1998-04.sun.com:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
224-characters-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\
aaaaaaaaaaaaaaaaaaaaaaaa"

set -A CMD_ARR

function itadm_create_initiator_n_syntax
{
	cti_pass
	typeset -i i
	(( i = ${TET_TPNUMBER} - 1 ))	

        tc_id="itadm_create_initiator_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm create-initiator command fails to create the initiator"
	tc_desc="${tc_desc} with { "
	tc_desc="${tc_desc} ${CMD_ARR[${i}]} }"

	print_test_case $tc_id - $tc_desc

	${CMD_ARR[${i}]}

	tp_cleanup

}

auto_generate_tp "CMD" "CMD_ARR" "itadm_create_initiator_n_syntax"

