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
# ident	"@(#)tp_delete_002.ksh	1.2	08/12/19 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common

#
# start __stc_assertion__
#
# ASSERTION: delete_002
#
# DESCRIPTION:
#	Delete a lofi device based on the name of the device.
#
# STRATEGY:
#	Setup
#		- Create a file of default size
#		- Add a lofi device using the file
#	Assert
#		- Delete the lofi device by specifying the device name to
#		  'lofiadm -d'
#	Cleanup
#		- Remove the file
#
# end __stc_assertion__
#
function tp_delete_002 {
	typeset cmd lofi_add_status
	typeset lofi_file=${SCRATCH_DIR}/lofi_file_$$_$TET_TPNUMBER
	typeset status=0

	typeset -r ASSERTION="delete_002"
	typeset -r TP_NAME=tp_${ASSERTION}
	typeset -r ME=$(whence -p ${0})
	extract_assertion_info $(dirname $ME)/$TP_NAME

	# Initialization
	cti_pass
	cti_assert $ASSERTION "Delete lofi device by device name"
	create_execution_record		# Record cmds; will display on failure
	execution_phase_setup		# Record setup cmds

	# Setup  -- create file for lofi device
	make_and_verify_file $DEFAULT_FILE_SIZE $lofi_file
	if (( $? != 0 )); then
		cti_unresolved "Unable to test lofi deletion because" \
		    "creation of file failed"
		status=1
	fi

	# Setup -- add lofi device
	if (( $status == 0 )); then
		lofi_dev_returned=`add_lofi_device $lofi_file`
		lofi_add_status=$?
		if (( $lofi_add_status != 0 )) && (( $lofi_add_status != 2 ))
		then
			cti_unresolved "Unable to test lofi deletion because" \
			    "creation failed"
			status=1
		fi
	fi

	# Assertion -- delete lofi device using name of device
	if (( $status == 0 )); then
		execution_phase_assert		# Record assertion cmds
		del_lofi_device $lofi_dev_returned
		if (( $? == 0 )); then
			cti_report "Deletion of lofi $lofi_dev_returned" \
			   "succeeded"
		else
			cti_fail "Unable to delete lofi device" \
			    "$lofi_dev_returned"
			status=1
		fi
	fi

	# Cleanup
	execution_phase_cleanup		# Record cleanup cmds
	if [[ -f "$lofi_file" ]]; then
		cmd="$RM $lofi_file"
		record_cmd_execution $cmd
		cti_execute "PASS" "$cmd"
		if (( $? != 0 )); then
			cti_fail "Unable to remove file $lofi_file" \
			    "used to for lofi device.  Possible lofi" \
			    "is still using it."
			status=1
		fi
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0 )); then
		display_execution_record
	else
		delete_execution_record
	fi
}
