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
# NFSv4 named attributes support functions: 
#

[[ -n $DEBUG && $DEBUG != 0 ]] && set -x


TESTSH=$TESTROOT/testsh
if [ -r $TESTSH ]; then
	. $TESTSH
else
	echo "$0 ERROR: Cannot read file $TESTSH. Terminating ..." >&2
	exit 6 /* UNINITIATED */
fi


function setup
{
	# any arguments are silently ignored
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x
	NAME=`basename $0`
	DIR=`dirname $0`
	CDIR='pwd'

	LSAT='ls -@'
	LSATD='ls -@d'
	CPAT='cp -@'
	TESTFILE="foo.$$"
	TESTFILE2="foo2.$$"
	NEWFILE="newfoo.$$"
	TESTDIR1="dirobj1.$$"
	TESTDIR2="dirobj2.$$"
	TESTDIR3="dirobj3.$$"
	HLNK1="link1.$$"
	HLNK2="link2.$$"
	OLIST="TESTFILE TESTFILE2 NEWFILE HLNK1 HLNK2 TESTDIR1 TESTDIR2 \
		TESTDIR3"

	. $TESTROOT/nfs4test.env

	TMPmnt=$ZONE_PATH/$NAME.$$
	export TMPmnt $OLIST

	is_root $NAME
}

function cleanup
{
	[[ -n $DEBUG && $DEBUG != 0 ]] && set -x
	(( $# < 1 )) && echo "USAGE: cleanup return_code" && exit $OTHER
	typeset out=$1

	# clean all files created here
	for i in $OLIST
	do
		typeset value=$(eval "echo \$${i}")
		[ -e $TMPmnt/$value ] && rm -rf $TMPmnt/$value 2>&1 > /dev/null
		[ -e $MNTPTR/$value ] && rm -rf $MNTPTR/$value 2>&1 > /dev/null
	done

	# unmount dir
	mount | grep "^$TMPmnt" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		umount $TMPmnt > $TMPDIR/umount.out.$$
		ret=$?
		ckreturn $ret "Cannot unmount [$TMPmnt], returned $ret." \
			$TMPDIR/$umount.out.$$ WARNING
		if [ $? -ne 0 ]; then
			umount -f $TMPmnt
			ret=$?
			[ $ret -ne 0 ] && \
				echo "umount -f $TMPmnt also failed ($ret)."
		fi
	fi

	# clean dir
	mount | grep "^$TMPmnt" > /dev/null 2>&1
	[ $? -ne 0 ] && [ -d $TMPmnt ] && rm -rf $TMPmnt

	# Cleanup temp files
	rm -f $TMPDIR/*.out.$$ > /dev/null 2>&1

	[ $out -ne 0 ] && exit $out
}
