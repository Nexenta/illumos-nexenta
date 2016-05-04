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

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

#
# ------------------
# Function: stat_dir
# ------------------
# This function gets the filesystem type and name of a directory and print out
#
# Usage: #   stat_dir <dir>
# e.g.   stat_dir /              # print "ufs /dev/dsk/c0t1d0s0"
# e.g.   stat_dir /tmp/foo1/foo2 # print "tmpfs swap"
# e.g.   stat_dir /export/foo    # print "zfs rpool/export"
# e.g.   stat_dir /upool/xxxx    # print "zfs upool"
#
# Return: 
#   always return 0 unless dir is null string
#
function stat_dir {
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

	typeset dir=$1
	[[ -z $dir ]] && return 1
	typeset basepath=$dir
	typeset strout=""

	#
	# get base path of dir which does not exist
	#
	if [[ ! -d $dir ]]; then
		typeset pdir=""              # dir begins with  a relative path
		[[ $dir == /* ]] && pdir="/" # dir begins with an absolute path
		typeset d=""
		for d in $(echo $dir | sed 's%/% %g'); do
			if [[ -z $pdir ]]; then
				pdir=$d
			else
				[[ $pdir == "/" ]] && pdir=/$d || pdir=$pdir/$d
			fi

			if [[ ! -d $pdir ]]; then
				basepath=$(dirname $pdir)
				break
			fi
		done
	fi

	#
	# get filesystem type: ufs, zfs, tmpfs, ...
	#
	typeset fs_type=$(/usr/bin/stat -f -c "%T" $basepath)
	strout=$fs_type

	#
	# get filesystem name
	# e.g.
	# +---------+---------+-------------------+
	# | dir     | fs_type | fs_name           |
	# +---------+---------+-------------------+
	# | /root   | ufs     | /dev/dsk/c0t4d0s0 |
	# | /tmp    | tmpfs   | swap              |
	# | /export | zfs     | rpool/export      |
	# | /proc   | proc    | proc              |
	# +---------+---------+-------------------+
	#
	typeset fs_name=$(/usr/sbin/df $basepath | awk -F\( '{print $2}' \
				| awk -F\) '{print $1}')
	strout=$strout" "$fs_name

	echo $strout
	return 0
}

# 
# Function: get_zpool_name
#   get the zpool name of a zfs filesystem and print out
# Usage:
#   get_zpool_name <fs name>
# Return:
#   always return 0 unless fs name is null string
# 
function get_zpool_name {
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

	typeset fs_name=$1
	[[ -z $fs_name ]] && return 1
	typeset zpool_name=$(echo $fs_name | awk -F\/ '{print $1}')

	echo $zpool_name
	return 0
}

# 
# Function: get_zpool_stat
#   get the status of a zpool and print out
# Usage:
#   get_zpool_stat <zpool name>
# Return:
#   return 0 if successful
# 
function get_zpool_stat {
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

	typeset zpool_name=$1
	[[ -z $zpool_name ]] && return 1

	typeset zpool_stat=""
	typeset f1=/tmp/get_zpool_stat.out.$$
	typeset f2=/tmp/get_zpool_stat.err.$$

	/usr/sbin/zpool list -H -o health $zpool_name > $f1 2>$f2
	typeset -i rc=$?
	(( rc == 0 )) && zpool_stat=$(cat $f1) || zpool_stat=$(cat $f2)
	echo $zpool_stat
	rm -f $f1 $f2
	return $rc
}

function usage {
	typeset prog=$1
	echo "This file is to check what type of filesystem of a directory,"
	echo "then print related information out as such format,"
	echo "<FAIL|OKAY> <fs type> <fs name | <zpool name> [zpool stat]>"
	echo "and exit 0 if OKAY or exit 1 if FAIL."
	echo
	echo "Usage: $prog <directory name>"
	echo "e.g.   $prog /export/foo   # print OKAY zfs rpool ONLINE"
	echo "e.g.   $prog /ufsdisk/d1   # print OKAY ufs /dev/dsk/c0t1d0s3"
	echo "e.g.   $prog /tmp/dirxxx   # print OKAY tmpfs swap"
	echo "e.g.   $prog /proc/12345   # print OKAY proc proc"
	echo "e.g.   $prog /home         # print OKAY autofs auto.home"
	echo "e.g.   $prog /ws/onnv-gate \c"
	echo "# print OKAY nfs onnv.sfbay:/export/onnv-gate"
	echo 
	exit 1
}

[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
CDIR=$(dirname $0)

[[ $# != 1 ]] && usage $NAME
dir=$1

fs_info=$(stat_dir $dir)
fs_type=$(echo $fs_info | awk '{print $1}')
fs_name=$(echo $fs_info | awk '{print $2}')
strout=""
if [[ $fs_type == "ufs" ]]; then
	strout="$fs_type $fs_name"
elif [[ $fs_type == "zfs" ]]; then
	strout=$fs_type

	zpool_name=$(get_zpool_name $fs_name)
	if (( $? != 0 )); then
		echo "FAIL $strout \n$zpool_name"
		exit 1 
	fi
	strout="$strout $zpool_name"

	zpool_stat=$(get_zpool_stat $zpool_name)
	if (( $? != 0 )); then
		echo "FAIL $strout \n$zpool_stat"
		exit 1 
	fi
	strout="$strout $zpool_stat"
else
	strout="$fs_type $fs_name"
fi

echo OKAY $strout
exit 0
