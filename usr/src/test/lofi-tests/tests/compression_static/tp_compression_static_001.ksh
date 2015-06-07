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
# ident	"@(#)tp_compression_static_001.ksh	1.3	09/03/09 SMI"
#

LOGFILE=${LOGDIR}/mkdir.out
. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common
. ${TET_SUITE_ROOT}/lofi-tests/lib/util_common

#
# start __stc_assertion__
#
# ASSERTION: compression_static_001
#
# DESCRIPTION
#	An attempt to compress a file that's currently associated with a
#	lofi device should fail.
#
# STRATEGY:
#	Setup
#		- Create a file of default size
#		- Add a lofi device using the file
#	Assert
#		- Attempt to compress the file via 'lofiadm -C'
#	Cleanup
#		- Delete the lofi device
#		- Remove the file
#
# end __stc_assertion__
#
function tp_compression_static_001 {
	typeset -r ASSERTION="compression_static_001"
	typeset -r TP_NAME=tp_${ASSERTION}
	typeset -r ME=$(whence -p ${0})
	typeset -r ASSERT_DESC="Try to compress in use lofi file"
	typeset lofi_file=${SCRATCH_DIR}/$$_$ASSERTION
	typeset status=0

	extract_assertion_info $(dirname $ME)/$TP_NAME

	cti_assert $ASSERTION "$ASSERT_DESC"
	create_execution_record
	execution_phase_setup

	# First off, verify that compression is supported by the version of
	# lofiadm on the test system.
	typeset compression_supported=`get_supported_compression_types`
	if [[ ! -n $compression_supported ]]; then
		cti_untested "Skipping assertion $ITERATION as lofi" \
		    "compression is not supported on this OS version"
		return
	fi

	# This test uses default compression type, so make sure that the
	# user hasn't set COMPRESSION_TYPES to exclude 'default'.
	tp_within_parameters COMPRESSION_TYPES default
	if (( $? != 0 )); then
		cti_untested "Skipping assertion as compression type" \
		    "'default' not in COMPRESSION_TYPES ($COMPRESSION_TYPES)"
		return
	fi

	#
	# Create the file that we're going to use
	#
	make_and_verify_file $DEFAULT_FILE_SIZE $lofi_file
	if (( $? != 0 )); then
		cti_unresolved "Unable to test '$assert_desc' because" \
		    "creation of file failed"
		display_execution_record
		return
	fi

	#
	# Add a lofi device using the file.  We'll capture the name of the
	# lofi device printed by the add_lofi_device function even though
	# we're not going to use it -- otherwise, it will get printed out
	# in the terminal where the test suite is being executed.
	#
	typeset lofi_dev=`add_lofi_device $lofi_file`
	if (( $? == 0 )); then
		cti_report "File created and lofi device successfully" \
		    "associated with it"

		# Now execute the actual assertion, where we attempt to
		# compress the file via 'lofiadm -C gzip' while it's in use.
		execution_phase_assert
		typeset cmd="$LOFIADM -C $lofi_file"
		record_cmd_execution "$cmd"
		cti_execute "PASS" "$cmd"
		if (( $? == 0 )); then
			cti_fail "Error: '$cmd' succeeded when it should" \
			    "have failed."
			cti_report "Should not be able to compress file that" \
			    "is currently associated with a lofi device"
			status=1
		else
			cti_pass "Compression while file was in use failed" \
			    "as expected"
		fi

		#
		# Clean up after ourselves.
		#
		execution_phase_cleanup
		del_lofi_dev_and_file $lofi_file
		if (( $? != 0 )); then
			cti_fail "Cleanup of lofi device and/or file" \
			    "$lofi_file failed"
			status=1
		fi
	else
		#
		# The addition of the lofi device failed.
		#
		cti_fail "Unable to test '$assert_desc' because addition of" \
		    "lofi device failed"
		status=1
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0 )); then
		display_execution_record
	else
		delete_execution_record
	fi
}
