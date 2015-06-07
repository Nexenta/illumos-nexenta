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
# ident	"@(#)tp_compression_dynamic_001.ksh	1.3	09/03/09 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common
. ${TET_SUITE_ROOT}/lofi-tests/lib/util_common


#
# start __stc_assertion__
#
# ASSERTION: compression_dynamic_001
#
# DESCRIPTION:
#       This test purpose dynamically generates a set of test cases that
#	tests combinations of valid and invalid lofi compression parameters. 
#	Each test case is an iteration that identifies a specific set of
#	parameters. The combination of parameters form either a positive test
#	case (pos) or a negative test case (neg). Only one negative parameter
#	will be tested in each negative test case.
#
# STRATEGY:
#    Setup:
#	1. Create a list of parameter combinations containing both
#	   positive and negative test cases (performed by tc file).
#	2. For each set of parameter combinations:
#		2.01 Create a file.
#		2.02 Create and populate filesystem on file (method depends on
#		     type of FS being created).
#    Assertion:
#		2.03 Compress file using 'lofiadm -C <compression parameter>'.
#		2.04 Associate compressed file with lofi device.
#		2.05 Execute 'fstype' agains lofi device to verify correct FS
#		     type is reported.
#		2.06 For UFS FS, attempt to mount FS with read-write
#		     permissions, which should fail.
#		2.07 For UFS and HSFS FS, mount FS read-only.
#		2.08 For UFS and HSFS FS, verify contents of FS on compressed
#		     file.
#		2.09 For UFS and HSFS FS, unmount FS.
#		2.10 Disassociate lofi device from file.
#		2.11 Decompress file.
#		2.12 Associate decompressed file with lofi device.
#		2.13 Mount filesystem with default options
#		2.14 Verify contents of FS on file.
#		2.15 Unmount FS.
#		2.16 Disassociate lofi device from file.
#    Cleanup:
#		Remove file
#	
# end __stc_assertion__
#
function tp_compression_dynamic_001 {

	cti_pass

        # Extract and print assertion information for the test
	typeset -r ASSERTION="compression_dynamic_001"
        typeset -r TP_NAME=tp_${ASSERTION}
        typeset -r ME=$(whence -p ${0})

	typeset status=0

	# ic_num is the number of test purposes that are not dynamic.
	# this may change if other test purposes are added.
	let counter=$TET_TPNUMBER
	typeset -r ITERATION=${ASSERTION}_$counter

	# Rather than reusing the same lofi dev number over and over, we'll
	# use a different one each time (based on our counter).  As there's
	# a limit to lofi dev numbers, we'll wrap around to lower numbers
	# if the counter exceeds LOFI_DEV_NUM_LIMIT.
	if (( $counter <= 128 )); then
		lofi_dev_num=$counter
	else
		lofi_dev_num=$(( ($counter % $LOFI_DEV_NUM_LIMIT) +1 ))
	fi
	typeset desired_lofi_dev=/dev/lofi/$lofi_dev_num

	# TET_TPNUMBER could change if other test purposes are added.
	# This check is so that the assertion is not reprinted for
	# every iteration of the test purpose.
	((assert_check = $ic_num + 1))
	if (( $TET_TPNUMBER == $assert_check )); then
        	extract_assertion_info $(dirname $ME)/$TP_NAME
	fi

	# Parameters used to build the test cases
        typeset pos_or_neg file_size_param file_system_param compress_param
        typeset lofi_file=${SCRATCH_DIR}/lofi_file_$$_$counter
	cti_report "lofi_file = '$lofi_file'"

        # Get the line corresponding to this iteration (matching
        # $counter) from the dynamic config file.
	cp $dynamic_config_file /tmp/dynamic_config_file
        typeset config_line=`extract_line_from_file $dynamic_config_file \
	    $counter`
	if (( $? != 0 )) || [[ -z "$config_line" ]]; then
               	cti_uninitiated "Could not extract line $counter from" \
		    "dynamic confile file $dynamic_config_file"
               	return
       	fi

        # Extract the individual elements from the line that was read from
        # the dynamic configuration file.
        set $config_line
        pos_or_neg="$1"
        file_size_param="$2"
        file_system_param="$3"
        compress_param="$4"
        segment_size_param="$5"
	skip_iteration="$6"
        if [[ "$pos_or_neg" = "neg" ]]; then
                pos_or_neg_text=" (expected to fail)"
        fi

	# Build and display the assertion description
	typeset atxt="Testing the following parameters - file size"
	atxt="$atxt '$file_size_param' file system '$file_system_param'"
	atxt="$atxt compression algorithm '$compress_param' segment size"
	atxt="$atxt '$segment_size_param' $pos_or_neg_text"
        cti_assert $ITERATION "$atxt"

	# Determine compression support
	is_compression_type_supported $compress_param
	typeset comp_type_rc=$?

	# There are several reasons why we might choose not to run this test
	# assertion.  First is if the OS we're running on doesn't include any
	# lofi compression support.
	if (( $comp_type_rc == 2 )); then
		cti_untested "Skipping assertion $ITERATION as lofi" \
		    "compression is not supported on this OS version"
		return
	fi

	# Second reason not to run is if the OS supports lofi compression
	# in general but doesn't support the specific compression algorithm
	# specified.
	if [[ $compress_param != 'default' && $compress_param != 'invalid' ]]
	then
		if (( $comp_type_rc == 1 )); then
			cti_untested "Skipping assertion $ITERATION " \
			    "as lofi compression type '$compress_param' is " \
			    "not supported on this OS version"
			return
		fi
	fi

	# Third reason not to run is if this iteration was flagged to be
	# skipped due to the value of RUNMODE.
	if [[ -n "$skip_iteration" ]]; then
		cti_untested "This test skipped as RUNMODE is '$RUNMODE'"
		return
	fi

	# Fourth reason not to run is if the user has placed limits on which
	# parameters to test and the current list of parameters doesn't fall
	# within those limits.
	tp_within_parameters FS_TYPES $file_system_param COMPRESSION_TYPES \
	    $compress_param COMPRESSION_SEG_SIZES $segment_size_param
	if (( $? != 0 )); then
		cti_untested "Skipping assertion $ITERATION"
		return
	fi

	# If we've gotten this far, we're going to attempt to execute the test
	# assertion.

	create_execution_record		# Record cmds; will display on failure
        execution_phase_setup           # Record setup cmds

	typeset zpool_name zpool_arg
	if [[ "$file_system_param" = "zfs" ]]; then
		zpool_name="lofi_pool_${counter}"
		zpool_arg="-z $zpool_name"
	fi

	# Call function that takes care of creating a populated filesystem
	# on the specified file (via lofi).  $reference_tree is a directory
	# hierarchy and set of files created during the startup phase of the
	# 'tc' file that runs this test purpose.
	create_populated_fs_in_file -l $lofi_file -f $file_system_param \
	    -r $file_size_param -s $reference_tree $zpool_arg
	if (( $? != 0 )); then
		cti_fail "Unable to create populated $file_system_param" \
		    "filesystem on file $lofi_file using lofi"
		display_execution_record
		return
	fi

	# We now have a populated filesystem in a lofi-usable file.  Time
	# to get to the meat of this assertion, which is the compression/
	# decompression functionality.

        execution_phase_assert           # Record assertion cmds

	# For any compression parameter other than "default" we place the
	# compression type the -C flag.  For "default", no compression
	# type is specified.
	typeset compress_value
	if [[ "$compress_param" != "default" ]]; then
		compress_value="$compress_param"
	fi

	# For any sement size other than "default" we place the segment size
	# after the -s flag.  For "default", no segment size type is specified.
	typeset segment_size_arg=""
	if [[ "$segment_size_param" != "default" ]]; then
		segment_size_arg="-s $segment_size_param"
	fi

	cmd="lofiadm -C $compress_value $segment_size_arg $lofi_file"
	record_cmd_execution "$cmd"

	# Whether the compression command is expected to pass or fail
	# depends on if this is a positive or negative test case.
	typeset on_fail
	if [[ "$pos_or_neg" = "pos" ]]; then
		on_fail="FAIL"
	else
		on_fail="PASS"
	fi
	cti_execute $on_fail "$cmd"
	typeset compression_status=$?

	typeset exit_due_to_compression_status
	if (( $compression_status == 0 )); then
		if [[ "$pos_or_neg" = "neg" ]]; then
			cti_fail "Error: Compression succeeded when it" \
			    "was expected to fail"
			exit_due_to_compression_status=1
		fi
	else
		if [[ "$pos_or_neg" = "neg" ]]; then
			cti_report "Attempted compression failed as expected"
			exit_due_to_compression_status=1
		else
			cti_fail "Attempted compression failed when it was" \
			    "expected to pass"
			exit_due_to_compression_status=1
		fi
	fi

	# If compression failed, or succeeded when it was expected to fail,
	# clean up and return.
	if [[ -n "$exit_due_to_compression_status" ]]; then
		execution_phase_cleanup
		lofi_and_fs_tidy_up -f $lofi_file -d
		display_execution_record
		return
	fi

	cti_report "Compressed file $lofi_file with compression type" \
	    "'$compress_value' and segment size '$segment_size_param'"

	# Verify the filesystem contents after compression.
	verify_populated_fs_in_file -l $lofi_file -f $file_system_param \
	    -s $reference_tree $zpool_arg -c
	if (( $? == 0 )); then
		cti_report "Verified filesystem on file $lofi_file following" \
		    "compression"
	else
		cti_fail "Verification of compressed $file_system_param" \
		    "filesystem on file $lofi_file failed."

		# Don't return yet as we still need to find out if the
		# filesystem looks ok after decompression.
		status=1
	fi

	# Decompress the file containing the file system.
	cmd="lofiadm -U $lofi_file"
	record_cmd_execution "$cmd"
	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		cti_report "Could not decompress file $lofi_file"
		lofi_and_fs_tidy_up -f $lofi_file -d
		display_execution_record
		return
	fi

	cti_report "Decompression of $lofi_file succeeded."

	# Verify the filesystem contents after decompression.
	verify_populated_fs_in_file -l $lofi_file -f $file_system_param \
	    -s $reference_tree $zpool_arg
	if (( $? == 0 )); then
		cti_report "Verified filesystem on file $lofi_file following" \
		    "decompression"
	else
		cti_report "Verification of filesystem on file $lofi_file" \
		    "following decompression failed"
		status=1
	fi

	# Clean up
        execution_phase_cleanup
	lofi_and_fs_tidy_up -f $lofi_file -d
	if (( $? != 0 )); then
		status=1
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0 )); then
		display_execution_record
	else
		delete_execution_record
	fi
}
