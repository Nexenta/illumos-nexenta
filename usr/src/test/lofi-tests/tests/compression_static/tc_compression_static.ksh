#!/bin/ksh -p
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
# ident	"@(#)tc_compression_static.ksh	1.3	09/03/09 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/fs_common
. ${TET_SUITE_ROOT}/lofi-tests/lib/startup_cleanup_common

startup=startup
cleanup=cleanup

test_list="
	tp_compression_static_001 \
	tp_compression_static_002 \
	tp_compression_static_003 \
	tp_compression_static_004 \
	tp_compression_static_005 \
	tp_compression_static_006 \
"

function startup {
	cti_report "In startup"

	typical_startup_checks
	if (( $? != 0 )); then
		exit 1
	fi
}

function cleanup {
	cti_report "In cleanup"
	#
	# cleanup /dev/lofi to prepare for the next test
	#
	if [ -d /dev/lofi ]; then
		rm -rf /dev/lofi
	fi
}

#
# NAME
#	zero_size_test
#
# SYNOPSIS
#	zero_size_test <assert #> <compression type>
#
# DESCRIPTION
#	This function contains the code used to test the special case of
#	zero-length files and lofiadm compression.  All of the test code
#	for these cases is in this function.  The test purpose files for
#	these cases just pass in the assertion ID number, the type of
#	compression used, and the name of the tp file (so the assertion
#	comments can be extracted from it).  This function then takes care
#	of the actual test.
#
#	Tests for additional compression types that may be added later can
#	be accomplished by just copying one of the existing zero-size tp
#	files and updating the assertion ID number and type of compression
#	in it.
#
# RETURN VALUE
#	Undefined
#
function zero_size_test {
	typeset assert_num="$1"
	typeset compression_type="$2"
	typeset tp_file="$3"
	typeset compression_arg

	typeset assertion="compression_static_${assert_num}"
	typeset tp_name=tp_${assertion}
	typeset assert_desc="Compress/uncompress zero-length file using"
	assert_desc="$assert_desc compression of '$compression_type'"
	typeset lofi_file=${SCRATCH_DIR}/$$_$assertion
	typeset status=0

	extract_assertion_info $(dirname $tp_file)/$tp_name

	cti_assert $assertion "$assert_desc"
	create_execution_record
	execution_phase_setup

	# Make sure that, if the user has specified which compression types
	# to test, that the current compression type is on the list.
	tp_within_parameters COMPRESSION_TYPES $compression_type
	if (( $? != 0 )); then
		cti_untested "Skipping assertion $assertion"
		return
	fi

	if [[ "$compression_type" = "default" ]]; then
		# No arg after "-C" for default compression
		compression_arg=""
	else
		compression_arg="$compression_type"
	fi

	# Check system for compression support
	is_compression_type_supported $compression_type
	typeset comp_type_rc=$?

	# Verify that compression is supported by the version of lofiadm on
	# the test system.
	if (( $comp_type_rc == 2 )); then
		cti_untested "Skipping assertion $ITERATION as lofi" \
		    "compression is not supported on this OS version"
		return
	fi

	# Make sure the compression type specified is supported.
	if [[ $compression_type != "default" ]]; then
		if (( $comp_type_rc == 1 )); then
			cti_untested "Skipping assertion $ITERATION as " \
			    "$compression_type compression is not supported " \
			    "by lofi on this system"
			return
		fi
	fi

	#
	# Create the file that we're going to use
	#
	$RM -rf $lofi_file 2>&1
	cmd="touch $lofi_file"
	record_cmd_execution "$cmd"
	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		cti_unresolved "Unable to test '$assert_desc' because" \
		    "creation of file '$lofi_file' failed"
		display_execution_record
		return
	fi

	#
	# Compress the file
	#
	execution_phase_assert
	cmd="lofiadm -C $compression_arg $lofi_file"
	record_cmd_execution "$cmd"
	cti_execute "FAIL" "$cmd"
	if (( $? == 0 )); then
		cti_report "Compression of zero-length file succeeded"
		cmd="$LS -l $lofi_file"
		record_cmd_execution "$cmd"
		typeset current_size=`$cmd | awk ' { print $5 } '`
		if (( $current_size == 0 )); then
			cti_report "File size after compression is '0' as" \
			    "expected"
		else
			cti_fail "File size after compression should be '0';"
			    "got '$current_size' instead"
			status=1
		fi

		#
		# Decompress the file
		#
		cmd="lofiadm -U $lofi_file"
		record_cmd_execution "$cmd"
		cti_execute "FAIL" "$cmd"
		if (( $? == 0 )); then
			cti_report "Decompression of zero-length file succeeded"
			cmd="$LS -l $lofi_file"
			record_cmd_execution "$cmd"
			typeset current_size=`$cmd | awk ' { print $5 } '`
			if (( "$current_size" == 0 )); then
				cti_pass "File size after decompression is" \
				    "'0' as expected"
			else
				cti_fail "File size after decompression" \
				    "should be '0' got '$current_size' instead"
				status=1
			fi
		fi
	else
		cti_report "Compression of zero-length file failed when it" \
		    "was expected to succeed"
		status=1
	fi

	#
	# Clean up
	#
	execution_phase_cleanup
	cmd="$RM $lofi_file"
	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		status=1
	fi

	if [[ -n "$VERBOSE" ]] || (( $status != 0)); then
		display_execution_record
	else
		delete_execution_record
	fi
}

. ./tp_compression_static_001	# Contains static 'compression' test purpose 1
. ./tp_compression_static_002	# Contains static 'compression' test purpose 2
. ./tp_compression_static_003	# Contains static 'compression' test purpose 3
. ./tp_compression_static_004	# Contains static 'compression' test purpose 4
. ./tp_compression_static_005	# Contains static 'compression' test purpose 5
. ./tp_compression_static_006	# Contains static 'compression' test purpose 6

. ${TET_ROOT:?}/common/lib/ctilib.ksh
