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
# control program for all NFSv4 client recovery tests 
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`dirname $0`
TESTROOT=${TESTROOT:-"$DIR/.."}

# Must be run as root since server re-boots
id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "Must be root to run $NAME tests."
        exit $OTHER
fi

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

function cleanup
{
	rm -f $TMPDIR/*.$$ $TMPDIR/SERVER_NOT_IN_GRACE > /dev/null 2>&1
	exit $1
}

# Setup the server with necessary files for recovery testing
echo "Setting up server<$SERVER> for recovery testing."
$DIR/recov_setup
if [ $? -ne 0 ]; then
   echo "ERROR: recovery/recov_setup failed to setup server"
   cleanup 1
fi

# Start the tests with some information
echo " "
echo "Testing on CLIENT=[`uname -n`] to SERVER=[$SERVER]"
echo "Started $dir tests at [`date`] ..."
echo " "

# Now ready to run the tests
TESTLIST=${TESTLIST:-`egrep -v "^#|^  *$" RECOV.flist`}

for t in $TESTLIST
do
	$TESTROOT/nfsh $t
	sleep 3
done

echo " "
echo "Testing ends at [`date`]."
echo " "

# Now cleanup the stuffs from recovery testing
echo "Cleaning up server<$SERVER> from the recovery testing."
$DIR/recov_cleanup
if [ $? -ne 0 ]; then
	echo "ERROR: recovery/recov_cleanup failed to cleanup server"
	cleanup 1
fi

cleanup 0
