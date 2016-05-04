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
# runtests.ksh
#     The file is the control program for uidmapping tests. It does some
#     initial setup common to all testscripts, which includes:
#	1) check server side mapid domain is not null
#       2) mount shared directory
#     Then it reads test script filelist and executes them one by one.
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

trap "cleanup" EXIT
trap "exit 1" HUP INT QUIT PIPE TERM

NAME=`basename $0`
UIDMAPENV="./uid_proc"
UNINITIATED=6

# set up initial running environment
if [ ! -f $UIDMAPENV ]; then
        echo "$NAME: UIDMAPENV[$UIDMAPENV] not found; test UNINITIATED."
        exit $UNINITIATED
fi
. $UIDMAPENV

# setup
#     the function first checks server side mapid domain and then mounts 
#     shared directory from server
# usage:
#     setup
# return value:
#     0 on success; 1 on error

function setup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

	# NFSmapid domain should be the same in both client and server
	# which is set in $TESTROOT/go_setup
	Cdomain=$(cat /var/run/nfs4_domain)
	Sdomain=$Cdomain
	export Sdomain Cdomain 

        # Create mount point directory
        mkdir -p "$TESTDIR" 2>$ERRLOG
        ckreturn $? "could not make mount point directory." $ERRLOG "ERROR" \
           || return 1

        # Mount file system
        mountit "$SERVER" "$ROOTDIR" "$TESTDIR" 4 1>$ERRLOG 2>&1
        ckreturn $? "could not mount directory." $ERRLOG "ERROR" || return 1

	rm $ERRLOG
}

# cleanup 
#     the function restores the original environment changed by call of 
#     setup(). It unmounts mounted directory from server.
# usage:
#     cleanup
# return value:
#     (it doesn't matter at all)

function cleanup
{
	[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

        # Unmount file system if it is mounted
        if grep $TESTDIR /etc/mnttab >/dev/null; then
                # Unmount it
                umountit "$TESTDIR" 1>$ERRLOG 2>&1
                ckreturn $? "could not unmount $TESTDIR" $ERRLOG "WARNING"

                if [ $? -ne 0 ]; then
                        # try again to forcibly unmount it
                        umount -f "$TESTDIR" 1>$ERRLOG  2>&1
                        ckreturn $? "could not unmount $TESTDIR forcibly" \
                            $ERRLOG "WARNING"
                fi
        fi

        # Remove mount point if file system has been umounted
        if ! grep $TESTDIR /etc/mnttab >/dev/null; then
                rm -fr "$TESTDIR" 1>$ERRLOG 2>&1
                ckreturn $? "could not remove $TESTDIR" $ERRLOG "WARNING"
        fi

	# remove log file
	rm -f $ERRLOG
        ckreturn $? "could not remove $ERRLOG" /dev/null "WARNING"
}

# must run as root
EXEC=""
id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
        EXEC="/suexec"
fi

# mount shared directory
setup || exit $UNINITIATED

# Get lists of TCL and kornshell scripts
TESTLIST=${TESTLIST:-$(egrep -v "^#|^  *$" uidmapping.flist)}
TESTLIST_TCL=""
TESTLIST_SH=""
for t in $TESTLIST
do
	grep "^#\!.*bin/ksh" $t > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		TESTLIST_TCL="$TESTLIST_TCL $t"
	else
		TESTLIST_SH="$TESTLIST_SH $t"
	fi
done

# Start the tests with some information
echo " "
echo "Testing at CLIENT=[`uname -n`] to SERVER=[$SERVER]"
echo "Started UID MAPPING tests at [`date`] ..."
echo " "

# run TCL scripts
for t in $TESTLIST_TCL
do 
	${EXEC} ${TESTROOT}/nfsh $t
	st=$?
	if (( (st != PASS) && (st != FAIL) )); then
		echo "\n$t{remaining_tests}: unexpected tests termination"
		echo \
		  "\tTest $(rc2str $st): test $t terminated with status $st\n"
	fi
done

# run shell scripts
for t in $TESTLIST_SH
do 
	${EXEC} ./$t
	st=$?
	if (( (st != PASS) && (st != FAIL) )); then
		echo "\n$t{remaining_tests}: unexpected tests termination"
		echo \
		  "\tTest $(rc2str $st): test $t terminated with status $st\n"
	fi
done

echo " "
echo "Testing ends at [`date`]."
echo " "

exit 0
