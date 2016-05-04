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
# cleanup script for nfs server environment

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "Must be root to run this script."
        exit $OTHER
fi

NAME=`basename $0`
DIR=`dirname $0`
TESTROOT=${TESTROOT:-"$DIR/../"}
TESTSH=$TESTROOT/testsh

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# sourcing useful functions
. $TESTSH

# now cleanup the SERVER
execute $SERVER root \
	"ksh ${CONFIGDIR}/recov_setserver -c" \
	> ${TMPDIR}/rsh.out.$$ 2>&1
grep "OKAY" ${TMPDIR}/rsh.out.$$ | grep -v echo > /dev/null 2>&1
if [ $? -ne 0 ]; then
	grep ERROR ${TMPDIR}/rsh.out.$$ | grep -v echo > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "$NAME: cleanup $SERVER failed:"
		cat ${TMPDIR}/rsh.out.$$
	fi
else
	# If server returned some warning, print it out
	grep "WARNING" $TMPDIR/rsh.out.$$ | grep -v echo > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		cat $TMPDIR/rsh.out.$$
	fi
fi
[ $DEBUG != "0" ] && cat $TMPDIR/rsh.out.$$

echo "$NAME: $SERVER recov_cleanup OK!! "
echo "$NAME: PASS"
exit $PASS
