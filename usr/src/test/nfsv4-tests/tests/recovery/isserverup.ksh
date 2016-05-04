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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
#  script to talk to reboot/restart daemon and check when
#  server is alive again for NFSv4 client recovery tests
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`

if (( $# != 1 ))
then
	print -u2 "Usage: $0 <reboot|reset-nfsd>"
	exit 1
fi

COMMAND=$1

case $COMMAND in
	reboot) touch $MNTPTR/$NOTICEDIR/reboot
		# Ping until down
		COUNTER=1
		while /usr/sbin/ping $SERVER 5 >/dev/null 2>&1
		do
		    echo $SERVER is still alive
		    if (( COUNTER == $REBOOTIMER ))
		    then
			echo $SERVER did not reboot within $REBOOTIMER seconds
			exit 1
		    else
			sleep 1
			(( COUNTER += 1 ))
		    fi
		done

		echo $SERVER is now DEAD

		# Ping until up
		if /usr/sbin/ping $SERVER $REBOOTIMER >/dev/null 2>&1
		then
		    echo $SERVER is now ALIVE
		    exit 0
		else
		    echo $SERVER never came back up after $REBOOTIMER seconds
		    exit 1
		fi
		;;

	reset-nfsd) touch $MNTPTR/$NOTICEDIR/reset-nfsd
		sleep 10
		loop=0

		touch $TMPDIR/isserverup.out.$$
		while (( loop < 10 ))
		do
		rsh -n $SERVER pgrep nfsd > $TMPDIR/isserverup.out.$$

                if [ -s $TMPDIR/isserverup.out.$$ ]
                then
                        echo nfsd started
			exit 0
                else
                        echo nfsd not started
                fi
		((loop += 1)) 
		done
		    # make sure nfsd is running
		;;
*) print -u2 "Invalid command: $COMMAND"
esac

exit 0
