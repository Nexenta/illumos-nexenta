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
# For recovery testing purposes, cleanup server filesystem from
# previous nfs4_gen test suite being run. Setup server with 
# reboot capability.
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`dirname $0`
TESTROOT=${TESTROOT:-"$DIR/../"}
TESTSH="$TESTROOT/testsh"

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "Must be root to run this script."
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

#source support functions 
. $TESTSH

function cleanup		# ensure umount MNPTR & exit
{
        # Need to unmount the test directory
        umount ${MNTPTR} > $TMPDIR/$NAME.umount.$$ 2>&1
        if [ $? -ne 0 ]; then
                echo "$NAME: cleanup - umount ${MNTPTR} failed"
                cat $TMPDIR/$NAME.umount.$$
	else 
		rm -f $TMPDIR/$NAME.umount.$$
        fi
        exit ${1}
}

# setup the server ... 
# add environment variables to recov_srv_setup script:
rm -f $TMPDIR/recov_setserver
SETD="DEBUG=0; export DEBUG"
[ "$DEBUG" != "0" ] && SETD="DEBUG=1; export DEBUG; set -x"
sed -e "s%Tmpdir_from_client%$TMPDIR%" -e "s%SetDebugMode%$SETD%" \
	-e "s%CONFIGFILE_from_client%$CONFIGFILE%" \
        -e "s%CONFIGDIR_from_client%$CONFIGDIR%" \
	recov_srv_setup > $TMPDIR/recov_setserver
if [ $? -ne 0 ]; then
        echo "$NAME: can't setup [recov_setserver] file."
        exit $UNINITIATED
fi

# and the reboot scripts
sed -e "s%Tmpdir_from_client%$TMPDIR%" \
        -e "s%CONFIGFILE_from_client%$CONFIGFILE%" \
        -e "s%CONFIGDIR_from_client%$CONFIGDIR%" \
	nfs4red > $TMPDIR/nfs4red
if [ $? -ne 0 ]; then
        echo "$NAME: can't setup [nfs4red] file."
        exit $UNINITIATED
fi
sed -e "s%Tmpdir_from_client%$TMPDIR%" \
        -e "s%BASEDIR_from_client%$BASEDIR%" \
        -e "s%CONFIGDIR_from_client%$CONFIGDIR%" \
        S99nfs4red > $TMPDIR/S99nfs4red
if [ $? -ne 0 ]; then
        echo "$NAME: can't setup [S99nfs4red] file."
        exit $UNINITIATED
fi

# ... now setup the $SERVER
ping $SERVER > $TMPDIR/ping.out.$$ 2>&1
if [ $? -ne 0 ]; then 
	echo "$SERVER setup failed - not responding?" 
	cat $TMPDIR/ping.out.$$
	exit $OTHER
fi

# copy server programs over to $SERVER for setup
scp $TMPDIR/recov_setserver $TMPDIR/nfs4red root@$SERVER:$CONFIGDIR \
	> $TMPDIR/rcp.out.$$ 2>&1
if [ $? -ne 0 ]; then
	echo "$NAME: copying setup files to $SERVER failed:"
	cat $TMPDIR/rcp.out.$$
	exit $OTHER
fi

scp $TMPDIR/S99nfs4red root@$SERVER:/etc/rc3.d > $TMPDIR/rcp.out.$$ 2>&1
if [ $? -ne 0 ]; then
        echo "$NAME: copying S99nfs4red file to $SERVER failed:"
        cat $TMPDIR/rcp.out.$$
        exit $OTHER
fi

execute $SERVER root "/usr/bin/ksh $CONFIGDIR/recov_setserver -s" \
	> $TMPDIR/rsh.out.$$ 2>&1
ret=$?
grep "OKAY" $TMPDIR/rsh.out.$$ | grep -v echo > /dev/null 2>&1
if [ $? -eq 0 ] && [ $ret -eq 0 ]; then
	# If server returned some warning, print it out
	grep "WARNING" $TMPDIR/rsh.out.$$ | grep -v echo > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "$NAME: setup $SERVER have warnings:"
		grep WARNING $TMPDIR/rsh.out.$$
	fi
else
	grep "ERROR" $TMPDIR/rsh.out.$$ | grep -v echo > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "$NAME: setup $SERVER had errors:"
	else
		echo "$NAME: setup $SERVER failed:"
	fi
	cat $TMPDIR/rsh.out.$$
	exit $OTHER
fi
[ $DEBUG != "0" ] && cat $TMPDIR/rsh.out.$$

echo "  SERVER=$SERVER recovery setup OK!! "
echo "$NAME: PASS"
exit $PASS 
