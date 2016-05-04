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
# The program to setup LOFI filesystem for testing.
# It must be run as root.
#

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
DIR=$(dirname $0)

id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
        echo "Must be root to run this test."
        exit 99
fi

Usage="Usage: $0 -s|-c FS_name [fs_size]\n
\t-s: to setup the LOFI or ZFS test filesystem\n
\t-c: to cleanup the LOFI or ZFS test filesystem\n
\tFS_name: new filesystem name, e.g. NFSv4_fs1 to mount the LOFI or ZFS;\n
\tfs_size: new filesystem size, must be in format of #m;\n
\t\tand it's optional, default is 5m (5MB).\n
"

if (( $# < 2 )); then
        echo $Usage
        exit 99
fi
OP=$(echo $1 | sed 's/-//')
FSNAME=$2
FSIZE=5m
UFSOPT="rw"
if (( $# > 2 )); then
        FSIZE=$3	# must be in the format of 5m/8m
	[[ -n $4 ]] && UFSOPT=$4
fi

function cleanup		# remove temp files and exit
{
        rm -fr $TMPDIR/*.out.$$
        exit $1
}

PATH=/usr/sbin:/usr/bin:$PATH; export PATH
SRVTESTDIR=${SRVTESTDIR:-"/export"}
TMPDIR=${TMPDIR:-"/usr/tmp"}
FNAME=LOFI_file.$$


case $OP in
  s) 		# Setup the LOFI filesystem 
	echo "Setting up a LOFI/FS using [$SRVTESTDIR/$FNAME] file..."
	# use LOFI to create a filesystem under:
	if [[ ! -d $SRVTESTDIR ]]; then
        	echo "$NAME: SRVTESTDIR=[$SRVTESTDIR] not found."
        	cleanup 88
	fi
	rm -f $SRVTESTDIR/$FNAME
	mkfile $FSIZE $SRVTESTDIR/$FNAME > $TMPDIR/mkfile.out.$$ 2>&1
	if (( $? != 0 )); then
        	echo "$NAME: mkfile $FSIZE failed:"
        	cat $TMPDIR/mkfile.out.$$
        	cleanup 88
	fi
	lofiadm -a $SRVTESTDIR/$FNAME > $TMPDIR/lofi-a.out.$$ 2>&1
	if (( $? != 0 )); then
	        echo "$NAME: lofiadm -a failed:"
	        cat $TMPDIR/lofi-a.out.$$
	        cleanup 88
	fi
	# build the UFS filesystem (with less inode if NoSPC):
	LDEV=$(head -1 $TMPDIR/lofi-a.out.$$ | awk '{print $1}')
	echo $FSNAME | grep "NoSPC" > /dev/null 2>&1
	if (( $? == 0 )); then
		echo "y" | newfs -i 10240 $LDEV > $TMPDIR/newfs.out.$$ 2>&1
	else
		echo "y" | newfs $LDEV > $TMPDIR/newfs.out.$$ 2>&1
	fi
	if (( $? != 0 )); then
	        echo "$NAME: newfs $LDEV failed:"
	        cat $TMPDIR/newfs.out.$$
	        cleanup 88
	fi
	# Mount the device
	[[ ! -d $FSNAME ]] && mkdir -p $FSNAME
	if [[ $UFSOPT == noxattr ]]; then
	    mount -F tmpfs -o$UFSOPT $LDEV $FSNAME > $TMPDIR/mnt.out.$$ 2>&1
	else
	    mount -F ufs -orw $LDEV $FSNAME > $TMPDIR/mnt.out.$$ 2>&1
	fi
	if (( $? != 0 )); then
	        echo "$NAME: mount -orw $LDEV failed:"
	        cat $TMPDIR/mnt.out.$$
	        cleanup 88
	fi
	chmod 0777 $FSNAME
	# save lofi-file name for cleanup
	echo "$SRVTESTDIR/$FNAME" > $FSNAME/..LOFI_file
	echo "$LDEV" > $FSNAME/..LOFI_file.dev
	
	echo "New Filesystem [$FSNAME] has been created successfully."
	cleanup 0
	;;

  c) 		# Cleanup the LOFI filesystem 
	# First retrieve the LOFI device and LOFI file names
	FNAME=$(cat $FSNAME/..LOFI_file)
	LDEV=$(cat $FSNAME/..LOFI_file.dev)
	mount -p | grep "$FSNAME" | grep tmpfs > /dev/null 2>&1
	if (( $? == 0 )); then
		umount $FSNAME > $TMPDIR/umnt.out.$$ 2>&1
	else
		umount -f $FSNAME > $TMPDIR/umnt.out.$$ 2>&1
	fi
        if (( $? != 0 )); then
                echo "$NAME: umount [$FSNAME] failed:"
                cat $TMPDIR/umnt.out.$$
                echo "\t please manually cleanup the LOFI-FS [$FSNAME]."
                cleanup 99
        fi
	lofiadm -d $LDEV > $TMPDIR/lofi-d.out.$$ 2>&1
	if (( $? != 0 )); then
        	echo "$NAME: lofiadm -d $LDEV failed."
        	cat $TMPDIR/lofi-d.out.$$
        	cleanup 99
	fi

	rm -rf $FNAME $FSNAME
	echo "Successfully completed cleanup of [$FSNAME]."
	cleanup 0
	;;

  \?) 
        echo $Usage
        exit 2
        ;;
esac

exit 0

