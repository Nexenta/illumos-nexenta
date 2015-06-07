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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)tc_add_dynamic.ksh	1.2	08/12/19 SMI"
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

	#
	# cleanup /dev/lofi to prepare for the next test
	#
	if [ -d /dev/lofi ]; then
		rm -rf /dev/lofi
	fi
}

default_lofi_size="10M"

#
# The following sets of parameters will be used to build dynamic test cases.
# All combinations of valid parameters will be built, while for negative
# parameters only one negative parameter will be allowed per test case.
#
dynamic_config_file="$CTI_LOGDIR/tc_lofi_basic_create.cfg"
cat /dev/null > $dynamic_config_file

lofi_dev_pos_params="none full_path_block full_path_char"
lofi_dev_neg_params="partial_path non_lofi_path"
file_name_pos_params="full_path"
file_name_neg_params="none partial invalid"
file_size_pos_params="zero non_zero"

ic_num=1

# This block builds the set of all possible combinations of all positive
# test case parameters.
for lofi_dev_param in $lofi_dev_pos_params
do
	for file_name_param in $file_name_pos_params
	do
		for file_size_param in $file_size_pos_params
		do
			echo "pos $lofi_dev_param $file_name_param" \
			    "$file_size_param" >> $dynamic_config_file
			let ic_num=$ic_num+1
		done
	done
done

# This block builds a set of test cases based on the negative 'lofi dev'
# parameters with all combinations of positive parameters for the other
# areas.
for lofi_dev_param in $lofi_dev_neg_params
do
	for file_name_param in $file_name_pos_params
	do
		for file_size_param in $file_size_pos_params
		do
			echo "neg $lofi_dev_param $file_name_param" \
			    "$file_size_param" >> $dynamic_config_file
			let ic_num=$ic_num+1
		done
	done
done

# This block builds a set of test cases based on the negative 'file name'
# parameters with all combinations of positive parameters for the other
# areas.
for file_name_param in $file_name_neg_params
do
	for lofi_dev_param in $lofi_dev_pos_params
	do
		for file_size_param in $file_size_pos_params
		do
			echo "neg $lofi_dev_param $file_name_param" \
			    "$file_size_param" >> $dynamic_config_file
			let ic_num=$ic_num+1
		done
	done
done

# Build the 'icN' and 'iclist' variables.
counter=1
iclist=""
while (( $counter < $ic_num )); do
	eval ic$counter=\"tp_add_dynamic\"
	eval iclist=\"$iclist ic$counter\"
	let counter=$counter+1
done

. ./tp_add_dynamic	# Contains test purpose for dynamic test cases

. ${TET_ROOT:?}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
. ${TET_SUITE_ROOT}/src/lib/ksh/fs_common.ksh
