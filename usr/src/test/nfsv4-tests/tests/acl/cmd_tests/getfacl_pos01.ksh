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
# ACL getfacl positive test
#     call getfacl(1) get to the ACL from an (file, directory or 
#     attribute) object after chmod(1) with different permissions.
#

if [ -z "$DEBUG" ]; then
	export DEBUG=0 
else
	[ "$DEBUG" != "0" ] && set -x
fi

NAME=`basename $0`
CDIR=`pwd`

# Source for common functions
. $CDIR/ACL.utils

# Preparation: create temp file/directory for testing 
# Assume MNTPTR is the base test directory.
TDIR=$MNTPTR/$NAME.dir.$$
TFILE=$MNTPTR/$NAME.file.$$
AFILE=$NAME.attr.$$
EFILE=$TMPDIR/$NAME.err.$$
touch $EFILE

# setup test file and directory
function test_setup
{
    [ "$DEBUG" != "0" ] && set -x
    mkdir -m 0777 $TDIR >> $EFILE 2>&1 || return $UNINTIATED
    echo "This is test file for $NAME" > $TFILE  2>> $EFILE || \
	return $UNINTIATED
    chmod 0666 $TFILE >> $EFILE 2>&1 || return $UNINTIATED
    runat $TFILE "echo \"This is test file for $TFILE\" > $AFILE" 2>> $EFILE ||\
	return $UNINTIATED
    runat $TFILE "chmod 0777.; chmod 0666 $AFILE" 2>> $EFILE 
}

# cleanup to remove tmp files/dirs
function cleanup
{
    [ "$DEBUG" != "0" ] && set -x
    rm -fr $TDIR $TFILE $EFILE $TMPDIR/$NAME.*.$$
    exit $1
}

# verify the acl permission match the mode bits of an object
function ckace
{
    [ "$DEBUG" != "0" ] && set -x
    ace=$1		# permission of an ACL entry
    mbit=$2		# a file mode bit to be compared
    obj=$3		# the object name for printing error message
    msgfile=$4		# message file to be printed if DEBUG
    case $mbit in
	7)	exp_ace="rwx" 	;;
	6)	exp_ace="rw-" 	;;
	5)	exp_ace="r-x" 	;;
	4)	exp_ace="r--" 	;;
	3)	exp_ace="-wx" 	;;
	2)	exp_ace="-w-" 	;;
	1)	exp_ace="--x" 	;;
	0)	exp_ace="---" 	;;
	*)	exp_ace="" 	;;
    esac
    if [ "$ace" != "$exp_ace" ]; then
	echo "\t Test FAIL: $obj - ACE does not match"
	echo "\t\t expect <$exp_ace>, got <$ace>"
	[ "$DEBUG" != "0" ] && [ -f $msgfile ] && cat $msgfile
	return 1
    else
	[ "$DEBUG" != "0" ] && \
		echo "ACE match - expect <$exp_ace>, got <$ace>"
	return 0
    fi
}    


# Test assertion driver to loop throught different modes
function run_assert
{
    [ "$DEBUG" != "0" ] && set -x
    TOBJ=$1		# the object to verify ACL entries
    RUNAT=$2		# flag for attribute file

    # Loop throught different modes
    modes="777 755 711 700 055 051 011 001 765 654 543 432 321 210 100 000"
    for m in $modes
    do
	# split the bits
	user=`echo "$m" | cut -c1`
	group=`echo "$m" | cut -c2`
	other=`echo "$m" | cut -c3`

	# set the mode; then get its ACL
	# should get the default as no ACL was set
	CMD="chmod $m $TOBJ" 
	if [ "$RUNAT" = "runat" ]; then
		runat $TFILE "$CMD" > $TMPDIR/$NAME.chm.$$ 2>&1
	else
		$CMD > $TMPDIR/$NAME.chm.$$ 2>&1
	fi
	ckreturn $? "$CMD failed" $TMPDIR/$NAME.chm.$$ || return $FAIL
	CMD="getfacl ${TOBJ}"
	if [ "$RUNAT" = "runat" ]; then
		runat $TFILE "$CMD" > $TMPDIR/$NAME.ga.$$ 2>&1 
	else
		$CMD > $TMPDIR/$NAME.ga.$$ 2>&1
	fi
	ckreturn $? "$CMD failed" $TMPDIR/$NAME.ga.$$ || return $FAIL

	# Verify the default ACEs look OK based on the mode
	nusr=`egrep "^user::" $TMPDIR/$NAME.ga.$$ | \
		nawk -F\: '{print $3}' | nawk '{print $1}'`
	ngrp=`egrep "^group::" $TMPDIR/$NAME.ga.$$ | \
		nawk -F\: '{print $3}' | nawk '{print $1}'`
	noth=`egrep "^other:" $TMPDIR/$NAME.ga.$$ | \
		nawk -F\: '{print $2}' | nawk '{print $1}'`
	ckace $nusr $user "$TOBJ|user|$m" $TMPDIR/$NAME.ga.$$ || return $FAIL
	ckace $ngrp $group "$TOBJ|group|$m" $TMPDIR/$NAME.ga.$$ || return $FAIL
	ckace $noth $other "$TOBJ|other|$m" $TMPDIR/$NAME.ga.$$ || return $FAIL
    done

    # restore the original mode
    CMD="chmod 0777 $TOBJ"
    if [ "$RUNAT" = "runat" ]; then
    	runat $TFILE "$CMD" 
    else
	$CMD
    fi
    echo "\t Test PASS"
}


# Start main program here:
# ----------------------------------------------------------------------
test_setup
if [ $? -ne 0 ]; then
	echo "$NAME{setup}: preparation for $NAME test"
	echo "\t UNINITIATED - no assertions will be run"
	cat $EFILE
	cleanup $UNINITIATED
fi

# ----------------------------------------------------------------------
# a: Verify getfacl of a dir with different modes, expect successful
ASSERTION="getfacl of a dir w/different modes, expect successful"
echo "$NAME{a}: $ASSERTION"
run_assert $TDIR reg

# b: Verify getfacl of a file with different modes, expect successful
ASSERTION="getfacl of a file w/different modes, expect successful"
echo "$NAME{b}: $ASSERTION"
run_assert $TFILE reg

# c: Verify getfacl of attr file with different modes, expect successful
ASSERTION="getfacl of an attr file w/different modes, expect successful"
echo "$NAME{c}: $ASSERTION"
run_assert $AFILE runat


# cleanup and exit
cleanup $PASS
