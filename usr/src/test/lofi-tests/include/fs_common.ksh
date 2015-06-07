#
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
# ident	"@(#)fs_common.ksh	1.4	09/03/09 SMI"
#

. ${TET_SUITE_ROOT}/lofi-tests/lib/util_common

LOFIADM="/usr/sbin/lofiadm"
LS=/usr/bin/ls
MKFILE=/usr/sbin/mkfile
MKISOFS=/usr/bin/mkisofs
RM=/usr/bin/rm
TMPDIR=/tmp
NEWFS=/usr/sbin/newfs
FSTYP=/usr/sbin/fstyp
ZPOOL=/usr/sbin/zpool

#
# Minimum and maximum sizes of files that will be created to populate
# reference tree.
#
MIN_ADJ_FILE_SIZE=0
MAX_ADJ_FILE_SIZE=65536

DEFAULT_FILE_SIZE="10M"
LOFI_DEV_NUM_LIMIT=128

#
# NAME
#	make_and_verify_file
#
# SYNOPSIS
#	make_and_verify_file <file size> <full pathname>
#
# DESCRIPTION
#	Use mkfile(1M) to create a file with the specified size and name.
#	If the mkfile returns good status, use ls to verify the existence
#	of the file.
#
# RETURN VALUES
#	0	File created and verified
#	1	File creation or verification failed
#	
function make_and_verify_file {
	typeset size="$1"
	typeset filename="$2"
	typeset cmd

	# If the specified file already exists, delete it.
	if [[ -f "$filename" ]]; then
		$RM -f $filename
		if (( $? != 0 )); then
			cti_unresolved "Error: File '$filename' already" \
			    "exists and this process can't delete it."
			return 1
		fi
	fi

	# Build the command to create the file.  Any size parameter that
	# starts with a zero (excluding leading whitespace) we interpret as
	# being zero (this is so that we'll catch 0, 0k, 0m, 0G, etc.).
	echo $size | sed 's/^[ \t]*//' | grep "^0" >/dev/null
	if (( $? == 0 )); then
		# Use 'touch' to create zero-length file.
		cmd="/usr/bin/touch $filename"
	else
		# Use 'mkfile' to create file.
		cmd="$MKFILE $size $filename"
	fi

	# Create the file
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "Error: Unable to create file via '$cmd'"
		return 1
	fi

	# Verify that the file exists
	cmd="ls $filename"
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "Error: '$cmd' returned good status but an 'ls'" \
		    "of the file fails"
		return 1
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "File $filename of size $size successfully created"
	fi

	return 0
}


#
# NAME
#	cleanup_lofi_files
#
# SYNOPSIS
#	cleanup_lofi_files
#
# DESCRIPTION
#	Find all lofi files (assuming they were created using the predefined
#	lofi files names) and delete them.
#
# RETURN VALUES
#	0	All lofi files delete or no lofi files found.
#	1	Unable to delete one or more lofi files.
#	
function cleanup_lofi_files {
	typeset lofi_file_list=`$LS $SCRATCH_DIR | grep lofi_file_`
	typeset retval=0
	typeset cmd lofi_file

	if [[ -z "$lofi_file_list" ]]; then
		# No files to delete
		return 0
	fi

	for lofi_file in $lofi_file_list
	do
		cmd="$RM $SCRATCH_DIR/$lofi_file"
		record_cmd_execution "$cmd"
		cti_execute "UNRESOLVED" "$cmd"
		if (( $? != 0 )); then
			retval=1
		fi
	done

	return $retval
}


#
# NAME
#	associate_lofidev_and_file
#
# SYNOPSIS
#	associate_lofidev_and_file <type> <name>
#
# DESCRIPTION
#	For a given file name determine the associated lofi device, or
#	vice versa.  The calling function identifies the type of name it's
#	passing in and the name itself.  This function determines the name
#	of the associated item and prints it to standard out so it can be
#	captured by the caller.
#
# RETURN VALUES
#	0	Found a 1-to-1 match between the lofi device and a file
#	1	lofiadm command failed or produced no output
#	2	lofi device listed more than once, associated with multiple
#		files (shouldn't happen)
#	3	lofi device not listed, associated with no files
function associate_lofidev_and_file {
	typeset type="$1"
	typeset name="$2"
	typeset retval=0
	typeset cmd match_list line

	# Execute 'lofiadm' command without any arguments, which should
	# output the current lofi setup.  Not knowing if we're being called
	# for a positive or negative test case, we'll pass a status value
	# of "PASS" to cti_execute() to prevent it from setting the tet status
	# to something negative on failure.  The calling function will be the
	# one to set the tet status.
	cmd="$LOFIADM"
	record_cmd_execution "$cmd"
	cti_execute "PASS" "$cmd"
	if (( $? != 0 )); then
		return 1
	fi

	# Make sure the output isn't null (shouldn't ever be, as lofiadm
	# should still print out column headers even when no lofiadm
	# devices are configured).
	if [[ ! -s cti_stdout ]]; then
		cti_report "'lofiadm' command returned good status but" \
		    "printed nothing to stdout"
		return 1
	fi

	# Walk through every line in the file, looking for ones in which
	# the lofi block device name (first column) matches the device name
	# provided to us by the calling function.  
	{ while read line; do
		if [[ -n "$line" ]]; then
			set $line
			if [[ "$type" = "lofi_dev" ]]; then
				# Match on lofi device name (first column)
				if [[ "$1" = "$name" ]]; then
					# Capture matching file
					match_list="$match_list $2"
				fi
			else
				# Match on file name (second column)
				if [[ "$2" = "$name" ]]; then
					# Capture matching lofi dev
					match_list="$match_list $1"
				fi
			fi
		fi
	done } < cti_stdout

	# Did we find a match?
	if [[ -n "$match_list" ]]; then
		set $match_list
		if (( $# > 1 )); then
			if [[ "$type" = "lofi_dev" ]]; then
				cti_report "Error: 'lofiadm' command showed" \
				    "more than one file associated with" \
				    "device ${name}: $match_list"
			else
				cti_report "Error: 'lofiadm' command showed" \
				    "more than one lofi dev associated with" \
				    "file ${name}: $match_list"
			fi
			retval=2
		fi
	else
		# Didn't find an entry for the specified lofi device.  Don't
		# print a failure as this might have been expected.
		retval=3
	fi

	# Output the list of files we generated so it can be captured by
	# the calling function, stripping off any leading whitespace.
	echo $match_list | sed 's/^ //'

	return $retval
}


#
# NAME
#	add_lofi_device
#
# SYNOPSIS
#	add_lofi_device <file> <optional lofi dev>
#
# DESCRIPTION
#	Execute the 'lofiadm -a' command to create a lofi device based on
#	the specified file (the file must already exist).  In addition to
#	checking the return code from 'lofiadm -a', the function performs
#	additional checks to be sure the command behaved as expected.
#
# RETURN VALUES
#	0	lofi device successfully created and verified.
#	1	creation of lofi device failed.
#	2	creation of lofi device returned good status but additional
#		verification failed.
#	In addition to return codes, if no lofi device name was specified,
#	the name of the lofi device chosen by 'lofiadm -a' will be echoed
#	so that it can be captured by the calling function.
#
function add_lofi_device {
	typeset file="$1"
	typeset desired_lofi_dev="$2"
	typeset desired_lofi_dev lofi_dev cmd_retval line dev_match_count
	typeset file_match_count dev_match cmd
	typeset retval=0

	# Build the lofiadm command
	typeset cmd="$LOFIADM -a $file $desired_lofi_dev"

	# Execute lofiadm command.  Note:  We don't know if the lofiadm -a
	# command is expected to pass or fail as we could be called by a
	# negative test case.  For that reason, we pass in a "PASS" status to
	# cti_execute so that it won't set a failing TET status if the
	# command doesn't succeed.
	record_cmd_execution "$cmd"
	cti_execute "PASS" "$cmd"
	cmd_retval=$?

	# 'lofiadm -a' failed.  Nothing else for us to do.
	if (( $cmd_retval != 0 )); then
		cti_reportfile cti_stderr
		return 1
	fi

	# Retrieve whatever lofiadm printed to stdout
	typeset lofi_dev_returned="`cat cti_stdout`"

	if [[ -n "$desired_lofi_dev" ]]; then
		lofi_dev="$desired_lofi_dev"
		# We specified a particular lofi device, in which case
		# lofiadm should not have printed anything to stdout.
		if [[ -n "$lofi_dev_returned" ]]; then
			cti_report "Err: 'lofiadm -a' cmd should not print" \
			    "to stdout when the lofi dev is specified"
			cti_report "The following was printed to stdout:" \
			    "$lofi_returned_dev"
			retval=2
		fi
	else
		lofi_dev="$lofi_dev_returned"
		# We did not specify a particular lofi device, so lofiadm
		# should have printed the name of the lofi device it created
		# to stdout.
		if [[ -n "$lofi_dev_returned" ]]; then
			set $lofi_dev_returned
			if (( $# > 1 )); then
				retval=2
			fi
		else
			cti_report "Error:  $LOFIADM -a succeeded but did" \
			    "not provide a lofi device name"
			retval=2
		fi
	fi

	# Verify that 'lofiadm' shows the correct block device and file
	# for the just created lofi dev.
	lofi_dev_reported_back=`associate_lofidev_and_file file $file`
	if (( $? != 0 )); then
		cti_report "'lofiadm -a' command returned good status but" \
		    "'lofiadm' output shows irregularities."
		retval=2
	else
		if [[ "$lofi_dev_reported_back" = "$lofi_dev" ]]; then
			if [[ -n "$VERBOSE" ]]; then
				cti_report "'lofiadm' shows file '$file'" \
				    "associated with device $lofi_dev as" \
				    "expected"
			fi
		else
			cti_report "Error: File $file should be associated" \
			   "with lofi device $desired_lofi_dev but 'lofiadm'" \
			   "shows it associated with $lofi_dev_reported_back"
			retval=2
		fi
	fi

	if (( $retval != 0 )); then
		cti_report "Output of 'lofiadm -a' follows:"
		cti_reportfile cti_stdout
	fi

	# If a lofi devname was output by the lofiadm command, echo it so
	# it can be captured by the function that called us.
	if [[ -n "$lofi_dev_returned" ]]; then
		echo $lofi_dev_returned
	fi

	return $retval
}


#
# NAME
#	del_lofi_device
#
# SYNOPSIS
#	del_lofi_device <lofi dev or filename>
#
# DESCRIPTION
#	Delete a lofiadm device based on the provided lofi device name or
#	file name.
#
# RETURN VALUES
#	0	Delete completed successfully
#	1	Delete or verification of delete was unsuccessful
#
function del_lofi_device {
	typeset lofi_dev_or_file="$1"
	typeset cmd

	cmd="$LOFIADM -d $lofi_dev_or_file"
	record_cmd_execution "$cmd"

	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		return 1
	fi

	return 0
}


#
# NAME
#	del_lofi_dev_and_file
#
# SYNOPSIS
#	del_lofi_dev_and_file <filename>
#
# DESCRIPTION
#	Since most test cases will have to delete both the lofi device they
#	created and the file associated with that device, this function
#	exists to allow them to do both with a single function call.
#
# RETURN VALUES
#	0	Deletion of both lofi device and file was successful
#	1	Deletion of lofi device and/or file was unsuccessful
#
function del_lofi_dev_and_file {
	typeset filename=$1
	typeset retval=0
	typeset cmd

	# Delete the lofi device
	del_lofi_device $filename
	if (( $? != 0 )); then
		retval=1
	fi

	# Delete the file
	cmd="$RM $filename"
	record_cmd_execution "$cmd"
	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		retval=1
	fi

	return $retval
}


#
# NAME
#       get_supported_compression_types
#
# SYNOPSIS
#       get_supported_compression_types
#
# DESCRIPTION:
#	Determine which compression types are supported by lofi on the
#	system the test suite is being run on.
#
# RETURN VALUES
#	No value is returned.  The names of the supported compression
#	algorithms (if any) are printed to stdout do they can be captured
#	by the calling function.
#
function get_supported_compression_types {

	#
	# Get usage message for lofiadm and extract the line containing
	# compression info, if it's there.  If no compression info is found,
	# we're running on an OS version that doesn't support lofi compression.
	#
	typeset compression_info=`$LOFIADM -h 2>&1 | grep "lofiadm -C"`
	if [[ -n $compression_info ]]; then
		#
		# Found line containing compression info.  Parse it to extract
		# the supported compression types.
		#
		comp_list=`print $compression_info | \
		    sed -e 's/^lofiadm -C *//' | sed -e 's/\] .*//' | \
		    sed -e 's/\[//' | sed -e 's/|/ /g'`

		#
		# Depending on the OS version, the usage message will contain
		# one of the following descriptions of compression algorithms:
		#	-C [algorithm]
		# or
		#	-C [<algorithm1>|<algorithm2>|...|<algorithmN>]
		# The former is the style used by the initial compression
		# support putback into Solaris and you just have to know that
		# the supported types are 'gzip', 'gzip6', and 'gzip9'.  The
		# latter is the style for subsequent additions of compression
		# algorithms and specifically identifies which algorithms are
		# supported.
		#
		if [[ $comp_list == 'algorithm' ]]; then
			print "gzip gzip-6 gzip-9"
		else
			print $comp_list
		fi
	fi
}


#
# NAME
#	is_compression_type_supported
#
# DESCRIPTION
#	Determine if the desired compression type is supported by lofi on the
#	system the test suite is running on.
#
# SYNOPSIS
#	is_compression_type_supported <desired compression type>
#
# RETURN VALUES
#	0	Desired compression type is supported
#	1	Desired compression type is not supported
#	2	No lofi compression supported on system
#
function is_compression_type_supported {
	typeset desired_compression_type="$1"
	typeset supported_compression_types=`get_supported_compression_types`

	if [[ ! -n $supported_compression_types ]]; then
		# lofi compression not supported at all on this system
		return 2
	fi

	#
	# Compression is supported, so check if the desired compression type
	# is one of the supported ones.
	#
	for comp_type in $supported_compression_types
	do
		if [[ $desired_compression_type = $comp_type ]]; then
			# Desired compression type is supported
			return 0
		fi
	done

	# Desired compression type is not supported
	return 1
}


#
# NAME
#       create_ufs
#
# SYNOPSIS
#       create_ufs -f <file> -l <lofi device>
#
# DESCRIPTION:
#
#	Create a ufs filesystem. The <file> argument passed in is
#	first lofi mounted and then a ufs is created on the lofi
#	mounted device.  The <lofi_device> specifies a particular
#	lofi device name to use.
#
# RETURN VALUES
#       0       ufs filesystem successfully created
#       1       ufs filesystem not successfully created
#
function create_ufs {

	typeset file_name_arg lofi_dev option

	while getopts f:l:z: option
	do
		case $option in
			f)	file_name_arg="$OPTARG";;
			l)	lofi_dev="$OPTARG";;
		esac
	done

	# Build 'raw' lofi device name based on block name
	raw_lofi_dev=`echo $lofi_dev | sed 's/\/lofi/\/rlofi/'`

	# Create ufs filesystem on the specified device
	cmd="$NEWFS $raw_lofi_dev"
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "unable to create ufs on lofi device" \
		    "$lofi_device_arg."
		return 1
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "Creation of ufs on lofi device $lofi_device_arg" \
	 	   "succeeded."
	fi

        # The newfs command returned successfully, so check to make
        # sure that a ufs filesystem has been created on the lofi
        # device.
        cmd="$FSTYP $raw_lofi_dev"
        record_cmd_execution "$cmd"
        fstype=`$cmd`
        if (( $? != 0 )); then
                cti_report "ufs does not appear to be correctly associated" \
                    "with lofi device lofi device $lofi_device_arg."
                cti_unresolved
                return 1
        fi

	return 0

}


#
# NAME
#	create_zfs <file>
#
# SYNOPSIS
#	create_zfs -f <file> -z <zpool name> -l <lofi device>
#
# DESCRIPTION:
#
#	Create a lofi device using the specified file and then place a
#	zfs filesystem on it.
#
# RETURN VALUES
#	0	zfs filesystem successfully created
#	1	zfs filesystem not successfully created
#
function create_zfs {

	typeset file_name_arg lofi_dev zpool_name option

	while getopts f:l:z: option
	do
		case $option in
			f)	file_name_arg="$OPTARG";;
			l)	lofi_dev="$OPTARG";;
			z)	zpool_name="$OPTARG";;
		esac
	done

	typeset lofi_device_returned fstype
	typeset retval=0
	typeset add_status=0

	# Now that a file has been successfully mounted as a lofi device,
	# create a zfs filesystem on it.
	cmd="$ZPOOL create $zpool_name $lofi_dev"
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "Unable to create a zpool using lofi device" \
		    "$lofi_dev."
		return 1
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "Creation of zpool using lofi device" \
		    "$lofi_device_arg succeeded."
	fi

	# The following checks to see if zpool status is returned.
	cmd="$ZPOOL status"
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "Check of zpool $zpool_name failed."
		cleanup_lofi_zfs -z $zpool_name -l $file_name_arg
		return 1
	fi


	# The zpool command returned successfully, so check to make
	# sure that a zfs filesystem has been created on the lofi
	# device.
	cmd="$FSTYP $lofi_dev"
	record_cmd_execution "$cmd"
	fstype=`$cmd`
	if (( $? != 0 )) || [[ $fstype != "zfs" ]]; then
		cti_report "zfs does not appear to be correctly associated"\
		    "lofi device $lofi_device_arg."
		cti_unresolved
		cleanup_lofi_zfs -z $zpool_name -l $file_name_arg
		return 1 
        fi

	return 0
}


#
# NAME
#	cleanup_lofi_zfs
#
# SYNOPSIS
#	cleanup_lofi_zfs -z <zpool name> -l <lofi device or file name>
#
# RETURN VALUES
#	0	zfs filesystem and lofi device successfully deleted
#	1	zfs filesystem or lofi device could not be deleted
#
function cleanup_lofi_zfs {

	typeset lofi_dev_or_file zpool_name

	while getopts l:z: option
	do
		case $option in
			l)	lofi_dev_or_file="$OPTARG";;
			z)	zpool_name="$OPTARG";;
		esac
	done

	cmd="$ZPOOL destroy $zpool_name"
	record_cmd_execution "$cmd"
	cti_execute "UNRESOLVED" "$cmd"
	if (( $? != 0 )); then
		cti_report "Unable to remove zpool '$zpool_arg'"
		return 1
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "zpool '$zpool_arg' removed"
	fi

	del_lofi_device $lofi_dev_or_file
	if (( $? != 0 )); then
		cti_report "Deleting the lofi device associated with" \
		    "$lofi_dev_or_file failed."
		return 2
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "lofi device associated with '$lofi_dev_or_file'" \
		    "deleted"
	fi

        return 0
}


#
# NAME
#	import_zfs
#
# SYNOPSIS
#	import_zfs <path to device> <zpool name>
#
# DESCRIPTION
#	Import the specified zpool.
#
# RETURN VALUE
#	0	ZFS filesystem successfully imported
#	1	Unable to import ZFS filesystem
#
function import_zfs {
	typeset path_to_dev="$1"
	typeset zpool_name="$2"

	typeset dir=`dirname $1`
	typeset cmd="zpool import -d $dir $zpool_name"
	record_cmd_execution "$cmd"

	cti_execute "FAIL" "$cmd"
	if (( $? != 0 )); then
		return 1
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "zpool '$zpool_name' associated with" \
		    "'$path_to_dev' imported"
	fi

	return 0
}


#
# NAME
#	build_reference_tree
#
# SYNOPSIS
#	build_reference_tree <directory>
#
# DESCRIPTION
#	Build a hierarchy of directories and files, covering a variety of
#	permission values and sizes.  The expectation is that the resulting
#	tree will copied to a filesystem, and that the contents of that
#	filesystem can be compared back against this tree for validation.
#
# RETURN VALUES
#	0 - reference tree built successfully
#	1 - errors encountered, reference tree not created or not complete
function build_reference_tree {
	typeset ref_dir="$1"
	typeset owner=0;
	typeset group=0;
	typeset other=0;

	typeset def_other=4
	typeset def_group=4
	typeset def_owner=4
	typeset def_misc=0

	# Delete previous version if one exists
	if [[ -d "$ref_dir" ]]; then
		cti_report "$ref_dir exists; deleting to create fresh version"
		$RM -rf $ref_dir
		if (( $? != 0 )); then
			cti_report "Unable to delete existing $ref_dir"
			return 1
		fi
	fi

	# Create top-level directory
	cti_execute "FAIL" "mkdir -p $ref_dir"
	if (( $? != 0 )); then
		cti_report "Unable to make directory $ref_dir"
		return 1
	fi

	typeset counter=0
	typeset size=$MIN_ADJ_FILE_SIZE
	typeset size_inc
	let size_inc=$MAX_ADJ_FILE_SIZE/10
	typeset perm_type bits cur_dir

	# The 'for' and nested 'while' loop create a subdirectory for each
	# type of file permissions ('other', 'group', 'owner', and 'misc'),
	# then for each combination of permissions bits for that type (0-7)
	# creates a file and sets the permissions.  The sizes of the files
	# created is varied.
	for perm_type in other group owner misc
	do
		# Create subdirectory for the permissions type
		cur_dir=$ref_dir/$perm_type
		cti_execute "FAIL" "mkdir $cur_dir"
		if (( $? != 0 )); then
			cti_report "Error: Unable to make directory $cur_dir"
			return 1
		fi

		# For each set of permissions bits for this type, create the
		# file and set the permissions.
		bits=0
		while (( $bits <= 7 )); do
			# Build the set of permissions that the file to be
			# created will have.
			if [[ $perm_type = "other" ]]; then
				perms=$def_misc$def_owner$def_group$bits
			elif [[ $perm_type = "group" ]]; then
				perms=$def_misc$def_owner$bits$def_other
			elif [[ $perm_type = "owner" ]]; then
				perms=$def_misc$bits$def_group$def_other
			else
				perms=$bits$def_owner$def_group$def_other
			fi

			# 'mkfile' won't create files with a size of zero, so
			# depending on the size of this file we'll use 'touch'
			# (zero length file) or 'mkfile' (non zero length) to
			# perform the file creation.
			if (( $size == 0 )); then
				cti_execute "FAIL" "touch $cur_dir/f$perms"
			else
				cti_execute "FAIL" \
				    "mkfile $size $cur_dir/f$perms"
			fi

			if (( $? != 0 )); then
				cti_report "Error: Unable to create file" \
				    "$cur_dir/f$perms"
				return 1
			fi

			# Set permissions on the file.
			cti_execute "FAIL" "chmod $perms $cur_dir/f$perms"
			if (( $? != 0 )); then
				cti_report "Error: Unable to set permissions" \
				    "for file $cur_dir/f$perms"
				return 1
			fi

			# Increment the 'bits' used to set the permissions
			# so that the next file will have a different value
			# than this one.
			let bits=$bits+1

			# Increase the size for the next file, wrapping around
			# back to zero if the size exceeds the maximum allowed.
			let size=$size+$size_inc
			if (( $size > $MAX_ADJ_FILE_SIZE )); then
				size=$MIN_ADJ_FILE_SIZE
			fi
		done
	done

	if [[ -n "$VERBOSE" ]]; then
		cti_report "Reference tree created at '$ref_dir'"
	fi

	return 0
}


#
# NAME
#	create_isofs
#
# SYNOPSIS
#	create_isofs <filename> <source directory>
#
# DESCRIPTION
#	Create file <filename> as an iso image of <directory> using
#	mkisofs(8) and then do some basic santity testing of the
#	command output.
#	
# RETURN VALUE
#	0 - Creation returned good status and output to stderr seems sane
#	1 - Creation returned non-zero status
#	2 - Creation returned good status but output to stderr doesn't seem
#	    right
#
function create_isofs {
	typeset file="$1"
	typeset src_dir="$2"

	# Build and execute mkisofs command
	typeset cmd="$MKISOFS -o $file $src_dir"
	record_cmd_execution "$cmd"
	cti_execute FAIL "$cmd"
	if (( $? != 0 )); then
		cti_report "Creation of iso image unsuccessful"

		# Delete iso image file if it was created.
		if [[ -f "$file" ]]; then
			$RM -rf $file 2>/dev/null
		fi
		return 1
	fi

	# mkisofs should print various bits of information to stderr when
	# it succeeds.  First make sure output was written to stderr...
	if [[ ! -s cti_stderr ]]; then
		cti_report "Cmd '$cmd' returned good status but did not" \
		    "print anything to stderr (which it's expected to)"
		return 2
	fi

	# ...then make sure the output looks sane by looking for the string
	# 'extents written' which should have been printed on the last line.
	grep "extents written" cti_stderr >/dev/null
	if (( $? != 0 )); then
		cti_report "Cmd 'cmd' returned good status but did not find" \
		    "information about extents written in stderr as expected"
		return 2
	fi

	if [[ -n "$VERBOSE" ]]; then
		cti_report "Creation of iso fs ($cmd) succeeded"
	fi

	return 0
}


#
# NAME
#	validate_file
#
# SYNOPSIS
#	validate_file <src_path> <dest_path> <file_basename> <fs_type>
#
# DESCRIPTION
#	Arguments:
#	  src_path - Path to the directory in the original set of dirs/files
#		containing the dir/file that was copied to the destination.
#	  dest_path - Path to the directory in the destination/copy that
#		contains the dir/file.
#	  file_basename - 'basename' of the file/dir being validated.
#	  fs_type - The filesystem type of the destination/copy (e.g.
#		ufs, zfs, iso.
#
# RETURN VALUES
#	0 - All validation checks of the dir/file passed
#	1 - One or more validation checks of the dir/file failed
#
function validate_file {
	typeset src_path="$1"
	typeset dest_path="$2"
	typeset file_basename="$3"
	typeset fs_type="$4"

	typeset retval=0

	src_listing=`ls -l $src_path | grep "$file_basename\$"`
	dest_listing=`ls -l $dest_path | grep "$file_basename\$"`

	if [[ -z "$src_listing" ]]; then
		cti_report "Error: 'ls' doesn't show $file_basename in" \
		    "$src_path"
		return 1
	fi

	if [[ -n "$dest_listing" ]]; then
		dest_file=$dest_path/$file_basename
	else
		# Didn't find a matching file in the destination.  If the
		# destination is an hsfs filesystem, this could be because a
		# '.' was appended to the filename when the iso image was
		# created.
		if [[ $fs_type = "hsfs" ]]; then
			typeset alt_dest_basename="${file_basename}."
			dest_listing=`ls -l $dest_path | grep "$alt_dest_basename\$"`
			if [[ -z "$dest_listing" ]]; then
				cti_report "Error: 'ls' doesn't show" \
				    "$file_basename $alt_dest_basename in" \
				    "$dest_path"
				retval=1
			fi
			dest_file=$dest_path/$alt_dest_basename
		else
			cti_report "Error: 'ls' doesn't show $file_basename" \
			    "in $dest_path"
			retval=1
		fi
	fi

	# Make sure we found a corresponding file in the destination.
	if (( $retval != 0 )); then
		cti_report "Error: Unable to find file corresponding to" \
		    "$src_path in $dest_path"
		return 1
	fi

	# Determine the expected permissions for the file and what the
	# actual permissions are.
	if [[ $fs_type = "hsfs" ]]; then
		# HSFS filesystems are read only, with permissions set to
		# '-r-xr-xr-x' for all files and 'dr-xr-xr-x' for all
		# directories.
		if [[ -d $dest_file ]]; then
			exp_perms="dr-xr-xr-x"
		else
			exp_perms="-r-xr-xr-x"
		fi
	else
		# For other filesystem types, we expect the file permissions
		# to be the same as they were in the source.
		typeset exp_perms=`echo $src_listing | awk ' { print $1 } ' `
	fi
	typeset dest_perms=`echo $dest_listing | awk ' { print $1 } ' `

	if [[ "$exp_perms" != "$dest_perms" ]]; then
		cti_report "Error: Expected $dest_file to have permissions" \
		    "'$exp_perms' but found '$dest_perms' instead"
		retval=1
	fi

	# Verify file size is correct (n/a for directories)
	if [[ ! -d $dest_file ]]; then
		typeset src_size=`echo $src_listing | awk ' { print $5 } ' `
		typeset dest_size=`echo $dest_listing | awk ' { print $5 } ' `

		if [[ "$src_size" != "$dest_size" ]]; then
			cti_report "Error:  Sizes of files" \
			    "$src_path/$file_basename ($src_size) and" \
			    "$dest_file ($dest_size) do not match"
			cti_report "$src_listing"
			cti_report "$dest_listing"
			retval=1
		fi
	fi

	return $retval
}


#
# NAME
#	validate_test_fs
#
# SYNOPSIS
#	validate_test_fs <mount point> <src dir> <fs type>
#
# DESCRIPTION
#
# RETURN CODES
#	0	Comparison of FS against source dir found no problems
#	1	Contents of FS and source dir don't match or trouble accessing
#		FS.
#
function validate_test_fs {
	typeset fs_mnt_point="$1"
	typeset src_dir="$2"
	typeset fs_type="$3"
	typeset start_dir=`pwd`
	typeset status=0

	# Make sure the fs is mounted
	cti_execute "PASS" "df -k $fs_mnt_point"
	if (( $? != 0 )); then
		cti_report "Specified $fs_type fs '$fs_mnt_point' does not" \
		    "appear to be mounted"
		return 1
	fi

	cd $src_dir
	typeset src_file_list=$TMPDIR/src_file_list_$$
	find . -print > $src_file_list
	cd $start_dir

	typeset mod_src src_path dest_path file_basename
	{ while read src_filename; do
		# Strip the leading "./" off the filename
		mod_src_filename=`echo $src_filename | sed 's/^\.\///'`
		src_path=`dirname $src_dir/$mod_src_filename`
		dest_path=`dirname $fs_mnt_point/$mod_src_filename`
		file_basename=`basename $src_dir/$mod_src_filename`
		if [[ "$file_basename" = "." ]]; then
			continue
		fi
		validate_file $src_path $dest_path $file_basename $fs_type
		if (( $? != 0 )); then
			status=1
		fi
	done } < $src_file_list

	if [[ -n "$VERBOSE" ]] && (( $status == 0 )); then
		cti_report "Comparision of '$fs_mnt_point' against" \
		    "'$src_dir' shows no errors (fs type '$fs_type')"
	fi

	# Clean up
	$RM -f $src_file_list 2>/dev/null

	return 0
}


#
# NAME
#	lofi_and_fs_tidy_up
#
# SYNOPSIS
#	lofi_and_fs_tidy_up [ -f lofi file ] \
#	    [ -m hsfs or ufs mnt point ] [ -s status ] [ -z zfs pool name ]
#
# DESCRIPTION
#	Tidy up after execution of a typical lofi test purpose, where there
#	is a single filesystem associated with a single lofi device and a
#	single file.  The caller tells this function about the filesystem and
#	lofi device that were configured.  This function tears down that
#	configuration.
#
# RETURN VALUE
#	0	Tidying-up was successful.
#	1	Problems encountered while tidying-up.
#
function lofi_and_fs_tidy_up {
	typeset lofi_file hufs_mnt_point zpool_name delete_file

	# Process arguments
	typeset option
	while getopts df:m:z: option
	do
		case $option in
			d)	delete_file="yes";;
			f)	lofi_file="$OPTARG";;
			m)	hufs_mnt_point="$OPTARG";;
			z)	zpool_name="$OPTARG";;
		esac
	done

	# Clean up ZFS config
	if [[ -n "$zpool_name" ]]; then
		status=1
		errmsg='device is busy'
		until [ $status == 0 ]; do
			cmd="zpool export $zpool_name"
			record_cmd_execution "$cmd"
			$cmd 2>/tmp/err
			if (( $? != 0)); then
				# if this is busy signal then we want to retry
				if [ "`grep "$errmsg" /tmp/err`" != "" ]; then
					cti_report "zpool '$zpool_name' not cleaned up;" \
					    "can't delete lofi device based on file" \
					    "'$lofi_file'"
				else # return here if error is something else
					return 1
				fi	
			else
				status=0
			fi
		done
	fi

	# Clean up UFS config
	if [[ -n "$hufs_mnt_point" ]]; then
		cmd="umount $hufs_mnt_point"
		record_cmd_execution "$cmd"
		cti_execute "FAIL" "$cmd"
		if (( $? != 0 )); then
			cti_report "ufs fs mounted at '$ufs_mount_point" \
			    "would not unmount; can't delete lofi device" \
			    "based on file '$lofi_file'"
			return 1
		fi
	fi

	# Clean up lofi device
	if [[ -n "$lofi_file" ]]; then
		lofi_dev=`associate_lofidev_and_file file $lofi_file`
		if [[ -n "$lofi_dev" ]]; then
			# There appears to be a lofi device based on the file
			del_lofi_device $lofi_dev
			if (( $? != 0 )); then
				cti_report "Can't delete lofi device" \
				    "'$lofi_dev' and so can't delete file" \
				    "'$lofi_file'"
				return 1
			fi
		fi

		if [[ -n "$delete_file" ]]; then
			cmd="$RM -f $lofi_file"
			record_cmd_execution "$cmd"
			$cmd
			if (( $? != 0 )); then
				cti_report "Could not remove file '$lofi_file'"
				return 1
			fi
		fi
	fi

	return 0
}


#
# NAME
#	create_populated_fs_in_file
#
# SYNOPSIS
#	create_populated_fs_in_file -f <fs type> -l <file> -s <source dir> \
#	    -r <file size> [-c compression type] [-d desired lofi device] \
#	    [-z zpool_name]
#
# DESCRIPTION:
#       Create and populate a filesystem of the specified type in the
#	specified file.  When this function is complete, the specified
#	file will contain a filesystem image that can be accessed by
#	associating the file with a lofi device.  The filesystem is
#	populated by copying (via cpio) the contents of the source dir
#	specified by the -s flag.
#
# RETURN CODES:
#	0	File system created and populated
#	1	Problem with file system creation or populating
#
function create_populated_fs_in_file {
	typeset compression_type desired_lofi_dev file_system_param
	typeset lofi_file file_size_param src_dir zpool_name
	typeset status=0

	# Process arguments
	typeset option
	while getopts c:f:l:r:s:z: option
	do
		case $option in
			c)	compression_type="$OPTARG";;
			d)	desired_lofi_dev="$OPTARG";;
			f)	file_system_param="$OPTARG";;
			l)	lofi_file="$OPTARG";;
			r)	file_size_param="$OPTARG";;
			s)	src_dir="$OPTARG";;
			z)	zpool_name="$OPTARG";;
		esac
	done

	# Verify that the source directory exists
	if [[ ! -d $src_dir ]]; then
		cti_uninitiated "Error:  Specified source dir to copy from" \
		    "($src_dir) does not exist or is not a directory."
		return 1
	fi

	typeset status=0 fs_creation_status=0 fs_population_status=0
	typeset lofi_dev_name mount_point
	typeset lofi_dev
	typeset ufs_finish_arg zfs_finish_arg
	typeset cmd

	if [[ $file_system_param == "ufs" || $file_system_param = "hsfs" ]]
	then
		mount_point="/mnt"
	fi

	# For ufs and zfs filesystems creating the lofi file, creating the
	# filesystem, and populating it are all separate steps.
	if [[ $file_system_param == "ufs" || $file_system_param = "zfs" ]]
	then
		# Create the file
		make_and_verify_file $file_size_param $lofi_file
		if (( $? != 0 )); then
			# File creation failed.
			return 1
		fi

		# Add lofi device based on just-created file.
		# $desired_lofi_dev may or may not be set, so
		# add_lofi_device() may return a lofi dev name to us.
		lofi_dev=`add_lofi_device $lofi_file $desired_lofi_dev`
		if (( $? != 0 )); then
			# Addition of lofi device failed
			lofi_and_fs_tidy_up -f $lofi_file
			return 1
		fi

		# If we specified a desired lofi dev name, then
		# add_lofi_device() will not have output a lofi dev name.
		if [[ -n "$desired_lofi_dev" ]]; then
			lofi_dev="$desired_lofi_dev"
		fi

		# Create filesystem
		if [[ $file_system_param == "ufs" ]]; then
			create_ufs -f $lofi_file -l $lofi_dev
			fs_creation_status=$?
		else
               		create_zfs -f $lofi_file -z $zpool_name -l $lofi_dev
			fs_creation_status=$?
		fi

		if (( $fs_creation_status != 0 )); then
			# Filesystem creation failed
			lofi_and_fs_tidy_up -f $lofi_file
			return 1
		fi

		# Take care of filesystem mounting
		typeset mount_status=0
		if [[ $file_system_param = "ufs" ]]; then
			# ufs filesystem must be mounted after
			# creation.
			cmd="mount -F $file_system_param $lofi_dev"
			cmd="$cmd $mount_point"
			record_cmd_execution "$cmd"
			cti_execute "FAIL" "$cmd"
			if (( $? != 0 )); then
				lofi_and_fs_tidy_up \
				    -f $lofi_file -m $mount_point
				return 1
			fi
			ufs_finish_arg="-m $mount_point"
		else
			# ZFS filesystem should have been mounted at
			# creation time.
			zfs_finish_arg="-z $zpool_name"
			mount_point="/${zpool_name}"
			grep "$mount_point" /etc/mnttab >/dev/null
			if (( $? != 0 )); then
				cti_fail "ZFS file system $zpool_name not" \
					    "mounted at creation time"
				lofi_and_fs_tidy_up \
				    -f $lofi_file $zfs_finish_arg
				return 1
			fi
		fi

		# 'cd' to the top directory of the reference tree
		typeset mypwd=`pwd`
		cmd="cd $src_dir"
		record_cmd_execution "$cmd"
		$cmd

		# Use cpio to copy the reference tree to the target
		# filesystem.  We won't use cti_execute to execute this as
		# is will create cti_stdout and cti_stderr files in the
		# reference tree as that is our current working directory.
		# This means we'll have to manage command output ourselves.
		#
		# Command with a pipe ("|") in it won't execute correctly
		# if we try to execute it out of a variable, so have to
		# explicitly write out the command twice (once to log it
		# in the execution record, once to execute it).
		record_cmd_execution "find . -print | cpio -pdm $mount_point"
		find . -print | cpio -pdm $mount_point >/dev/null \
		    2>${TMPDIR}/$$_cpio_stderr
		typeset populate_status=$?

		# 'cd' back to our original location before doing anything
		# else.
		cmd="cd $mypwd"
		record_cmd_execution "$cmd"
		$cmd

		# Abort if populating the filesystem failed
		if (( $populate_status != 0 )); then
			cti_report "Populating $file_system_param file" \
			    "system failed.  stderr for find/cpio:"
			cti_reportfile ${TMPDIR}/$$_cpio_stderr
			$RM -f ${TMPDIR}/$$_cpio_stderr 2>/dev/null
			lofi_and_fs_tidy_up -f $lofi_file \
			    $ufs_finish_arg $zfs_finish_arg
			return 1
		fi
		$RM -f ${TMPDIR}/$$_cpio_stderr 2>/dev/null

		if [[ -n "$VERBOSE" ]]; then
			cti_report "Populating of $file_system_param file" \
			    "system completed"
		fi

		lofi_and_fs_tidy_up -f $lofi_file $ufs_finish_arg \
		    $zfs_finish_arg
		if (( $? != 0 )); then
			return 1
		fi

		if [[ -n "$VERBOSE" ]]; then
			cti_report "Unmounted the $file_system_param" \
			    "filesystem and deleted lofi device"
		fi

	elif [[ $file_system_param == "hsfs" ]]; then
		# For an hsfs filesystem, creation of the file and population
		# by the file system all happen at once.
		create_isofs $lofi_file $src_dir
		if (( $? != 0 )); then
			lofi_and_fs_tidy_up -f $lofi_file
			return 1
		fi
	fi

	return 0
}


#
# NAME:
#	verify_populated_fs_in_file
#
# SYNOPSIS:
#	verify_populated_fs_in_file -f <fs type> -l <lofi file> -s <src dir> \
#	    [-c] [-z <zpool name>]
#
# DESCRIPTION:
#	Verify the filesystem contents of the specified lofi file against
#	the original source.  At this time the verification is restricted
#	to file/directory names and permissions, as the files were created
#	via 'mkfile' [by build_reference_tree()] and so don't actually
#	have contents for us to verify.
#
# RETURN CODES:
#	0	Contents of filesystem on lofi device verified
#	1	Filesystem on lofi device inaccessible or doesn't match source
#
function verify_populated_fs_in_file {
	typeset lofi_file file_system_param compression zpool_name
	typeset status=0

	# Process function arguments
	typeset option
	while getopts cf:l:s:z: option
	do
		case $option in
			c)	compression="yes";;
			f)	file_system_param="$OPTARG";;
			l)	lofi_file="$OPTARG";;
			s)	src_dir="$OPTARG";;
			z)	zpool_name="$OPTARG";;
		esac
	done

	# Add lofi device based on the file.
	lofi_dev=`add_lofi_device $lofi_file`
	if (( $? != 0 )); then
		# Addition of lofi device failed
		lofi_and_fs_tidy_up -f $lofi_file
		return 1
	fi

	# Verify that the correct file system type is reported.
	cmd="$FSTYP $lofi_dev"
	record_cmd_execution "$cmd"
	cti_execute "FAIL" "$cmd"
	typeset fs_type=`cat cti_stdout`
	if [[ "$fs_type" != "$file_system_param" ]]; then
		cti_fail "$FSTYP for $lofi_dev returns type '$fs_type';" \
		    "expected '$file_system_param'"
		lofi_and_fs_tidy_up -f $lofi_file
		return 1
	fi

	if [[ -n "$compression" && $file_system_param = "zfs" ]]; then
		# With a compressed zfs zpool, the only check we can make is
		# executing fstyp above to verify that the on-the-fly
		# decompression allows the file system type to be determined.
		# We can't import or otherwise use the zpool so we'll return
		# now.
		lofi_and_fs_tidy_up -f $lofi_file
		return 0
	fi

	# Need to specify mount point for ufs or hsfs; zfs fs has mount
	# point defined in itself.
	if [[ $file_system_param == "ufs" || $file_system_param = "hsfs" ]]
	then
		mount_point="/mnt"
	fi

	# If the file is compressed and contains a UFS filesystem, first try
	# mounting it read/write.  This should fail.
	if [[ -n "$compression" && "$file_system_param" = "ufs" ]]; then
		cti_report "Attempt mounting compressed UFS filesystem" \
		    "read/write.  This is expected to fail."
		cmd="mount -F ufs $lofi_dev $mount_point"
		record_cmd_execution "$cmd"
		cti_execute "PASS" "$cmd"
		if (( $? == 0 )); then
			cti_fail "Mounting of compressed ufs filesystem at" \
			    "$lofi/dev/ with read/write permissions" \
			    "succeeded when it was expected to fail."
			lofi_and_fs_tidy_up -f $lofi_file \
			    -m $mount_point
			cmd="mount -F ufs $lofi_dev $mount_point"
			record_cmd_execution "$cmd"
			cti_execute "PASS" "$cmd"
			if (( $? == 0 )); then
				return 1
			fi
			status=1
		fi

		if [[ -n "$VERBOSE" ]]; then
			cti_report "Attempted mounting of compressed ufs" \
			    "filesystem with read/write permissions failed" \
			    "as expected."
		fi
	fi

	typeset hufs_finish_arg zfs_finish_arg
	if [[ "$file_system_param" = "ufs" || "$file_system_param" = "hsfs" ]]
	then
		# Set mount options to read-only if file is compressed.
		typeset mopts
		if [[ -n "$compression" ]]; then
			mopts="-o ro"
		fi

		# Mount the FS.
		cmd="mount -F $file_system_param $mopts $lofi_dev $mount_point"
		record_cmd_execution "$cmd"
		cti_execute "PASS" "$cmd"
		if (( $? != 0 )); then
			if [[ -n "$compression" ]]; then
				cti_fail "Mounting of compressed" \
				    "$file_system_param filesystem at" \
				    "$lofi_dev with read-only option failed" \
				    "when it was expected to pass"
			else
				cti_fail "Mounting of $file_system_param" \
				    "filesystem with default options failed" \
				    "when it was expected to pass"
			fi
			lofi_and_fs_tidy_up -f $lofi_file \
			    -m $mount_point
			return 1
		fi
		hufs_finish_arg="-m $mount_point"
	elif [[ "$file_system_param" = "zfs" ]]; then
		mount_point="/${zpool_name}"
		import_zfs $lofi_dev $zpool_name
		if (( $? != 0 )); then
			lofi_and_fs_tidy_up -f $lofi_file
			return
		fi

		zfs_finish_arg="-z $zpool_name"
	fi

	# Validate the contents of the file system on the lofi device
	# associated with the decompressed file.
	validate_test_fs $mount_point $src_dir $file_system_param
	if (( $? == 0 )); then
		if [[ -n "$VERBOSE" ]]; then
			cti_report "Validation of $file_system_param" \
			    "filesystem succeeded"
		fi
	else
		if [[ -n "$VERBOSE" ]]; then
			cti_report "Validation of $file_system_param" \
			    "filesystem failed"
		fi
		status=1
	fi

	# Unmount the filesystem and dissasociate the lofi device from it.
	lofi_and_fs_tidy_up -f $lofi_file $hufs_finish_arg $zfs_finish_arg
	if (( $? != 0 )); then
		return 1
	fi

	return $status
}
