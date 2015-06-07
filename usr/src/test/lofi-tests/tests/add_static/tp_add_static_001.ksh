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
# ident	"@(#)tp_add_static_001.ksh	1.2	08/12/19 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common

#
# NAME
#	test_cleanup
#
# SYNOPSIS
#	test_cleanup <filename prefix> <file count> <lofi device count>
#
# DESCRIPTION
#	Clean up the lofi devices and files created by the test purpose.
#
# RETURN VALUES
#	0	Cleanup was successful
#	1	Problems encountered during cleanup
#
function test_cleanup {
	typeset filename_prefix="$1"
	typeset file_count="$2"
	typeset lofi_dev_count="$3"
	typeset status=0
	typeset cmd
	typeset current_file_num=$file_count

	execution_phase_cleanup

	# For every file that was created...
	while (( $current_file_num > 0 )); do
		filename=${filename_prefix}$current_file_num

		# Had we associated a lofi device with this file?  If so, we
		# need to clear the lofi device before removing the file.
		if (( $current_file_num <= $lofi_dev_count )); then
			del_lofi_device $filename
			if (( $? != 0 )); then
				status=1
				cti_report "Could not clear lofi device" \
				    "associated with $filename and so" \
				    "cannot delete the file"
				continue
			fi
		fi

		# Remove the file
		cmd="$RM $filename"
		record_cmd_execution "$cmd"
		cti_execute "FAIL" "$cmd"
		if (( $? != 0 )); then
			cti_report "Unable to delete file $filename"
			status=1
		fi
		((current_file_num = $current_file_num - 1))
	done

	return $status
}

#
# start __stc_assertion__
#
# ASSERTION: add_static_001
#
# DESCRIPTION:
#	Up to 127 lofi devices can be created, but the 128th will fail.
#
# STRATEGY:
#	Setup
#		- Create 128 smallish files
#	Assert
#		- Associate lofi devices with the first 127 files.  This
#		  should succeed.
#		- Attempt to associate a lofi device with the 128th file.
#		  This should fail.
#	Cleanup
#		- Remove each file created after first having deleted the
#		  associated lofi device.
#
# end __stc_assertion__
#
function tp_add_static_001 {
	typeset -r LOFI_MAX_DEVICES=127
	typeset cmd lofi_add_status

	typeset -r ASSERTION="add_static_001"
	typeset -r TP_NAME=tp_${ASSERTION}
	typeset -r ME=$(whence -p ${0})
	extract_assertion_info $(dirname $ME)/$TP_NAME
	typeset filename_prefix="${SCRATCH_DIR}/lofi_file_$$_$TET_TPNUMBER_"
	typeset cmd filename
	typeset status=0

	# Initialization
	cti_assert $ASSERTION "Create maximum number of lofi devices"

	# Creating all the lofi devices is time consuming, so skip this test
	# if the run mode is set to short.
	if [[ -n "$RUNMODE" && "$RUNMODE" = "short" ]]; then
		cti_untested "Assertion $ASSERTION skipped as RUNMODE is set" \
		    "to '$RUNMODE'"
		return
	fi

	cti_pass
	create_execution_record		# Record cmds; will display on failure
	execution_phase_setup		# Record setup cmds

	# Create all the files we'll need, which is one beyond LOFI_MAX_DEVICES
	typeset file_counter=0
	typeset file_number
	((files_to_create = $LOFI_MAX_DEVICES + 1))
	while (( $file_counter < $files_to_create )); do
		((file_number = $file_counter + 1))
		filename=${filename_prefix}$file_number
		cmd="mkfile 128k $filename"
		record_cmd_execution $cmd
		cti_execute "FAIL" "$cmd"
		if (( $? != 0 )); then
			cti_report "Error: Unable to create file $filename"
			if (( $file_counter != 0 )); then
				test_cleanup $filename_prefix $file_counter 0
			fi
			display_execution_record
			return
		fi
		((file_counter = $file_counter + 1))
	done

	execution_phase_assert	# Record assertion commands

	# Add lofi devices up to LOFI_MAX_DEVICES.  All of these should
	# succeed.
	typeset lofi_counter=0
	while (( $lofi_counter < $LOFI_MAX_DEVICES )); do
		((file_number = $lofi_counter + 1))
		filename=${filename_prefix}$file_number
		cmd="add_lofi_device $filename"
		record_cmd_execution $cmd
		cti_execute "FAIL" "$cmd"
		if (( $? != 0 )); then
			cti_report "Error: Unable to associate lofi device" \
			    "with file $filename"
			test_cleanup $filename_prefix $file_counter \
			    $lofi_counter
			display_execution_record
			return
		fi
		((lofi_counter = $lofi_counter + 1))
	done

	# Now try to add one more lofi file beyond the limit.  This should
	# fail.
	filename=${filename_prefix}$file_counter
	cmd="add_lofi_device $filename"
	record_cmd_execution $cmd
	cti_execute "PASS" "$cmd"
	if (( $? != 0 )); then
		cti_report "Attempted addition of ${file_counter}th lofi" \
		    "device failed as expected"
	else
		cti_fail "Error: addition of ${file_counter} lofi device" \
		    "succeeded when it was expected to fail"
		lofi_counter=$file_counter
		display_execution_record
		status=1
	fi

	# Clean up after ourselves.
	test_cleanup $filename_prefix $file_counter $lofi_counter
	if (( $? != 0 )); then
		status=1
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0 )); then
		display_execution_record
	else
		delete_execution_record
	fi
}
