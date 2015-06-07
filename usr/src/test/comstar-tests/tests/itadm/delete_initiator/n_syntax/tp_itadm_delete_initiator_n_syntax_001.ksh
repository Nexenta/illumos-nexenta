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
# A test purpose file to test functionality of the delete-initiator
# subfunction of the itadm command
#

# __stc_assertion_start
#
# ID: itadm_delete_initiator_n_syntax_001
#
# DESCRIPTION:
#	itadm delete-initiator command  with invalid arguments fails and does not
#	impact any existing initiators
#
# STRATEGY:
# 	Create a dynamic test case that generates command and options
# 	combinations with a scope of the invalid argument.
#
#	Setup:
#		Create a initiator
#	Test:
#		1. itadm delete-initiator
#
#		   Invalid argument:
#
#		   <initiator-node-name>
#			iqn.1986-03.com.sun.not.existing
#			iqn.1986-3.invalid.name
#			"" (Empry string)
#
#
#		2. ensure that the command fails with an appropriate error
#		   message
#
#		3. itadm list initiator shows that none of the pre-existing initiators
#		   were impacted.
#
#	Cleanup:
#		Delete the created initiator
#
#	STRATEGY_NOTES:
#
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
CMD="itadm_delete NEG initiator ^SET_1 "

SET_1=" \
	iqn.1986-03.com.sun.not.existing | \
	iqn.1986-3.invalid.name | \ 
        NULL
"

set -A CMD_ARR 
 
function itadm_delete_initiator_n_syntax
{ 
        cti_pass 
        typeset -i i 
        (( i = ${TET_TPNUMBER} - 1 ))    
 
        tc_id="itadm_delete_initiator_n_syntax_${TET_TPNUMBER}"
	tc_desc="itadm delete-initiator command fails to delete initiator"
	tc_desc="${tc_desc} with { ${CMD_ARR[${i}]} }"
	print_test_case $tc_id - $tc_desc

	itadm_create POS initiator -u chap-user iqn.1986-03.com.sun

        ${CMD_ARR[${i}]} 
 
        tp_cleanup 
 
} 
 
auto_generate_tp "CMD" "CMD_ARR" "itadm_delete_initiator_n_syntax" 

