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
# control program for OPENATTR op tests

[[ -n $DEBUG && $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
DIR=$(dirname $0)
CDIR=$(pwd)
TESTROOT=${TESTROOT:-"$CDIR/../../"}
TESTTAG="OPENATTR"
TESTLIST=$(egrep -v "^#|^  *$" ${TESTTAG}.flist)

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

#source support functions
TESTSH="$TESTROOT/testsh"
. $TESTSH

iscipso=0
is_cipso "vers=4" $SERVER
if (( $? == $CIPSO_NFSV4 )); then
	iscipso=1
	# In openattr_neg03{a}, we need to do "Openattr" operation in non-global zone
        # for TX test, so add a tcl script to non-global zone.
        echo "connect $SERVER" > $ZONE_PATH/root/openattr_neg03
	echo 'set res [compound {Putfh $env(qfh); Lookup $env(RWFILE); Openattr T}]' \
		>> $ZONE_PATH/root/openattr_neg03
	echo 'puts "$status $res"' >> $ZONE_PATH/root/openattr_neg03
	echo 'disconnect' >> $ZONE_PATH/root/openattr_neg03
fi

# Start the tests with some information
echo
echo "Testing at CLIENT=[$CLIENT] to SERVER=[$SERVER]"
echo "Started $TESTTAG op tests at [$(date)] ..."
echo

# Now ready to run the tests
(
for t in $TESTLIST; do
        # Need to switch to $TUSER2 for quota testing
        grep DQUOT $t >/dev/null 2>&1
        rc=$?
        grep $TUSER2 /etc/passwd >/dev/null 2>&1
        rc=$(( $rc + $iscipso + $? ))
        if (( $rc == 0 )); then
                su $TUSER2 -c "(. $CONFIGFILE; \
                        $TESTROOT/nfsh $t)"
        else
                $TESTROOT/nfsh $t
        fi
done
)

[[ $iscipso == 1 ]] && rm $ZONE_PATH/root/openattr_neg03

echo
echo "Testing ends at [$(date)]."
echo 
exit $PASS
