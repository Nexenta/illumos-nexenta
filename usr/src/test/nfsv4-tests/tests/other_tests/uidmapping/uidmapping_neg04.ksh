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
# uidmapping_neg04.ksh 
#     This file contains negative testcases for the setup that domains 
#     mismatch. They are:
#
#     	{a} - files owner and group are mapped to nobody
#	{b} - chown command failed due to unmappable user string.
#

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
DESC="client and server domains mismatch, "

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

# a: ls -l shows nobody with mismatch mapid domain
function as_a
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=1
	assertion a \
	    "$DESC""ls -l shows nobody on all files in the test directory" $exp

	# get all files' user and group
	ls -l | grep -v total | awk '{print $3, $4}' >$TESTFILE 2>$ERRLOG
	ckreturn $? "could not generate $TESTFILE" $ERRLOG "ERROR" || return 1

	# look for mappable user or group. Shouldn't exist
	grep -v nobody $TESTFILE 1>/dev/null 2>$ERRLOG
	res=$?
	rm -f $TESTFILE
	ckres2 "ls -l own:grp are nobody" "$res" $exp \
	    "found mappable user or group"
}

# b: chown of existing file fails with mismatch mapid domain
function as_b
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=1
	assertion b "$DESC""chown an existing file fails, and file owner doesn't change" $exp

	# prepare test file
	touch $TESTFILE 2>$ERRLOG
	ckreturn $? "could not genereate $TESTFILE" $ERRLOG "UNINITIATED" \
	    || return 1

	# get its owner and owner_group
	old_attributes=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE")
	if [ $? -ne 0 ]; then
	    echo "\t Test UNINITIATED: ls -l $TESTFILE failed on server side"
	    rm -f $TESTFILE
	    return $UNINITIATED
	fi
	old_owner_grp=$(echo $old_attributes | nawk '{print $3, $4}')
	
	# try to change file owner and owner_group. Should fail
	chown bin:staff $TESTFILE 2>$ERRLOG

	# "chown" command failed or not? 
	res=$?

	# file owner and owner_group changed or not?
	new_attributes=$(execute $SERVER root "ls -l $ROOTDIR/$TESTFILE")
	if [ $? -ne 0 ]; then
	    echo "\t Test UNRESOLVED: ls -l $TESTFILE failed on server side after chown"
	    rm -f $TESTFILE
	    return $UNRESOLVED
	fi
	new_owner_grp=$(echo $new_attributes | nawk '{print $3, $4}')

	# check if the command failed as expected
	if [ $exp -ne $res ]; then
		# print error message
                echo "the owner/group of $SERVER:$ROOTDIR/$TESTFILE file" >&2
		echo "--------------------------------------------------" >&2
		echo "before chown command: $old_owner_grp" >&2
		echo "after chown command : $new_owner_grp" >&2
		echo "--------------------------------------------------" >&2

                ckres2 chown "$res" $exp "chown didn't fail"

		# clean up and return
		rm -f $TESTFILE
		return $FAIL
	fi 

	# check if the server side attributes didn't change
	if [ "$old_owner_grp" != "$new_owner_grp" ]; then
		# print error message
                echo "the owner/group of $SERVER:$ROOTDIR/$TESTFILE file" >&2
		echo "--------------------------------------------------" >&2
		echo "before chown command: $old_owner_grp" >&2
		echo "after chown command : $new_owner_grp" >&2
		echo "--------------------------------------------------" >&2

		ckres2 chown "$new_owner_grp" "$old_owner_grp" \
		    "$TESTFILE file owner/group was changed on server side"

		# clean up and return
		rm -f $TESTFILE
		return $FAIL
	fi

	# If it reaches here, the case passes. I call ckres2() below just to
	# print out information to tell the user that the case has passed, 
	# rather than for really matching $res against $exp, which I have 
	# already done above.

	rm -f $TESTFILE
	ckres2 chown "$res" $exp 
}

# c: setfacl fails with mismatch mapid domain
function as_c
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
	
	uid=0;user=root

        exp=2
        desc="$DESC""call setfacl/getfacl to set/get ACL, "
        assertion c "$desc" $exp

	setfacl -m user:$uid:rw- $TESTFILE 2>$ERRLOG
	ckres2 -s setfacl $? $exp "setfacl should fail" $ERRLOG \
	    || return $FAIL

	getfacl $TESTFILE 1>/dev/null 2>$ERRLOG
	ckres2 getfacl $? $exp "getfacl should fail" $ERRLOG \
	    || return $FAIL
}


# setup
setup || return $UNINITIATED

# main loop
for i in $ASSERTIONS
do
	as_$i || print_state
done
