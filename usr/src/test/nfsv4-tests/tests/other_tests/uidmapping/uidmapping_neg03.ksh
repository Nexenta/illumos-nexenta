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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# uidmapping_neg03.ksh 
#     This file contains negative testcases for the setup that both server
#     and client have the same domain. The testcases are:
#
#	{a} - change owner to user known only to client
#	{b} - change owner to user known only to client but who has a valid 
#	      id on server

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

ASSERTIONS=${ASSERTIONS:-"a b"}
DESC="client and server have the same mapid domain, "

function setup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	# change to shared directory
	cd $TESTDIR

	if [ "$Sdomain" != "$Cdomain" ]; then
		# set up client domain
		set_local_domain $Sdomain 2>$ERRLOG
		ckreturn $? "could not set up domain $Sdomain on client" \
			$ERRLOG "ERROR" || return 1
	fi

	# create temporary file for testing
	touch $TESTFILE 2>$ERRLOG 
	ckreturn $? "could not create $TESTFILE" $ERRLOG "ERROR" || return 1

	# make sure nobody issue not found
	typeset ug=$(/bin/ls -l $TESTFILE | awk '{print $3,$4}')
	if [ "$ug" == "nobody nobody" ]; then
		echo "something is wrong on nfs/mapid, nobody issue found"
		print_state
		return 1
	fi
}

function cleanup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	# we don't want cleanup procedure to be interruptable
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

function as_a
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=1
	desc="$DESC""user known only to client: $TUSERC, "
	desc="$desc""chown fails and file owner doesn't change"
	assertion a "$desc" $exp

	prev=$(get_val $OWN $TESTFILE)
	chown $TUSERC $TESTFILE 2>$ERRLOG
	st=$?

	# check if the command failed as expected
	if [ $exp -ne $st ]; then
		# print error message
		ckres2 uidmapping "$st" $exp "command should fail"
	else
		# check if the server side setting didn't change
		res=$(get_val $OWN $TESTFILE)
		ckres2 uidmapping "$res" $prev "file owner was changed"
	fi
}

function as_b
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	exp=1
	desc="$DESC""user known only to client with common user id: $TUSERC2, "
	desc="$desc""chown fails and file owner doesn't change"
	assertion b "$desc" $exp

	prev=$(get_val $OWN $TESTFILE)
	chown $TUSERC2 $TESTFILE 2>$ERRLOG
	st=$?

	# check if the command failed as expected
	if [ $exp -ne $st ]; then
		# print error message
		ckres2 uidmapping "$st" $exp "command should fail"
	else
		# check if the server side setting didn't change
		res=$(get_val $OWN $TESTFILE)
		ckres2 uidmapping "$res" $prev "file owner was changed"
	fi
}

# set up test environment
setup || exit $UNINITIATED

# main loop
for i in $ASSERTIONS
do
	as_$i || print_state
done
