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
# ident	"@(#)tp_add_dynamic.ksh	1.2	08/12/19 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common

#
# start __stc_assertion__
#
# ASSERTION: add_dynamic_N (multiple dynamically generated assertions)
#
# DESCRIPTION:
#	Users should be able to add lofi devices based on files, by specifying
#	no lofi path (lofiadm will pick one), block device lofi path, or
#	char device lofi path.  Invalid parameters should be caught by the
#	lofiadm command.
#
#	Set of dynamically-generated assertions for testing various
#	valid and invalid conbinations of parameters during lofi device
#	creation.  Each iteration will identify the specific values of
#	the parameters used.
#
# STRATEGY:
#    Setup:
#	1. Create a list of parameter combinations containing both
#	   positive and negative test cases (performed by tc file).
#	2. For each set of parameter combinations:
#		2.01 Create a file.
#    Assertion:
#		2.02 Add lofi device based on the file created during setup.
#    Cleanup:
#		2.03 Delete lofi device
#		2.04 Delete file
#
# end __stc_assertion__
#
function tp_add_dynamic {
	typeset pos_or_neg lofi_dev_param file_name_param file_size_param
	typeset pos_or_neg_text
	typeset lofi_dev_arg add_status invalid_lofi_path cmd
	typeset lofi_file=${SCRATCH_DIR}/lofi_file_$$_$TET_TPNUMBER
	typeset status=0

	base_asrt_id="add_dynamic"
	asrt_num=$TET_TPNUMBER
	if (( $asrt_num < 10 )); then
		asrt_num="00$asrt_num"
	elif (( $asrt_num < 100 )); then
		asrt_num="0$asrt_num"
	fi
	asrt_id="${base_asrt_id}_${asrt_num}"

	# Get the line corresponding to this iteration (matching
	# $TET_TPNUMBER) from the dynamic config file.
	typeset config_line=`extract_line_from_file $dynamic_config_file $TET_TPNUMBER`
	if (( $? != 0 )) || [[ -z $config_line ]]; then
		cti_assert $asrt_id
		cti_uninitiated "Could not extract line $TET_TPNUMBER from" \
		    "$dynamic_config_file"
		return
	fi

	# Extract the individual elements from the line that was read from
	# the dynamic configuration file.
	set $config_line
	pos_or_neg="$1"
	lofi_dev_param="$2"
	file_name_param="$3"
	file_size_param="$4"
	if [[ "$pos_or_neg" = "neg" ]]; then
		pos_or_neg_text=" (expected to fail)"
	fi

	cti_assert $asrt_id "lofi device '$lofi_dev_param', file name '$file_name_param', file size '$file_size_param'$pos_or_neg_text"

	create_execution_record		# Record cmds; will display on failure
	execution_phase_setup		# Record setup cmds

	if [[ "$file_name_param" != "none" ]]; then
		if [[ "$file_size_param" = "zero" ]]; then
			file_size="0"
		else
			file_size="$DEFAULT_FILE_SIZE"
		fi
		make_and_verify_file $file_size $lofi_file
		if (( $? != 0 )); then
			# File creation failed.  Set unresolved status, display
			# the commands executed up to this point, and return.
			cti_unresolved
			display_execution_record
			return
		fi
	fi

	# Create the file parameter we'll pass to 'lofiadm -a'
	if [[ "$file_name_param" = "full_path" ]]; then
		file_name_arg="$lofi_file"
	elif [[ "$file_name_param" = "partial" ]]; then
		file_name_arg=`echo $lofi_file | basename`
	fi

	# Create the lofi device parameter we'll pass to 'lofiadm -a'.
	if [[ "$lofi_dev_param" = "full_path_block" ]]; then
		lofi_dev_arg="/dev/lofi/$TET_TPNUMBER"
	elif [[ "$lofi_dev_param" = "full_path_char" ]]; then
		lofi_dev_arg="/dev/rlofi/$TET_TPNUMBER"
	elif [[ "$lofi_dev_param" = "partial_path" ]]; then
		lofi_dev_arg="$TET_TPNUMBER"
	elif [[ "$lofi_dev_param" = "non_lofi_path" ]]; then
		invalid_lofi_path="$SCRATCH_DIR/non_lofi_path_$$"
		lofi_dev_arg="$invalid_lofi_path"
	fi

	execution_phase_assert		# Record assertion cmds
	lofi_dev_returned=`add_lofi_device $file_name_arg $lofi_dev_arg`
	add_status=$?

	if (( $add_status == 0)) || (( $add_status == 2 )); then
		if [[ "$pos_or_neg" = "pos" ]]; then
			cti_pass "Creation of lofi device succeeded as" \
			    "expected"
		else
			cti_fail "Creation of lofi device was expected to fail"
			status=1
		fi
	elif (( $add_status == 1 )); then
		if [[ "$pos_or_neg" = "neg" ]]; then
			cti_pass "Creation of lofi device failed as" \
			    "expected"
		else
			cti_fail "Creation of lofi device failed when it was" \
			    "expected to succeed"
			status=1
		fi
	fi

	# Clean up after ourselves.
	execution_phase_cleanup

	# Return code 0 or 2 means that 'lofiadm -a' succeeded.  If so, then
	# we need to delete the lofi device.
	if (( $add_status == 0 )) || (( $add_status == 2 )); then
		del_lofi_device $lofi_file
		if (( $? == 0 )); then
			cti_report "Deletion of lofi device associated with" \
			   "$lofi_file succeeded"
		else
			cti_fail "Unable to delete lofi device associated" \
			    "with $lofi_file"
			status=1
		fi
	fi

	if [[ -f "$lofi_file" ]]; then
		# A file was created for use during lofi addition; delete it.
		cmd="$RM $lofi_file"
		record_cmd_execution $cmd
		cti_execute "PASS" "$cmd"
		if (( $? != 0 )); then
			cti_fail "Unable to remove file $lofi_file used to" \
			    "for lofi device.  Possible lofi is still using" \
			    "it."
			status=1
		fi
	fi

	if [[ -f "$invalid_lofi_path" ]]; then
		# A file was created to test out giving an invalid path for a
		# lofi device; delete it.
		cmd="$RM $invalid_lofi_path"
		record_cmd_execution $cmd
		cti_execute "PASS" "$cmd"
	fi

	if [[ -n $VERBOSE ]] || (( $status != 0)); then
		display_execution_record
	else
		delete_execution_record
	fi

	cti_pass
}
