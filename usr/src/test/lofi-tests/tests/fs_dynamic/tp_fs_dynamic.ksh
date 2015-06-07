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
# ident	"@(#)tp_fs_dynamic.ksh	1.2	08/12/19 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common
. ${TET_SUITE_ROOT}/lofi-tests/lib/util_common


#
# start __stc_assertion__
#
# ASSERTION: fs_dynamic
#
# DESCRIPTION:
#       This test purpose dynamically generates a set of test cases that
#	tests combinations of valid lofi file sizes and filesystem types.
#	Each test case is an iteration that identifies a specific set of
#	parameters.
#
# STRATEGY:
#    Setup:
#	1. Create a list of parameter combinations (performed by tc file).
#    Assertion
#	2. For each set of parameter combinations:
#		2.01 Create a file.
#		2.02 Create and populate filesystem on file (method depends on
#		     type of FS being created).
#		2.03 Disassociate lofi device from file.
#		2.04 Associate decompressed file with lofi device.
#		2.05 Mount filesystem with default options
#		2.06 Verify contents of FS on file.
#		2.07 Unmount FS.
#		2.08 Disassociate lofi device from file.
#    Cleanup:
#		2.09 Remove file
#	
# end __stc_assertion__
#
function tp_fs_dynamic {

	cti_pass

        # Extract and print assertion information for the test
	typeset -r ASSERTION="fs_dynamic"
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
	lofi_dev_num=$(($counter % ($LOFI_DEV_NUM_LIMIT + 1) ))
	typeset desired_lofi_dev=/dev/lofi/$lofi_dev_num

	# TET_TPNUMBER could change if other test purposes are added.
	# This check is so that the assertion is not reprinted for
	# every iteration of the test purpose.
	((assert_check = $ic_num + 1))
	if (( $TET_TPNUMBER == $assert_check )); then
        	extract_assertion_info $(dirname $ME)/$TP_NAME
	fi

	# Parameters used to build the test cases
        typeset pos_or_neg file_size_param file_system_param
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
	skip_iteration="$4"
        if [[ "$pos_or_neg" = "neg" ]]; then
                pos_or_neg_text=" (expected to fail)"
        fi

	# Build and display the assertion description
	typeset atxt="Testing the following parameters - file size"
	atxt="$atxt '$file_size_param' file system '$file_system_param'"
	atxt="$atxt $pos_or_neg_text"
        cti_assert $ITERATION "$atxt"

	if [[ -n "$skip_iteration" ]]; then
		cti_untested "Skipping assertion $ITERATION as RUNMODE is" \
		    "'$RUNMODE'"
		return
	fi

	# If the user has placed limits on which parameters to test, make
	# sure our current list of parameters falls within the list.
	tp_within_parameters FS_TYPES $file_system_param
	if (( $? != 0 )); then
		cti_untested "Skipping assertion $ITERATION"
		return
	fi

	create_execution_record		# Record cmds; will display on failure
        execution_phase_setup           # Record setup cmds

	typeset zpool_name zpool_arg
	if [[ "$file_system_param" = "zfs" ]]; then
		zpool_name="lofi_pool_${counter}"
		zpool_arg="-z $zpool_name"
	fi

        execution_phase_assert		# Record assertion commands

	# Call function that takes care of creating a populated filesystem
	# on the specified file (via lofi).  $reference_tree is a directory
	# hierarchy and set of files created during the startup phase of the
	# 'tc' file that runs this test purpose.
	create_populated_fs_in_file -l $lofi_file -f $file_system_param \
	    -r $file_size_param -s $reference_tree $zpool_arg
	if (( $? != 0 )); then
		display_execution_record
		status=1
	fi

	# If filesystem creation succeeded, verify the contents.
	if (( $status == 0 )); then
		# After the filesystem was created and populated, it was
		# unmounted and the lofi device associated with the file
		# containing the filesystem was torn down.  Make sure that the
		# filesystem is still accessible when the file is once again
		# associated with a lofi device.
		verify_populated_fs_in_file -l $lofi_file \
		    -f $file_system_param -s $reference_tree $zpool_arg
		if (( $? != 0 )); then
			cti_fail "Verification of $file_system_param" \
			    "filesystem on lofi device failed."
			status=1
		fi
	fi

	# Clean up after ourselves
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
