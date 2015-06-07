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
# ident	"@(#)tc_compression_dynamic.ksh	1.3	09/03/09 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/startup_cleanup_common

tet_startup=startup
tet_cleanup=cleanup

reference_tree=$SCRATCH_DIR/$$_ref_tree

function startup {
	cti_report "In startup"

	typical_startup_checks
	if (( $? != 0 )); then
		exit 1
	fi

	cti_report "Building 'reference tree' $reference_tree"
	build_reference_tree $reference_tree
	if (( $? != 0 )); then
		exit 1
	fi
}


function cleanup {
	cti_report "In cleanup"
	if [[ -d $reference_tree ]]; then
		cti_report "Deleting 'reference tree' $reference_tree"
		cti_execute "FAIL" "$RM -rf $reference_tree"
		if (( $? != 0 )); then
			exit 1
		fi
	fi

	# cleanup /dev/lofi to prepare for the next test
	if [ -d /dev/lofi ]; then
		rm -rf /dev/lofi
	fi
}


#
# NAME
#	runmode_skip
#
# SYNOPSIS
#	runmode_skip <file size parameter> <one in N (for medium mode)>
#
# DESCRIPTION
#	Determine if the assertion with the given set of parameters
#	should be skipped based on the value of RUNMODE.  For long
#	mode, no tests are skipped.  For medium mode, only one test
#	for a particular combination of file size, compression type,
#	and segment size is run and all other occurances of that
#	combination are skipped.  Short mode skips all of the same
#	tests that medium mode does, plus all but one of the tests
#	that involve the largest file size.
#
#	The intention is for medium and short mode to still provide
#	good general coverage while significantly reducing the
#	execution time compared to long mode.
#
# RETURN VALUES
#	Undefined
#
function runmode_skip {
	typeset used_combo_file="$1"
	typeset file_size_param="$2"
	typeset filesystem_param="$3"
	typeset compression_type_param="$4"
	typeset segment_size_param="$5"

	typeset combo last_line
	typeset prev_file_size prev_filesystem prev_compression_type
	typeset prev_segment_size

	# In short mode we only do the first 'large file' (1g) test that comes
	# up and skip any subsequent ones.
	if [[ "$RUNMODE" = "short" && "$file_size_param" = "1g" ]]; then
		if grep "^1g" $used_combo_file >/dev/null
		then
			# A combination using a 'large file' has been done.
			echo "skip=$RUNMODE"
			return
		fi
	fi

	# Always execute the tests for the smallest file size.  If size isn't
	# the smallest, then for 'short' and 'medium' run modes we may not
	# run this test.
	if [[ "$file_size_param" != "65m" ]]; then
		if [[ "$RUNMODE" = "medium" || "$RUNMODE" = "short" ]]; then
			last_line=`tail -1 $used_combo_file`
			if [[ -n "$last_line" ]]; then
				# Get the set of parameters for the last
				# combination that was actually used.
				echo "'$last_line'" >> /tmp/last_line
				set $last_line
				prev_file_size=$1
				prev_filesystem=$2
				prev_compression_type=$3
				prev_segment_size=$4

				# If we've already done a combo with this file
				# size, compression type, and segment size then
				# skip it.
				if grep "^$file_size_param .* $compression_type_param $segment_size_param" \
				    $used_combo_file >/dev/null
				then
					echo "skip=$RUNMODE"
					return
				fi
			fi
		fi
	fi

	# The current combination is one we will test.  Don't echo anything
	# (so the caller won't skip this test) and add the current set of
	# parameters to the list of combinations used.
	combo="$file_size_param $filesystem_param $compression_type_param"
	combo="$combo $segment_size_param"
	echo "$combo" >> $used_combo_file
}


# Set this parameter equal to the number of invocable components
# from above. This parameter is the base starting number for the
# dynamic test cases created below.
ic_num=2


# Build the dynamic configuration files for tp_compression_dynamic_001
dynamic_config_file="$CTI_LOGDIR/tc_lofi_compress_create.cfg"
cat /dev/null > $dynamic_config_file

# These variables contain the various parameters that will be used to
# generate the dynamic test cases.  Note that the lofi/config/test_config
# file specifies environment variables that can be set to restrict some
# of the parameters that get tested.  When adding a parameter value to one of
# these lists, comments for the appropriate env var name in the test_config
# file should be updated to list the parameter.
#
# The size parameters were chosen to test a variety of file sizes as well
# as one value that is not a multiple of 128k (as that's the default segment
# size).  In order to work with ZFS, all sizes must be above 64M.
#
#                                                       Env var name affected
# List and values                                       in test_config file
# ---------------------------------------------------   ---------------------
file_size_pos_params="65m 100m 1g 68157440"		# N/A
filesystem_pos_params="zfs ufs hsfs"			# FS_TYPES
compress_pos_params="default gzip gzip-6 gzip-9 lzma"	# COMPRESSION_TYPES
segmentsize_pos_params="default 128k 64k 1m"		# COMPRESSION_SEG_SIZES
compress_neg_params="invalid"				# COMPRESSION_TYPES
segmentsize_neg_params="none kkk 0"			# COMPRESSION_SEG_SIZES

# For ZFS we'll only execute on one file size (details in comments
# where this variable is used in the loop).
first_file_size_pos_param=`echo $file_size_pos_params | awk ' { print $1 } ' `

# This value keeps track of the number of compression tests that
# will be created.
ic_num=1
num_comp_tests=0
used_combo_file="${SCRATCH_DIR}/$$_used_combos"
typeset skip_arg=""
rm -f $used_combo_file >/dev/null
touch $used_combo_file

# This blocks builds the set of all possible combinations of all positive
# test case parameters for compression tests.
for file_size_pos_param in $file_size_pos_params
do
	for compress_pos_param in $compress_pos_params
	do
		for segmentsize_pos_param in $segmentsize_pos_params
		do
			for filesystem_pos_param in $filesystem_pos_params
			do
				# As compressed zpools can't be used, all we
				# can do with a compressed zpool is run 'fstyp'
				# on it.  That being the case, there's no point
				# in working through all of the possible file
				# sizes -- we'll only do the first one.
				if [[ $filesystem_pos_param = "zfs" ]]; then
					if [[ $file_size_pos_param != \
					    "$first_file_size_pos_param" ]]
					then
						continue
					fi
				fi

				skip_arg=`runmode_skip $used_combo_file $file_size_pos_param $filesystem_pos_param $compress_pos_param $segmentsize_pos_param`
				echo "pos $file_size_pos_param" \
				    "$filesystem_pos_param" \
				    "$compress_pos_param" \
				    "$segmentsize_pos_param $skip_arg">>\
				    $dynamic_config_file
				((ic_num = $ic_num + 1))

			done
		done
	done
done
rm -f $used_combo_file >/dev/null
touch $used_combo_file

# This step builds test cases for the negative compression parameters.
# There is only one negative parameter for each negative test case.
for file_size_pos_param in $file_size_pos_params
do
	for compress_neg_param in $compress_neg_params
	do
		for segmentsize_pos_param in $segmentsize_pos_params
		do
			for filesystem_pos_param in $filesystem_pos_params
			do
				skip_arg=`runmode_skip $used_combo_file $file_size_pos_param $filesystem_pos_param $compress_pos_param $segmentsize_pos_param`
				echo "neg $file_size_pos_param" \
			       	    "$filesystem_pos_param" \
				    "$compress_neg_param" \
				    "$segmentsize_pos_param" \
				    "$skip_arg" >>\
				    $dynamic_config_file
				((ic_num = $ic_num + 1))

				if [[ $filesystem_pos_param == "hsfs" ]]; then
					# Segment sizes judged not so
					# interesting for HSFS, so don't
					# run through all for that fs.
					continue 4
				fi
			done
		done
	done
done
rm -f $used_combo_file >/dev/null
touch $used_combo_file

# This step builds test cases for the negative segment size parameters.
# There is only one negative parameter for each negative test case.
for file_size_pos_param in $file_size_pos_params
do
	for compress_pos_param in $compress_pos_params
	do
		for segmentsize_neg_param in $segmentsize_neg_params
		do
			for filesystem_pos_param in $filesystem_pos_params
			do
				skip_arg=`runmode_skip $used_combo_file $file_size_pos_param $filesystem_pos_param $compress_pos_param $segmentsize_pos_param`
				echo "neg $file_size_pos_param" \
				    "$filesystem_pos_param" \
				    "$compress_pos_param" \
				    "$segmentsize_neg_param" \
				    "$skip_arg" >>\
				     $dynamic_config_file
				((ic_num = $ic_num + 1))
			done
		done
	done
done
rm -f $used_combo_file >/dev/null

# Build the 'icN' and 'iclist' variables to add to the iclist.
iclist=""
counter=1
while (( counter < $ic_num )); do
	eval ic$counter=\"tp_compression_dynamic_001\"
	eval iclist=\"$iclist ic$counter\"
	((counter = $counter + 1))
done

. ./tp_compression_dynamic_001	# Contains 'compression' test purpose 001

. ${TET_ROOT:?}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
. ${TET_SUITE_ROOT}/src/lib/ksh/fs_common.ksh
