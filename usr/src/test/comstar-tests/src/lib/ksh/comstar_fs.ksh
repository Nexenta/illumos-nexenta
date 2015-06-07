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

DEV_ZVOL=/dev/zvol/rdsk
RDEV_ZVOL=/dev/zvol/rdsk
BDSK=/dev/dsk
RDSK=/dev/rdsk
MP=$LOGDIR/mp

# NAME
#       fs_zpool_create
#
# DESCRIPTION
#       create a zfs pool on the given device 
#
# ARGUMENT
#       user specified options of zpool creation
#
# RETURN
#	0 - creation pass.
#	1 - creation fail.
#
function fs_zpool_create
{
	CMD="$ZPOOL create $*"
	run_ksh_cmd "$CMD"
	fs_report "$CMD"
	return $?
}
#
# NAME
#       fs_zfs_create
#
# DESCRIPTION
#       create a zfs file system 
#
# ARGUMENT
#       user specified options of zfs creation 
#
# RETURN
#	0 - creation pass.
#	1 - creation fail.
#
function fs_zfs_create
{
	CMD="$ZFS create $*"
	run_ksh_cmd "$CMD"
	fs_report "$CMD"
	return $?
}

#
# NAME
#	fs_zfs_set_mp
#
# DESCRIPTION
#	set the mountpoint for the zfs filesystem to the given mountpoint
#	and echo the return code from zfs set.
#
# ARGUMENT
#	$1 - mount point
#	$2 - mounted point
#
# RETURN
#	0 - creation pass.
#	1 - creation fail.
#
function fs_zfs_set_mp
{
	CMD="$ZFS set mountpoint=$1 $2"
	run_ksh_cmd "$CMD"
	fs_report "$CMD"
	return $?
}

#
# NAME
#	fs_create_smi_label
#
# DESCRIPTION
#	Create a generic SMI label on the device
#
# ARGUMENT
#	$1 - host name
#	$2 - device pathname of raw disk device 
#	$3 - device type of raw disk device 
# RETURN
#	0 - generic SMI label successfully created.
#	1 - generic SMI label creation failed.
#
function fs_create_smi_label
{
	typeset HOSTNAME=$1
	typeset RDEV=$2
	typeset type=$3

	cti_report "INFO - Writing the VTOC label to $RDEV on host $HOSTNAME"
	
	typeset cmd="uname -p"
	run_rsh_cmd $HOSTNAME "$cmd"
	ARCH=`get_cmd_stdout`
	case $ARCH in
		"i386") 
			cmd="$FDISK -B `echo $RDEV | sed -e 's/s2/p0/'`"
			run_rsh_cmd $HOSTNAME "$cmd"
			cmd="$FMTHARD -s /dev/null $RDEV"
			run_rsh_cmd $HOSTNAME "$cmd"
			rc=`get_cmd_retval`
		;;
		"sparc") 
			case $type in
					10) 
					cmd="echo label > /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
					cmd="echo 0 >> /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
					cmd="echo y >> /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
					cmd="echo q >> /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
				;;
					11) 
					cmd="echo label > /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
					cmd="echo 0 >> /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
					cmd="echo q >> /tmp/fmt_cmds.$$"
					run_rsh_cmd $HOSTNAME "$cmd"
				;;
					1)  
					cmd="$FMTHARD -s /dev/null $RDEV"
					run_rsh_cmd $HOSTNAME "$cmd"
					return 0
				;;
					*)  cti_report "Unknown disk"
					return 1
				;;
			esac

			cti_report "$FORMAT -f /tmp/fmt_cmds.$$ -e "\
				"`echo $RDEV | sed -e 's/\/dev\/rdsk\///'`"
			cmd="$FORMAT -f /tmp/fmt_cmds.$$ -e"
			cmd="$cmd `echo $RDEV | sed -e 's/\/dev\/rdsk\///'`"
			run_rsh_cmd $HOSTNAME "$cmd"
			rc=`get_cmd_retval`
		;;
		*)      
			cti_report "fs_create_smi_label : Unknown architecture"
			rc=1
		;;
	esac
	
	cti_report "End to format $RDEV with VTOC label"

	cmd="rm -f /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	return $rc
}

#
# NAME
#	fs_create_efi_label
#
# DESCRIPTION
#	Create a generic EFI label on the device
#
# ARGUMENT
#	$1 - host name
#	$2 - device pathname of raw disk device 
#	$3 - device type of raw disk device 
#
# RETURN
#	0 - generic EFI label successfully created.
#	1 - generic EFI label creation failed.
#
function fs_create_efi_label
{
	typeset HOSTNAME=$1
	typeset RDEV=$2
	typeset type=$3
	
	cti_report "INFO - Writing the EFI label to $RDEV on host $HOSTNAME"
	
	cmd="echo label > /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	cmd="echo 1 >> /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	cmd="echo y >> /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	cmd="echo q >> /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	cmd="$FORMAT -f /tmp/fmt_cmds.$$"
	cmd="$cmd -e `echo $RDEV | sed -e 's/\/dev\/rdsk\///'`"
	run_rsh_cmd $HOSTNAME "$cmd"
	rc=`get_cmd_retval`
	cmd="rm -f /tmp/fmt_cmds.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	return $rc
}

#
# NAME
#	fs_verify_label
#
# DESCRIPTION
#	Verify that the label is a generic SMI label with slice 2
#	representing the entire disk.
#
# RETURN
#	0 - label is a generic SMI label
#	1 - label is not a generic SMI label and could not be
#		converted to a generic SMI label
#
function fs_verify_label
{
	typeset HOSTNAME=$1
	typeset RDEV=$2
	typeset rc=0

	cti_report "INFO - Verify the label of $RDEV on host $HOSTNAME"
	typeset cmd="$PRTVTOC $RDEV > /tmp/prtvtoc_comstar.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	typeset rt=`get_cmd_retval`
	rc=`expr $rc + $rt`

	cmd="$GREP \"accessible cylinders\" /tmp/prtvtoc_comstar.$$"
	cmd="$cmd | awk '{print \$2}'"
	run_rsh_cmd $HOSTNAME "$cmd"
	typeset acccyl=`get_cmd_stdout`
	if [ -n "$acccyl" ]; then
		cmd="$GREP  \"sectors/cylinder\" /tmp/prtvtoc_comstar.$$"
		cmd="$cmd | $AWK '{print \$2}'"
		run_rsh_cmd $HOSTNAME "$cmd"		
		secpcyl=`get_cmd_stdout`
		typeset totsec=`expr $secpcyl \* $acccyl`
		if [ $totsec -lt 1024000 ]; then
			cti_report "Device is too small for testing. "\
				"Device must be at least 1gb in size."
		fi
		cmd="$GREP -v \"^\\*\" /tmp/prtvtoc_comstar.$$ |"
		cmd="$cmd grep \"^       2\" | $AWK '{print \$1, \$4, \$5}'"
		run_rsh_cmd $HOSTNAME "$cmd"
		set -A slice2 `get_cmd_stdout`

		if [ -n "${slice2[0]}" ]; then
			if [ ${slice2[0]} -ne 2 -o ${slice2[1]} -ne 0 \
				-o ${slice2[2]} -ne $totsec ]; then
				rc=`expr $rc + 1`
			fi
		else
			rc=`expr $rc + 1`
		fi
	else
		rc=`expr $rc + 10`;
	fi
	if [ $rc -ne 0 ]; then
		fs_create_smi_label $HOSTNAME $RDEV $rc
		rc=$?
	fi
	cmd="rm -f /tmp/prtvtoc_comstar.$$"
	run_rsh_cmd $HOSTNAME "$cmd"
	if [ $rc -ne 0 ];then
		cti_fail "FAIL - Unable to get a viable generic label on $RDEV"
	fi
	return $rc
}

#
# NAME
#	build_fs
#
# DESCRIPTION
# 	Build the filesystems and mount filesystems according to 
# 	configuration parameters.
#	- Create all the directories that are needed.
#	- Check the devices are not in use
#	- Create the needed filesystems (ufs and/or zfs)
#	- Mount the filesystems
#
# RETURN
#	0 - if the filesystems were built successfully
#	1 - if the filesystems were not built successfully
#
function build_fs
{
	typeset FSTYPE=$1
	typeset ret_code=0

	case "$FSTYPE" in 
	"ufs") 
		
		CMD="test -d $MP & $RM -rf $MP"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"
		(( ret_code+=$? ))
		CMD="test -d $MP | $MKDIR -p $MP"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"
		(( ret_code+=$? ))
		set -A bdevs $BDEVS
		CMD="echo y | $NEWFS ${bdevs[0]}"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"		
		(( ret_code+=$? ))
		CMD="$MOUNT ${bdevs[0]} $MP"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"
		(( ret_code+=$? ))
	;;
	"zfs")
		if [ ! -d $MP ]; then
			mkdir -p $MP
		fi
		set -A bdevs $BDEVS

		fs_zpool_create -f $ZP ${bdevs[0]}
		(( ret_code+=$? ))
		zfs_mp=`basename $MP`
		fs_zfs_create ${ZP}/${zfs_mp}
		(( ret_code+=$? ))
		fs_zfs_set_mp $MP ${ZP}/${zfs_mp}
		(( ret_code+=$? ))
	;;
	"zdsk")
		typeset disk_num=`echo $BDEVS | awk '{print NF}'`
		if [  $disk_num -gt 1 ];then
			fs_zpool_create -f $ZP "raidz2 $BDEVS"
		elif [ $disk_num -eq 1 ];then
			fs_zpool_create -f $ZP $BDEVS
		else
			cti_report "BDEVS is configured with none of disks."
			(( ret_code+=1 ))
		fi
		(( ret_code+=$? ))
	;;
	"zrdsk")
		typeset disk_num=`echo $RDEVS | awk '{print NF}'`
		if [  $disk_num -gt 1 ];then
			fs_zpool_create -f $ZP "raidz2 $RDEVS"
		elif [ $disk_num -eq 1 ];then
			fs_zpool_create -f $ZP $RDEVS
		else
			cti_report "RDEVS is configured with none of disks."
			(( ret_code+=1 ))
		fi
		(( ret_code+=$? ))
	;;
	*)	
		cti_report "Unknown configuration."		
		(( ret_code+=1 ))
	;;
	esac
	if [ $ret_code -ne 0 ];then
		cti_fail "FAIL - Build file system for base directory error"
		return 1
	else
		return 0
	fi
}

#
# NAME
#	clean_fs
#
# DESCRIPTION
#	clean the filesystems that were created for the tests by
#	unmounting and tearing down the zfs filesystems and pools
#	that were created.
#
# RETURN
#	0 - if the filesystems were successfully cleaned up
#	1 - if the filesystems were not successfully cleaned up
#	
#
function clean_fs
{
	typeset FSTYPE=$1
	typeset ret_code=0

	if [ "$FSTYPE" = "zdsk" -o "$FSTYPE" = "zrdsk" ]; then
		CMD="$UMOUNT /${ZP}"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"		
		(( ret_code+=$? ))
	else
		#
		# umount all the filesystem
		#
		cf_mp=`$DF $MP 2>/dev/null | $AWK '{ print $1 }' | \
			$AWK -F"(" '{print $1}'`
		if [ "$cf_mp" = "$MP" ]; then
			CMD="$UMOUNT $MP"
			run_ksh_cmd "$CMD"
			fs_report "$CMD"
			if [ `get_cmd_retval` -ne 0 ]; then
				CMD="$UMOUNT -f $MP"
				run_ksh_cmd "$CMD"
				if [ `get_cmd_retval` -ne 0 ]; then
					(( ret_code+=1 ))
					cti_report  "forced umount $MP failed"
				fi
				cti_report "Force umount of $MP"
			fi
		fi

		if [ -d $MP ]; then
			$RM -rf $MP > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				$UMOUNT -f $MP  > /dev/null 2>&1
				$RM -rf $MP > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					(( ret_code+=1 ))
					cti_report "Unable to remove $MP"
				fi
			fi
		fi
	fi
	
	if [ "$FSTYPE" = "zdsk" \
		-o "$FSTYPE" = "zrdsk" \
		-o "$FSTYPE" = "zfs" ]; then
		CMD="$ZPOOL list $ZP"
		run_ksh_cmd "$CMD"
		fs_report "$CMD"
		if [ `get_cmd_retval` -eq 0 ]; then
			CMD="$ZPOOL destroy -f $ZP"
			run_ksh_cmd "$CMD"
			fs_report "$CMD"
			(( ret_code+=$? ))
		else
			cti_report "$ZP pool does not exist"
		fi
	fi
	if [ $ret_code -ne 0 ];then
		cti_fail "FAIL - clean up file system for base directory error"
		return 1
	else
		return 0
	fi
	
}


#
# NAME
#       fs_report
#
# DESCRIPTION
#       provide the formatted to print information 
#	when unexpected result returns
#
# RETURN
#	0 - creation pass.
#	1 - creation fail.
#
function fs_report
{
	typeset fs_cmd="$*"
	if [ `get_cmd_retval` -ne 0 ] ; then
		report_err "$fs_cmd"
		return 1
	else
		cti_report "$fs_cmd passed."
		return 0
	fi
}

