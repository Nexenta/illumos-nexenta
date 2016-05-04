#! /usr/bin/ksh -p
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
# operate_dir <share|unshare> <directroy> [options]
#

ZFS=/usr/sbin/zfs

#
# Check if the specified directory is ZFS filesystem mountpoint
#
# $1 Directory
#
function is_zfs_mntpnt
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	typeset dir=$1
	[[ -z $dir ]] && return 1

	typeset mntpnt=$($ZFS list -H -o mountpoint)
	mntpnt=$(echo $mntpnt | tr -s "\n" " ")
	if [[ " $mntpnt " == *" $dir "* ]]; then
		return 0
	fi

	return 1
}

#
# According to mountpoint get the ZFS filesystem name.
#
# $1 Directory
#
function getfs_by_mntpnt
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	typeset dir=$1

	typeset fs=$($ZFS list -H -o name,mountpoint | \
		grep "${dir}$" | awk '{print $1}')
	echo $fs
}

#
# According to env variable to share the specified direcotry
#
# $1 Directory
# $2 Optinal for share
#
function share_dir
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	typeset dir=$1
	typeset opt=${2:-"rw"}

	typeset -i ret=0
	typeset tmpfile=/tmp/share_dir.err.$$

	if (( RANDOM % 2 == 0)) && is_zfs_mntpnt $dir ; then
	       	typeset fs=$(getfs_by_mntpnt $dir)
		echo "# $ZFS set sharenfs=$opt $fs" > $tmpfile 
		$ZFS set sharenfs="$opt" $fs >> $tmpfile 2>&1 
		ret=$?

		typeset sharedir=$(share | awk '{print $2}' | grep -w "$dir")
		sharedir=$(echo $sharedir | tr -s "\n" " ")
		if [[ " $sharedir " != *" $dir "* ]] && (( ret == 0 )) ; then
			echo "# $ZFS share $fs" >> $tmpfile 
			$ZFS share $fs >> $tmpfile 2>&1
			((ret |= $?))
		fi

		#
		# Print shared information for logging in journal file.
		#
		if (( ret == 0 )); then
			echo "SHARE: $this 'zfs share' $opt $dir"
		else
			echo "WARNING: $this 'zfs share' $opt $dir, failed"
			sed 's/^/WARNING: /' $tmpfile 2>&1 
		fi
	else
		# share with "-p" option, so that it is persistent when the \
		# smf service is refreshed by "sharectl set" in some subdirs
		echo "# share -F nfs -p -o $opt $dir" > $tmpfile
		share -F nfs -p -o $opt $dir >> $tmpfile 2>&1
		ret=$?
		if (( ret == 0 )); then
			echo "SHARE: $this 'share' $opt $dir"
		else
			echo "ERROR: $this 'share' $opt $dir, failed"
			sed 's/^/ERROR: /' $tmpfile 2>&1 
		fi
	fi

	rm -f $tmpfile
	return $ret
}

#
# According to env variable to unshare the directory
#
# $1 Directory
#
function unshare_dir
{
	[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

	typeset dir=$1
	[[ -z $dir ]] && return 1

	typeset fs=$(getfs_by_mntpnt $dir)
	typeset share_status=$($ZFS get -H -o value sharenfs $fs)
	typeset -i ret=0
	if [[ $share_status != "off" ]] && is_zfs_mntpnt $dir ; then
		$ZFS set sharenfs=off $fs
		ret=$?
	else
		unshare -p $dir
		ret=$?
	fi

	return $ret
}

#######################  FUNCTIONS END HERE  ##########################

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

this=$(basename $0)
operate=$1
dir=$2
opt=${3:-"rw"}
if [[ -z $operate || -z $dir ]] ; then
	echo "Usage: $this <share|unshare> <directroy> [options]"
	exit 1
fi

case $operate in
	share) 
		share_dir $dir $opt
		exit $?
		;;
	unshare) 
		unshare_dir $dir 
		exit $?
		;;
	*) 
		echo "Usage: $this <share|unshare> <directroy> [options]"
		exit 1
		;;
esac
