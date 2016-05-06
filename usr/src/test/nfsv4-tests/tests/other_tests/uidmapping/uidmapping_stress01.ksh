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

#
# This test creates a big number of files on a directory X in the server.
# Then spawns a process that kills and restarts nfsmapid on the client.
# and creates a number of processes that do "ls -l" on test directory
# over nfs Simultaneously.
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=${0##*/}
CDIR=`pwd`

id | grep "0(root)" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "$NAME{init}: Initialization"
	echo "\t Test UNINITIATED: must be root to run testcase"
	exit $UNINITIATED
fi

# Default of 1K iterations and 600 files and 10 processes
STRESS_LOOP=${1:-1000}
NUM_FILES=${2:-600}
NUM_PROC=${3:-10}

UIDMAPENV="./uid_proc"
UNINITIATED=6

# set up script running environment
if [ ! -f $UIDMAPENV ]; then
        echo "$NAME: UIDMAPENV[$UIDMAPENV] not found; test UNINITIATED."
        exit $UNINITIATED
fi
. $UIDMAPENV

# Also include common STC utility functions for SMF/Greenline
. $TESTROOT/libsmf.shlib

# This is the test directory for the files to be created/stat
MYTESTDIR="$MNTPTR/$NAME"

function cleanup
{
	[ "$DEBUG" != "0" ] && set -x
	(( $# >= 1 )) && ret=$1

	# stop all child processes
	n=0
	while (( n < NUM_PROC ))
	do
		p="0${APIDs[$n]}"
		(( p > 1 )) && kill ${APIDs[$n]} > /dev/null 2>&1
		(( n = n + 1 ))
	done

	# remove compiled program
	execute $SERVER root "cd $TMPDIR; rm -f create_mapid_files*" \
		> /dev/null 2>&1

	# remove test directory and tmp files
	rm -rf $MYTESTDIR $TMPDIR/$NAME.*.$$ > /dev/null 2>&1

	exit $ret
}
 

# Start main program here:
# ---------------------------------------------------------------------------
echo "$NAME{1}: looping ls tests in $MYTESTDIR,"
echo "\t while nfsmapid is being killed/restarted\n"
echo "\t START TIME: `date`\n"

# use the suite mounted directory to create the testdir
if [[ ! -d "$MYTESTDIR" ]]; then
        mkdir -m 777 $MYTESTDIR> $TMPDIR/$NAME.mkdir.$$ 2>&1
	if (( $? != 0 )); then
		echo "\t Test UNINITIATED: cannot create test dir $MYTESTDIR"
		cat $TMPDIR/$NAME.mkdir.$$
		exit $UNINITIATED
	fi
fi

# copy C program to server
rcp -p $CDIR/create_mapid_files.c $SERVER:$TMPDIR > $TMPDIR/$NAME.rcp.$$ 2>&1
if (( $? != 0 )); then
	echo "\t Test UNINITIATED: cannot copy files to $SERVER:$TMPDIR"
        echo "\tres = "
        cat $TMPDIR/$NAME.rcp.$$
        cleanup $UNINITIATED
fi

# compile the files creation program on the server
CS=$CC_SRV
cmd="cd $TMPDIR; $CS create_mapid_files.c -o create_mapid_files"
sh -c "$cmd"
scp $TMPDIR/create_mapid_files root@$SERVER:$TMPDIR > $TMPDIR/$NAME.rshcs.$$ 2>&1
if (( $? != 0 )); then
	echo "\t Test UNINITIATED: \c"
	echo "cannot scp to $SERVER:$TMPDIR/create_mapid_files"
        echo "\tres = "
        cat $TMPDIR/$NAME.rshcs.$$
        cleanup $UNINITIATED
fi

cmd="cd $BASEDIR/$NAME; $TMPDIR/create_mapid_files -n $NUM_FILES"
[[ "$DEBUG" != "0" ]] && cmd="$cmd -d 1"
execute $SERVER root "$cmd" > $TMPDIR/$NAME.rshrun.$$  2>&1
if [ "$?" != "0" ]; then
	echo "\t Test UNINITIATED: \c"
        echo "create_mapid_files cannot create files in"
	echo "\t$SERVER:$BASEDIR/$NAME."
	echo "\tres = "
	cat $TMPDIR/$NAME.rshrun.$$
	cleanup $UNINITIATED
fi

# name of the nfsmapid service
nfs_mapid="svc:/network/nfs/mapid:default"

# process to restart mapid service repeatedly on the background
(
	logfile=$TMPDIR/$NAME.daemon_out.$$
	exitfile=$TMPDIR/$NAME.daemon_exit.$$

	while :
	do
	    smf_fmri_transition_state do $nfs_mapid disabled 10 > $logfile
	    ckreturn $? "failed to disable mapid service" $logfile WARNING
	    sleep 6
	    smf_fmri_transition_state do $nfs_mapid online 10 > $logfile
	    ckreturn $? "failed to enable mapid service" $logfile WARNING
	    sleep 6
	    # if the file below is created, exit 
	    if [[ -f $exitfile ]]; then
		break
	    fi
	done
	rm -f $logfile $exitfile
)&
deamonMgmt_pid=$!

cd $MYTESTDIR

# Start the processes
n=0
while (( n < NUM_PROC ))
do
	(
	# repeat many ls -l over nfs
	i=0
	while (( i < STRESS_LOOP ))
	do
		echo "Process ${n} Loop ${i}"
		ls -lR > $TMPDIR/$NAME.$n.out.$$ 2> $TMPDIR/$NAME.$n.err.$$
		if [ $? -ne 0 ]; then
			echo "ERROR: Could not ls -lR $MYTESTDIR, i=$i"
			nlines=10
			echo "\tlast $nlines lines printed were"
			tail -$nlines $TMPDIR/$NAME.$n.out.$$
			echo "\tstderr was"
			cat $TMPDIR/$NAME.$n.err.$$
			rm -f $TMPDIR/$NAME.$n.*.$$
		else
			rm -f $TMPDIR/$NAME.$n.*.$$
		fi
	
		(( i = i + 1 ))
	done
	) > $TMPDIR/$NAME.$n.$$ 2>&1 &
	APIDs[$n]=$!
	(( n = n + 1 ))
done

cd $CDIR

# wait for all processes to be done, and check and print logs on errors
n=0
e=0
while (( n < NUM_PROC ))
do
	wait ${APIDs[$n]}
	grep ERROR $TMPDIR/$NAME.$n.$$ 2>&1 > /dev/null
	if [ $? -eq 0 ]; then
		cat $TMPDIR/$NAME.$n.$$
		e=1
	fi
	rm -f $TMPDIR/$NAME.$n.$$
	(( n = n + 1 ))
done
(( e != 0)) && echo "\t Test FAIL: error found from some process(es)"

touch $TMPDIR/$NAME.daemon_exit.$$
wait $deamonMgmt_pid

echo "\t Test PASS: test run completed successfully"
echo "\t END TIME: `date`\n"

cleanup $PASS
