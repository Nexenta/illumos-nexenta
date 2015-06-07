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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tp_create_005.ksh	1.3	08/06/11 SMI"
#

#
# create-share test case
#

#__stc_assertion_start
#
#ID: create005
#
#DESCRIPTION:
#
#	Share manager should not allow a 'create' operation that specifies
#	options without specifying a protocol.
#
#STRATEGY:
#
#       Setup:
#		None
#       Test:
#		- Execute a create command that specifies valid NFS options but
#		doesn't specify a protocol.
#       Cleanup:
#		- Delete any groups created
#
#       STRATEGY_NOTES:
#
#KEYWORDS:
#
#       create NEG
#
#TESTABILITY: explicit
#
#AUTHOR: andre.molyneux@sun.com
#
#REVIEWERS: TBD
#
#TEST_AUTOMATION_LEVEL: automated
#
#CODING_STATUS: COMPLETE
#
#__stc_assertion_end
function create005 {
	tet_result PASS
	tc_id="create005"
	tc_desc="Try to set options without having protocol specified"
	cmd_list=""
	unset GROUPS
	print_test_case $tc_id - $tc_desc

	#
	# Execute create command that also sets NFS options but without
	# specifying the NFS protocol.  This should fail.  (Dry run,
	# then for real.)
	#
	create NEG ${TG[0]} -n -p index="test_file_aaa"
	create NEG ${TG[0]} -p index="test_file_aaa"

	#
	# Cleanup
	#
	delete_all_test_groups
	report_cmds NEG
}
