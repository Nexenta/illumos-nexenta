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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# The program to saturate a filesystem with disk/inodes

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
DIR=$(dirname $0)

Usage="Usage: $0 fs-to-saturate\n"

if (( $# < 1 )); then
	echo $Usage
	exit 99
fi

fs=$1
mntpt=$(zfs list -H $fs | awk '{print $NF}')
if [[ $mntpt == $1 && $? == 0 ]]; then
	fs=$(zfs list -H $fs | awk '{print $1}')
	[[ $? != 0 ]] && echo "ERROR: Can not get zfs name" && exit 1
	TestZFS=1
else
	TestZFS=0
fi

SDIR=${1}/sat_dir
[[ ! -d $SDIR ]] && mkdir -m 0777 $SDIR

integer Inodes i=0 j=0 Disks=0 Bigf=0 kbleft=0

# create a zero byte file in the directory
rm -f $SDIR/zerobyte.file
> $SDIR/zerobyte.file

if [[ $TestZFS == 0 ]]; then
	# UFS
	# First fill up inodes first
	Inodes=$(df -e $SDIR | tail -1 | awk '{print $2}')
	while (( i <= Inodes )); do
		cp $SDIR/zerobyte.file $SDIR/Newfile.$i
		ls $SDIR/Newfile.$i > /dev/null 2>&1
		[[ $? == 0 ]] && let i+=1 || break
	done

	# Now fillup the disk.
	# first fill with MB ...
	i=1
	Disks=$(df -b $SDIR | tail -1 | awk '{print $2}')
	let Bigf=Disks/1024
	rm $SDIR/Newfile.$i
	(( Bigf > 0 )) && mkfile ${Bigf}m $SDIR/Newfile.$i || touch $SDIR/Newfile.$i
	# then fill the KB ...
	let kbleft=Disks%1024-1
	let i+=1
	rm $SDIR/Newfile.$i
	mkfile ${kbleft}k $SDIR/Newfile.$i
	# finally fill the Byte ... (at most 1023B)
	while (( j < 1023 )); do
		echo "A\c" >> $SDIR/Newfile.$i
		[[ $? != 0 ]] && break
		let j+=1
	done
else
	# ZFS
	Disks=$(zfs get -pHo value available $fs)
	if [[ $? != 0 ]]; then
		echo "ERROR: Can not get zfs size"
		exit 1
	fi
	mkfile ${Disks}b $SDIR/Newfile
fi

exit 0
