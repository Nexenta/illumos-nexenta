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

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
CDIR=`pwd`

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "$NAME: This script require root permission to run."
        exit 99
fi

CONFIGFILE=CONFIGFILE_from_client
CONFIGDIR=CONFIGDIR_from_client
TMPDIR=Tmpdir_from_client

function smf_is_present
{
        [ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x
        smf_include="/lib/svc/share/smf_include.sh"
        [ ! -r ${smf_include} ] && return 1

        . ${smf_include}

        smf_present
}

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

NOTICEDIR=$BASEDIR/._Notice__Dir_.

[ ! -d $NOTICEDIR ] && mkdir -m 0777 -p $NOTICEDIR || chmod 0777 $NOTICEDIR

fmri=svc:/network/nfs/server:default
timeout=10

while :; do
	sleep 2
	action=`ls -d $NOTICEDIR/re* 2>/dev/null | nawk -F\/ '{print $NF}'`

	case $action in
	  reset-nfsd)
		echo "Restarting the 'nfsd' in `uname -n` ..."
		rm -f $NOTICEDIR/DONE_reset
		if smf_is_present; then
			svcadm disable ${fmri}
		fi

		pkill -x -u 0 nfsd
		sleep 1

		if smf_is_present; then
			svcadm enable ${fmri}
			timer=${timeout}
		else
			/usr/lib/nfs/nfsd
			timer=5
		fi
		i=1
		while [ $i -le $timer ]
		do
			pgrep nfsd > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				i="OK"
				break
			fi
			i=`expr $i + 1`
			sleep 1
		done
		if [ $i = "OK" ]; then
			echo "ReSet NFSD(`pgrep nfsd`) started" \
				> $NOTICEDIR/DONE_reset
		else
			echo "ReSet nfsd FAILed" > $NOTICEDIR/DONE_reset
		fi
		;;
	  reboot)
		echo "Rebooting `uname -n`, please wait ..."
		rm -f $NOTICEDIR/DONE_reboot
		rm -f $NOTICEDIR/re*
		sync; sync; reboot
		;;
	  requit)
		rm -f $NOTICEDIR/re*
		break;;
	  *)
		continue;;

	esac
	rm -f $NOTICEDIR/re*
done
exit 0
