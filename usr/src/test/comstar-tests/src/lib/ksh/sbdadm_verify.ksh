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
# This file contains common functions and is meant to be sourced into
# the test case files.  These functions are used to verify the 
# configuration and state of the resources in use.
#


#
# NAME
#	sbdadm_verify_lu
# DESCRIPTION
#	Compare the actual node list of specified logical unit to 
#	what the test suite thinks the 
#	lu list should be.
#
# RETURN
#	Sets the result code
#	void
#
function sbdadm_verify_lu 
{
	cti_report "Executing: sbdadm_verify_lu start"
	sbdadm_list_lu 
	get_cmd_stdout | grep "Found 0 LU(s)" >/dev/null 2>&1
	if [ $? -ne 0 ];then
		typeset chk_vols="$G_VOL"
		get_cmd_stdout | sed -n '6,$p' | while read line
		do
			typeset source=`echo $line | awk '{print $NF}'`
			source=`basename $source`
			typeset vol_fnd=0
			unset vol_list
			for chk_vol in $chk_vols
			do
				if [ "$chk_vol" = "$source" ] ;then
					vol_fnd=1
				else
					vol_list="$vol_list $chk_vol"
				fi
			done
			if [ $vol_fnd -eq 0 ] ;then
				cti_fail "WARNING: vol $source is in "\
					"listed output but not in stored info."
			fi
			chk_vols="$vol_list"
		done
		if [ "$chk_vols" ];then
			cti_fail "WARNING: VOL(s) $chk_vols were in "\
				"stored info but not in listed output."
		fi
	else
		if [ -n "$G_VOL" ];then
			cti_fail "WARNING: Logical Unit : $G_VOL is in "\
				"stored info not in listed output."
		fi
	fi
	cti_report "Executing: sbdadm_verify_lu stop"
	
}

#
# NAME
#	sbdadm_verify_im
# DESCRIPTION
#	Compare the actual attribute of specified logical unit to 
#	what the test suite thinks the lu list should be 
#	after import-lu operation.
#
# RETURN
#	Sets the result code
#	void
#
function sbdadm_verify_im 
{
	cti_report "Executing: sbdadm_verify_import start"
	sbdadm_list_lu 
	get_cmd_stdout | grep "Found 0 LU(s)" >/dev/null 2>&1
	if [ $? -ne 0 ];then
		typeset chk_vols="$G_VOL"
		get_cmd_stdout | sed -n '6,$p' | while read line
		do
			typeset source=`echo $line | awk '{print $NF}'`			
			source=`basename $source`
			guid=`echo $line | awk '{print $1}'`
			typeset -l guid=$guid
			size=`echo $line | awk '{print $2}'`			
			typeset vol_fnd=0
			unset vol_list
			for chk_vol in $chk_vols
			do
				eval chk_guid=\$LU_${chk_vol}_GUID
				typeset -l chk_guid=$chk_guid
				eval chk_size=\$LU_${chk_vol}_SIZE
				if [ "$chk_vol" = "$source" -a \
					$guid = $chk_guid -a \
					$size -eq $chk_size ] ;then
					vol_fnd=1
				else
					vol_list="$vol_list $chk_vol"
				fi
			done
			if [ $vol_fnd -eq 0 ] ;then
				cti_fail "WARNING: vol $source $size $guid is "\
					"in listed output but not matched with"\
					" stored info after import-lu."
			fi
			chk_vols="$vol_list"
		done
		if [ "$chk_vols" ];then
			cti_fail "WARNING: VOL(s) $chk_vols were in stored "\
				"info but not matched with listed output "\
				"after import-lu."
		fi
	else
		if [ -n "$G_VOL" ];then
			cti_fail "WARNING: Logical Unit : $G_VOL is in stored"\
				"info not matched with listed output "\
				"after import-lu."
		fi
	fi
	cti_report "Executing: sbdadm_verify_import stop"
}

