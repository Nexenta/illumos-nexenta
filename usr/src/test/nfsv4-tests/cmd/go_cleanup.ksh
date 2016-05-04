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
#
. $TESTROOT/nfs4test.env

[[ -n $DEBUG ]] && [[ $DEBUG != 0 ]] && set -x

NAME=$(basename $0)
DIR=$(dirname $0)

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# sourcing support functions
. ./testsh

id | grep "0(root)" > /dev/null 2>&1
if (( $? != 0 )); then
        echo "Must be root to run this script."
        exit $OTHER
fi

#make sure the MNTPTR is umounted on the client
mount | grep "^$MNTPTR[ \t]" | grep "on.*$SERVER:" > /dev/null 2>&1
if (( $? == 0 )); then
	umount -f $MNTPTR > $TMPDIR/umount.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "umount -f $MNTPTR on client failed - \c"
		cat $TMPDIR/umount.out.$$
		exit $OTHER
	fi
fi

# cleanup the SERVER
echo "Cleaning up server $SERVER"
execute $SERVER root \
	"export DEBUG=$DEBUG; /usr/bin/ksh $CONFIGDIR/setserver -c" \
	> $TMPDIR/rsh.out.$$ 2>&1
st=$?
if [[ $DEBUG == 0 ]]; then
	grep "OKAY" $TMPDIR/rsh.out.$$ > /dev/null 2>&1
	if (( $? == 0 && st == 0 )); then
		# If server returned some warning, print it out
		grep "WARNING" $TMPDIR/rsh.out.$$ | grep -v echo > \
			/dev/null 2>&1
	else
		grep ERROR $TMPDIR/rsh.out.$$ | grep -v echo > /dev/null 2>&1
		if (( $? == 0 )); then
			echo "$NAME: cleanup $SERVER had errors:"
		else
			echo "$NAME: cleanup $SERVER failed:"
		fi
		cat $TMPDIR/rsh.out.$$
	fi
else
	cat $TMPDIR/rsh.out.$$
fi

# Cleanup the client
echo "Cleaning up client $CLIENT"

# Remove added test users ...
res=$(mv /etc/passwd.orig /etc/passwd 2>&1)
res=$(mv /etc/group.orig /etc/group 2>&1)
res=$(chmod 444 /etc/passwd /etc/group 2>&1)
res=$(pwconv 2>&1)
res=$(/usr/xpg4/bin/egrep "2345678." /etc/passwd > $TMPDIR/users.err)
n=$(cat $TMPDIR/users.err | wc -l | nawk '{print $1}')
if (( n != 0 )); then
	echo "WARNING: removing test users failed, \
		remove the following users manually:"
	cat $TMPDIR/users.err
	echo "\n"
fi
rm -f $TMPDIR/users.err
res=$(/usr/xpg4/bin/egrep "2345678." /etc/group > $TMPDIR/groups.err)
n=$(cat $TMPDIR/groups.err | wc -l | nawk '{print $1}')
if (( n != 0 )); then
	echo "WARNING: removing test groups failed, \
		remove the following groups manually:"
	cat $TMPDIR/groups.err
	echo "\n"
fi
rm -f $TMPDIR/groups.err

# restore nfs tunable values
if [[ -f $CONFIGDIR/$CLIENT.nfs.flg ]]; then
	res=$(cat $CONFIGDIR/$CLIENT.nfs.flg)
	[[ -n $res ]] && ./set_nfstunable $res > $TMPDIR/nfs.out.$$ 2>&1
	if (( $? != 0 )); then
		echo "WARNING: restoring nfs tunable failed on $CLIENT:"
		cat $TMPDIR/nfs.out.$$
		echo "Please restore the following nfs tunable manually: $res"
	fi
fi

# Remove files
rm -f /suexec 
rm -rf $MNTPTR
rm -rf $TMPDIR $CONFIGDIR/*

# Remove nfsh in non-global zone.
is_cipso "$TMPNFSMOPT" $SERVER
(( $? == CIPSO_NFSV4 )) && rm $ZONE_PATH/root/nfsh $ZONE_PATH/root/tclprocs

echo "$NAME: PASS"
exit $PASS
