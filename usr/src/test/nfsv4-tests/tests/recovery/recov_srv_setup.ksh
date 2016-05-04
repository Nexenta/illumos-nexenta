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
# setup the $SERVER for testing NFS V4 recovery testing by:
# first removing LOFI file systems setup prior to recovery
# test execution. Setup server with testfiles, export it,
# start reboot/restart daemon.
#

SetDebugMode
[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "$NAME: ERROR - Must be root to run this script for setup."
        exit 1
fi

Usage="Usage: $NAME -s | -c \n
		-s: to setup this host w/daemon, testfiles, and share\n
		-c: to cleanup the server\n
"
if [ $# -lt 1 ]; then
	echo "$NAME: ERROR - incorrect usage."
	echo $Usage
	exit 2
fi

TMPDIR=Tmpdir_from_client
CONFIGFILE=CONFIGFILE_from_client
CONFIGDIR=CONFIGDIR_from_client

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

getopts sc opt
case $opt in
  s)
	# First cleanup the LOFI test filesystems (to avoid reboot warning)
	/usr/bin/ksh $CONFIGDIR/setserver -r > $TMPDIR/ssrv-r.out.$$ 2>&1
	[ $? -ne 0 ] && cat $TMPDIR/ssrv-r.out.$$

	# make sure nfs4red reboot/reset-nfsd daemon is running
	chmod +x $CONFIGDIR/nfs4red > /dev/null 2>&1
	$CONFIGDIR/nfs4red > /dev/null 2>&1 &
	ps -e | grep -w "nfs4red" > /dev/null
	if [ $? -ne 0 ]; then
		$CONFIGDIR/nfs4red > /dev/null 2>&1 &
	fi
	
	echo "Done - setup nfs4red OKAY."
        ;;

  c) 
	pkill -x -u 0 nfs4red 

        echo "Done - recovery cleanup of test filesystems/daemons OKAY"
        rm -f $CONFIGDIR/recov_setserver $CONFIGDIR/nfs4red \
		/etc/rc3.d/S99nfs4red
        ;;

  \?) 
	echo $Usage
	exit 2
	;;
esac

exit 0
