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
# A test purpose file to test view visibility of the stmf framework.

#
# __stc_assertion_start
# 
# ID: visible003
# 
# DESCRIPTION:
# 	Verify the view visibility with offline-target operation
# 
# STRATEGY:
# 
# 	Setup:
# 		Create a host group hg
# 		Create a target group tg1 tg2
# 		Create a logical unit lu 
# 		Add all the host initiator ports into the host group hg
# 		Add the target port port1 into the target group tg1
# 		Add the target port port2 into the target group tg2
# 		Add the view entry with hg, tg1 and lu
# 		Add the view entry with hg, tg2 and lu
# 		Offline the target port port 2
# 	Test: 
# 		Verify the host side can only see the logical unit lu through port1
# 	Cleanup:
# 		Delete the host group
# 		Delete the target group
# 		Delete the logical units
# 		Delete the view entry
# 
# 	STRATEGY_NOTES:
# 
# KEYWORDS:
# 
# 	stmfadm add-view
# 
# TESTABILITY: explicit
# 
# AUTHOR: John.Gu@Sun.COM
# 
# REVIEWERS:
# 
# TEST_AUTOMATION_LEVEL: automated
# 
# CODING_STATUS: IN_PROGRESS (2008-02-14)
# 
# __stc_assertion_end
function visible003 {
	cti_pass
	tc_id="visible003"
	tc_desc="Verify the view visibility with offline-target operation"
	print_test_case $tc_id - $tc_desc
	
	build_fs zdsk
	fs_zfs_create -V 1g $ZP/${VOL[0]}		

	sbdadm_create_lu POS -s 1024k $DEV_ZVOL/$ZP/${VOL[0]}
	eval guid=\$LU_${VOL[0]}_GUID
	
	stmfadm_create POS tg ${TG[0]}
	stmfadm_create POS tg ${TG[1]}
	stmfadm_create POS hg ${HG[0]}	

	stmf_smf_disable
	pos=0
	for target in $G_TARGET
	do
		if [ $pos -eq 0 ];then
			stmfadm_add POS tg-member -g ${TG[0]} $target
			pos=1
		else
			stmfadm_add POS tg-member -g ${TG[1]} $target
			pos=0
		fi
	done
	stmf_smf_enable

	stmsboot_enable_mpxio $FC_IHOST
	typeset hostname=`format_shellvar $FC_IHOST`
	eval initiator_list="\$HOST_${hostname}_INITIATOR"
	for port in $initiator_list
	do
		stmfadm_add POS hg-member -g ${HG[0]} $port
	done

	stmfadm_add POS view -t ${TG[0]} -h ${HG[0]} $guid
	stmfadm_add POS view -t ${TG[1]} -h ${HG[0]} $guid
	stmfadm_offline POS target $target
	
	stmfadm_verify initiator

	tp_cleanup
	clean_fs zdsk
	
}
