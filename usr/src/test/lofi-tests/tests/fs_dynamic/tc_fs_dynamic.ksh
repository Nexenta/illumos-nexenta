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
# ident	"@(#)tc_fs_dynamic.ksh	1.2	08/12/19 SMI"
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

# Build the dynamic configuration files for tp_fs_dynamic
dynamic_config_file="$CTI_LOGDIR/tc_lofi_compress_create.cfg"
cat /dev/null > $dynamic_config_file

# This is the full list.
file_size_pos_params="65m 100m 1g"
filesystem_pos_params="zfs ufs hsfs"

first_file_size_pos_param=`echo $file_size_pos_params | awk ' { print $1 } ' `

# This value keeps track of the number of dynamic fs tests that
# will be created.
ic_num=1
num_comp_tests=0

# This blocks builds the set of all possible combinations of all positive
# test case parameters for dynamic fs tests.
typeset skip_arg
for file_size_pos_param in $file_size_pos_params
do
	#
	# Any tests involving large (1g) file sizes should be skipped
	# if the run mode is 'short'
	#
	if [[ "$RUNMODE" = "short" && "$file_size_pos_param" = "1g" ]]; then
		skip_arg="skip=$RUNMODE"
	else
		skip_arg=""
	fi

	for filesystem_pos_param in $filesystem_pos_params
	do
		echo "pos $file_size_pos_param" \
		    "$file_type_pos_param" \
		    "$filesystem_pos_param $skip_arg" >>\
		    $dynamic_config_file
		((ic_num = $ic_num + 1))

	done
done

# Build the 'icN' and 'iclist' variables to add to the iclist.
iclist=""
counter=1
while (( $counter < $ic_num )); do
	eval ic$counter=\"tp_fs_dynamic\"
	eval iclist=\"$iclist ic$counter\"
	((counter = $counter + 1))
done

. ./tp_fs_dynamic	# Contains dyamic fs test purpose

. ${TET_ROOT:?}/common/lib/ctiutils.ksh
. ${TET_ROOT}/lib/ksh/tcm.ksh
. ${TET_SUITE_ROOT}/src/lib/ksh/fs_common.ksh
