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
# start multiple nfsh scripts on background to generate simultaneous
# SETATTR requests
#
# Usage: 
#    uidmapping_stress02 <number_of_process>  <number_of_requests_per_process>
#       number_of_process - number of send_setattr_reqs process. 60 by default
#       number_of_requests_per_process - number of SETATTR sent by each 
#                                        process. 400 by default

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=${0##*/}
CDIR=`pwd`

UIDMAPENV="./uid_proc"
UNINITIATED=6

# set up script running environment
if [ ! -f $UIDMAPENV ]; then
        echo "$NAME: UIDMAPENV[$UIDMAPENV] not found; test UNINITIATED."
        exit $UNINITIATED
fi
. $UIDMAPENV

NUM_OF_PROCS=${1:-60}
NUM_OF_REQS=${2:-400}
TESTDIR="$ZONE_PATH/$NAME"

function setup
{
        # Create mount point directory
        mkdir -p "$TESTDIR" 2>$ERRLOG
        ckreturn $? "failed to create $TESTDIR" $ERRLOG "ERROR" || \
            return 1

        # Mount file system shared with root access("anon=0" option)
        mountit "$SERVER" "$ROOTDIR" "$TESTDIR" 4 1>$ERRLOG 2>&1
        ckreturn $? "failed to mount directory." $ERRLOG "ERROR"
	if [ $? -ne 0 ]; then
            rm -rf $TESTDIR
            return 1
        fi

	# Create test files
	typeset -i x=1
	while (( $x <= $NUM_OF_PROCS ))
	do
		echo "test file for nfsmapid stress test" > $TESTDIR/mapid.$$.$x
		if [[ ! -f $TESTDIR/mapid.$$.$x ]]; then
			echo "\t Test UNINITIATED: \c"
			echo "failed to create $TESTDIR/mapid.$$.$x file"
			cleanup $UNINITIATED
		fi
		x=$(($x+1))
	done
}

function cleanup {
	echo "\t END TIME: `date`"

	# Remove test files
	#
	# Although removing files doesn't use nfsmapid service directly, it 
        # actually need that. The reason is when accesing a directory or a
	# file, Solaris performs access permission checking, which in turn 
	# need nfsmapid service. For this reason, the following command may
	# hang if nfsmapid service is stressed:
	#
	# 	rm -f $TESTDIR/mapid.$$.$x
	#
	# Instead it is better to use the following r-command in this case.
	#
	execute $SERVER root "rm -f $ROOTDIR/mapid.$$.*"

        # Unmount file system
        umountit "$TESTDIR" 1>$ERRLOG 2>&1
        ckreturn $? "failed to unmount $TESTDIR" $ERRLOG "WARNING"

        # remove mount point 
        rm -rf $TESTDIR 1>$ERRLOG 2>&1
        ckreturn $? "failed to remove $TESTDIR" $ERRLOG "WARNING"

	# remove temporary files
	rm -f $TMPDIR/$NAME.$$.* 

	exit $1
}

# must run as root
is_root $NAME "NFSv4 mapid stress test"

setup || exit $UNINITIATED

echo "$NAME{1}: generating simultaneous kernel upcall to stress nfsmapid\n"
echo "\t START TIME: `date`"

# export the common domain for the test
Cdomain=$(cat /var/run/nfs4_domain)

# Start children processes to stress nfsmapid
x=1
while [ $x -le $NUM_OF_PROCS ]
do 
	# start the x-th instance of send_setattr_reqs.tcl
	$TESTROOT/nfsh send_setattr_reqs $ROOTDIR/mapid.$$.$x $NUM_OF_REQS \
             >$TMPDIR/$NAME.$$.$x 2>&1 &

        # record the child's pid
	pid_list[$x]=$!

	x=$(($x+1))
done

[ "$DEBUG" -eq "1" ] && echo "$NUM_OF_PROCS processes started: ${pid_list[*]}"

# Check if the server is overcome by the requests from the client.
#
# For each rpc call, there is a timer associated with it. If the client
# doesn't get reply from server and the timer expires, the rpc call fails.
# In that case, Solaris nfs client will keep trying until that it succeeds.
# If the server keeps not responding, the client hangs.(notes: a simple 
# experiment shows the default timeout value of a rpc call on solaris is 
# 120 seconds)
#
# nfsh is different from Solaris nfs client in that it doesn't retry. Instead,
# the Compound command just fails and returns. That means, nfsh client never
# really hangs. In the worst situation(no reply from server), it exits after
# the rpc call timer expires.
#
# To check if the server works well with nfsh clients, we can check the clients'
# exit status. If a client gets reply from the server, it exits successfully.
# Otherwise, the RPC call timer expires and we think the client "hangs".
x=1
failed=0
while [ $x -le $NUM_OF_PROCS ]
do 
	# get the x-th child's pid
	pid=${pid_list[$x]}

	# wait until it exits and get its exit status
	wait $pid
        status=$?

	if [ "$status" != "0" ]; then
		if [ "$DEBUG" == "1" -o "$failed" == "0" ]; then
			echo "\nERROR: process $pid failed!"
			echo "------------- $TMPDIR/$NAME.$$.$x -------------"
			cat $TMPDIR/$NAME.$$.$x
			echo "-------------------- END ----------------------"
		fi
		failed=$(( failed + 1))
	fi

	x=$(($x+1))
done 

# Print all out log files in debug mode

if [ "$DEBUG" -eq "1" ]; then
	x=1
	while [ $x -le $NUM_OF_PROCS ]
	do
		echo "------------- $TMPDIR/$NAME.$$.$x -------------"
		cat $TMPDIR/$NAME.$$.$x
		echo "-------------------- END ----------------------"
		x=$(($x+1))
	done
fi


# Print test result

if [ "$failed" -eq 0 ]; then 
	echo "\t Test PASS: test run completed successfully"
	cleanup $PASS
else 
	echo "\t Test FAIL: Total <$failed> children processes failed"
	cleanup $FAIL
fi

