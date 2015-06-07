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
# A test purpose file to test functionality of chap authentication
#

# __stc_assertion_start
#
# ID: iscsi_auth_011
#
# DESCRIPTION:
#	Verify that RADIUS authentication configured by default setting works 
#	properly 
#
# STRATEGY:
#	Setup:
#		Modify the default auth-method is "radius" authentication 
#		    by itadm modify-defaults option on target host
#		Create target portal group with specified tag 1 and ip address
#		Create target node with tpgt 1 and auth-method default specified
#		Modify radius server ip address and port on target host
#		    by itadm modify-default option
#		Create a LU on target host by zfs file system
#		Create the view of LU by default to all target and host groups
#		Setup initiator node to enable "SendTarget" method
#		Setup SendTarget with discovery address on initiator host
#		Setup RADIUS authentication enabled on initiator host
#		Setup radius server and shared secret on initiator host by
#		    iscsiadm modify initiator-node option
#	Test:
#		Check that device path of specified LU can be visible by
#		    iscsi initiator node
#		Check that iscsi initiator node has at least 1 active connection
#	Cleanup:
#		Delete the target portal group
#		Delete the target node
#		Delete the configuration information in initiator and target
#
#	STRATEGY_NOTES:
#
# TESTABILITY: explicit
#
# AUTHOR: john.gu@sun.com
#
# REVIEWERS:
#
# ASSERTION_SOURCE:
#
# TEST_AUTOMATION_LEVEL: automated
#
# STATUS: IN_PROGRESS
#
# COMMENT
#
# __stc_assertion_end
#
function iscsi_auth_011
{
	cti_pass

        tc_id="iscsi_auth_011"

	tc_desc="Verify that RADIUS authentication configured by default setting"
	tc_desc="${tc_desc} works properly"

	print_test_case $tc_id - $tc_desc

	stmsboot_enable_mpxio $ISCSI_IHOST

        cti_unsupported "Radius Authentication is not supported by Comstar"\
            "iSCSI Target temporarily, test is skipped."

}
