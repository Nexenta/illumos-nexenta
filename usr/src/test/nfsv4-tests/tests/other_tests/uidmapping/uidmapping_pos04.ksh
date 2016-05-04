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
# uidmapping_pos04.ksh
#     This file contains positive testcases for the setup that domains
#     mismatch. They are:
# 	
#	{a} - create a file and verify the file was created and with 
#	      correct user id on both server side and client side

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

trap "cleanup" EXIT
trap "exit 1" HUP INT QUIT PIPE TERM

NAME=`basename $0`
UIDMAPENV="./uid_proc"
UNINITIATED=6

# set up script running environment
if [ ! -f $UIDMAPENV ]; then
        echo "$NAME: UIDMAPENV[$UIDMAPENV] not found; test UNINITIATED."
        exit $UNINITIATED
fi
. $UIDMAPENV

ASSERTIONS=${ASSERTIONS:-"a b c"}
DESC="client and server mapid domains mismatch, "

function setup
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        # run test cases on shared directory
        cd $TESTDIR

        # set up client domain
        Ndomain="nonexistent.at.all"
        set_local_domain $Ndomain 2>$ERRLOG
        ckreturn $? "could not set up domain $Ndomain on client" \
            $ERRLOG "ERROR" || return 1
}

function cleanup
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        # we don't want user can interrupt cleanup procedure
        trap '' HUP INT QUIT PIPE TERM

	# remove testfile
        rm -f $TESTFILE 2>$ERRLOG
        ckreturn $? "could not remove $TESTFILE" $ERRLOG "WARNING"

        # Change to other directory
        cd $TESTROOT

        restore_local_domain 2>$ERRLOG
        ckreturn $? "could not restore local domain" $ERRLOG "WARNING"

        # remove temporary file
        rm -f $ERRLOG
        ckreturn $? "could not remove $ERRLOG" /dev/null "WARNING"
}

# Assertions

# a: create NFS file with mismatch mapid domain
function as_a
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=0
	desc="$DESC""create a file over NFS as root, "
	desc="$desc""file is created successfully, "
	desc="$desc""check it on server side, file owner is root, "
	desc="$desc""check it on client side, file owner is nobody"
	assertion a "$desc" $exp

	touch $TESTFILE 2>$ERRLOG
	res=$?

	if [ $exp -ne $res ]; then
                # print error message
                ckres2 uidmapping "$res" $exp "could not create file"
		return $FAIL
	fi

        # check it on server side 
        exp=0
        execute $SERVER root "ls -l $ROOTDIR/$TESTFILE" 1>/dev/null 2>$ERRLOG
	res=$?

	if [ $exp -ne $res ]; then
               	ckres2 uidmapping "$res" $exp "could not found file on server" 
		return $FAIL
	fi

	# check file owner on server side
	exp=0
        execute $SERVER root "ls -l $ROOTDIR/$TESTFILE \
            | awk \"{print \\\$3, \\\$4}\" \
            | grep root.*root" 1>/dev/null 2>$ERRLOG
	res=$?

	if [ $exp -ne $res ]; then
        	ckres2 uidmapping "$res" $exp "wrong file owner/group"
		return $FAIL
	fi

	# check file owner on client side
	exp="nobody"
	res=$(get_val $OWN $TESTFILE)
        rm -f $TESTFILE
	ckres2 uidmapping "$res" $exp "unexpected file owner"
}

# b: create NFS directory with mismatched mapid domain
function as_b
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=0
	desc="$DESC""create a directory over NFS as root, "
	desc="$desc""file is created successfully, "
	desc="$desc""check it on server side, file owner is root, "
	desc="$desc""check it on client side, file owner is nobody"
	assertion b "$desc" $exp

	typeset TESTDIR=uidmapping.$$.testdir
	mkdir $TESTDIR 2>$ERRLOG
	ckres2 -s mkdir $? $exp "could not create directory" $ERRLOG \
	    || return $FAIL

        # check it on server side 
        exp=0
        tmp=$(execute $SERVER root "ls -ld $ROOTDIR/$TESTDIR" 2>$ERRLOG)
	ckres2 -s "ls" $? $exp "could not found directory on server" $ERRLOG \
	    || return $FAIL

	# check file owner on server side
	exp=0
	echo $tmp | awk '{print $3, $4}' | grep root.*root 1>/dev/null 2>&1
	ckres2 -s "ls" $? $exp "incorrect file owner" || return $FAIL

	# check file owner on client side
	exp="nobody"
	res=$(ls -ld $TESTDIR \
	    | awk '{print $3}' 2>&1) 
        rm -rf $TESTDIR
	ckres2 uidmapping "$res" $exp "unexpected file owner"
}

# c: create attribute file over NFS with mismatch mapid domain
function as_c
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        exp=0
        desc="$DESC""create a attribute file over NFS as root, "
        desc="$desc""file is created successfully, "
        desc="$desc""check it on server side, file owner is root, "
        desc="$desc""check it on client side, file owner is nobody"
        assertion c "$desc" $exp

	# create a normal file
	touch $TESTFILE 2>$ERRLOG
	ckreturn $? "failed to create $TESTFILE" $ERRLOG "UNRESOLVED" ||
	    return $UNRESOLVED

	ATTRFILE=$NAME.$$.attr
	# create a attribute file for the above file
	runat $TESTFILE touch $ATTRFILE > $ERRLOG
	ckres2 -s runat $? 0 "failed to create attribute file" \
	    $ERRLOG  || return $FAIL

	# check it on server side
	tmp=$(execute $SERVER root "runat $ROOTDIR/$TESTFILE ls -l $ATTRFILE" \
	    2>$ERRLOG)
	ckres2 -s execute $? 0 "attr file not exist" $ERRLOG \
	    || return $FAIL

	# check file owner on server side
	echo $tmp | awk '{print $3, $4}' | grep root.*root >/dev/null 2>&1
	ckres2 -s execute $? 0 "incorrect file owner on server side" \
	    || return $FAIL

	# check it on client side
	exp="nobody"
	res=$(runat $TESTDIR/$TESTFILE ls -l $ATTRFILE \
            | awk '{print $3}' 2>&1)
	rm -f $TESTFILE
	ckres2 runat "$res" $exp "unexpected file owner" || return $FAIL
}

# setup
setup || return 1

# main loop
for i in $ASSERTIONS
do
	as_$i || print_state
done
