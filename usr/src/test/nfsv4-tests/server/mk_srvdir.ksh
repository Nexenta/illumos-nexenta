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
# script to create test files/directories in the current
# directory based on variables in v4test.cfg file, which
# must be found in the same directory as the script.
#
#  Usage: $NAME [full-path-dir]
# 	if "full-path-dir" is not provided
#	default to create test files/dirs in "./srvdir"
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`

id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
	echo "$NAME: This script must be run as root."
	exit 1
fi

TDIR="./srvdir"
if (( $# > 0 )); then
        TDIR=${1}
fi
[[ ! -d $TDIR ]] && mkdir -m 0777 -p $TDIR
DIR=`dirname $0`
[[ "$DIR" = "." ]] && DIR=`pwd`

# get all names
CFGFILE="$DIR/config.suite"
if [[ ! -f $CFGFILE ]]; then
	echo "$NAME: CFGFILE[$CFGFILE] not found;"
	echo "\tunable to create test files/dirs; exiting."
	exit 2
fi
. $CFGFILE
# Any command below fails, will exit with non-zero immediately
set -e
cd $TDIR

# Start creation of test files and directories in $TDIR
echo "creating directories ..."
mkdir -m 0777 $DIR0777 $DIR0777/dir2  $LARGEDIR
mkdir -m 0755 $DIR0755 $DIR0755/dir2
mkdir -m 0711 $DIR0711 $DIR0711/dir2
mkdir -p $DNOPERM/dir2;
mkdir -p $LONGDIR
typeset -i i=1
while (( $i < 256 ))
do
	mkdir $LARGEDIR/dir-${i}
	cp $CFGFILE $LARGEDIR/file-${i}
	i=`expr $i + 1`
done

echo "creating test files ..."
head -38 $CFGFILE > $TEXTFILE; chmod 0644 $TEXTFILE
cp $CFGFILE $EXECFILE; chmod 0755 $EXECFILE
cp $CFGFILE $RWFILE; chmod 0666 $RWFILE
cp $CFGFILE $RWGFILE; chmod 0664 $RWGFILE
cp $CFGFILE $ROFILE; chmod 0444 $ROFILE
> $ROEMPTY; chmod 0444 $ROEMPTY
head -68 $CFGFILE > $FNOPERM; chmod 0000 $FNOPERM
zip -r $ZIPFILE $LARGEDIR > /dev/null 2>&1; chmod 0444 $ZIPFILE
cp $TEXTFILE $LONGDIR/file.20
find $RWFILE $ROFILE $ROEMPTY -print | cpio -dump $DIR0777
find $RWFILE $ROFILE $ROEMPTY -print | cpio -dump $DIR0755
find $RWFILE $ROFILE $ROEMPTY -print | cpio -dump $DIR0711
find $RWFILE $ROFILE $ROEMPTY -print | cpio -dump $DNOPERM

echo "creating symlink files ..."
ln -s $DIR0777 $SYMLDIR
ln -s $DNOPERM $SYMNOPD
ln -s $EXECFILE $SYMLFILE
ln -s $FNOPERM $SYMNOPF

echo "creating special files ..."
mknod $BLKFILE b 77 188; chmod 0644 $BLKFILE
mknod $CHARFILE c 88 177; chmod 0666 $CHARFILE
mknod $FIFOFILE p; chmod 0664 $FIFOFILE

echo "creating extended attribute files ..."
cp $RWFILE $ATTRFILE; chmod 666 $ATTRFILE
mkdir -m 0777 $ATTRDIR

echo "this is the ext-attr file for $ATTRFILE" | \
	runat $ATTRFILE "cat > $ATTRFILE_AT1; chmod 0777 ."
runat $ATTRFILE "cp $ATTRFILE_AT1 $ATTRFILE_AT2; chmod 0 $ATTRFILE_AT2"
cp -@ $ATTRFILE $ATFILE_NP; chmod 0 $ATFILE_NP;

echo "this is the ext-attr file for $ATTRDIR" | \
	runat $ATTRDIR "cat > $ATTRDIR_AT1; chmod 0777 ."
runat $ATTRDIR "cp $ATTRDIR_AT1 $ATTRDIR_AT2; chmod 0 $ATTRDIR_AT2"
cp -@ -r $ATTRDIR $ATDIR_NP; chmod 0 $ATDIR_NP
runat $ATDIR_NP "chmod 0777 ."

# Make sure owner are set correctly
chown -R 0:10 $TDIR
chmod 0000 $TDIR/$DNOPERM
set +e # End switch here as BASEDIR may be over UFS

# ZFS requires ACL access to create xattr
df -F zfs $TDIR > /dev/null 2>&1
if (( $? == 0 )); then
	set -e
	chmod A+everyone@:write_xattr/write_attributes/write_acl:allow \
		. $RWFILE $ATTRFILE $ATTRDIR
	chmod A+everyone@:read_xattr:deny \
		$DNOPERM $FNOPERM $ATDIR_NP $ATFILE_NP
	set +e
fi

echo " "
echo "DONE, all test files and directories have now been"
echo "created under [$TDIR]"
echo " "

exit 0
