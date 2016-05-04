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
# control program for NFSv4 ACL attributes tests
#
. $TESTROOT/nfs4test.env

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`dirname $0`
CDIR=`pwd`
TESTROOT=${TESTROOT:-"$CDIR/../../"}

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# Start the tests with some information
echo " "
echo "Testing at CLIENT=[`uname -n`] to SERVER=[$SERVER]"
echo "Started ACL tests at [`date`] ..."
echo " "


# Now ready to run the tests
TESTLIST=`egrep -v "^#|^  *$" acl.flist`
CFGFILE="$TESTROOT/../tests/acl/srv_tests/data.cfg"
(
. $CFGFILE
for t in $TESTLIST
do
	$TESTROOT/nfsh $t
done
)

echo " "
echo "Testing ends at [`date`]."
echo " "

exit 0
