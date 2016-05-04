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
# runit: Executes go_setup, runtests control script
# to run the tests, and go_cleanup scripts.
#

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`dirname $0`

function usage {
echo "usage: runit <test subdir> [-t loop-time, default=1]" 
echo "		-a=all tests listed below"
echo "		-t=number of times to loop the tests, except '-r'"
echo "		-l=acl"
echo "		-b=basic_ops"
echo "		-n=num_attrs"
echo "		-m=named_attrs"
echo "		-o=other_tests"
echo "		-r=recovery"
echo "		-s=srv_namespc"
exit 1
}

# Execute the tests; LOOPIT is set to run
# once by default. To modify number of times  
# to loop tests, user must specify using
# "-t <# to loop tests>" option in runit.
LOOPIT=1
ARGS=""
while getopts "ablnmorst:" options
do
	case $options in
		a) ARGS="$ARGS -a";;
		b) ARGS="$ARGS -b";;
		l) ARGS="$ARGS -l";;
		n) ARGS="$ARGS -n";;
		m) ARGS="$ARGS -m";;
		o) ARGS="$ARGS -o";;
		r) ARGS="$ARGS -r";;
		s) ARGS="$ARGS -s";;
		t) LOOPIT=$OPTARG;;
		*) usage;;
	esac
done
shift `expr $OPTIND - 1`

[ $# -eq 0 ] && [ -z "$ARGS" ] && usage

recovery=0
# run all options?
res=`echo $ARGS | grep 'a' 2>&1`
if [ $? -eq 0 ]; then
	recovery=1
	# NOTE, these "blnmos" are the current options different from recovery
	#	this list need to be updated if any other option is added
	#	or if any option letter is changed
	ARGS="-blnmos"
fi

# run recovery tests independently from the rest 
res=`echo $ARGS | grep 'r' 2>&1`
if [ $? -eq 0 ]; then
	recovery=1
	ARGS=`echo $ARGS | sed 's/-r//g'`
fi

#Sourcing framework Global environment variables
ENVFILE="./nfs4test.env"
if [ ! -f $ENVFILE ]; then
        echo "$NAME: ENVFILE[$ENVFILE] not found;"
        echo "\texit UNINITIATED."
        exit 6 
fi
. $ENVFILE

# This is where we want the logs to go
if [ ! -d ${LOGDIR} ]; then
	mkdir -m 777 -p $LOGDIR > /dev/null 2>&1
	if (( $? != 0 )); then
		echo "WARNING: unable to create $LOGDIR"
		exit 6
	fi
fi

# Go setup the server with exported filesystem and 
# files/directories for testing purposes.
JOURNAL_SETUP=$LOGDIR/journal.setup
JOURNAL_CLEANUP=$LOGDIR/journal.cleanup
echo "Setting up test systems CLIENT<$(uname -n)> & SERVER<$SERVER>," 
echo "\tit could take a few minutes..." 
> $JOURNAL_SETUP
su root -c "./go_setup" >> $JOURNAL_SETUP 2>&1
if [ $? -ne 0 ]; then
	cat $JOURNAL_SETUP
	echo "ERROR: go_setup failed to setup systems"
	echo "\ttrying to cleanup the partial setup" 
	> $JOURNAL_CLEANUP
	su root -c "./go_cleanup" >> $JOURNAL_CLEANUP 2>&1
	[ -n "$DEBUG" ] && [ "$DEBUG" = "1" ] && \ 
		cat $JOURNAL_CLEANUP
	exit 1
fi
cat $JOURNAL_SETUP

LOOPF=0
# Execute any requested tests other than recovery
if [ $LOOPIT -gt 1 ]; then
	[ "$recovery" = "1" ] && echo \
	    "Recovery tests will be executed only once, the rest $LOOPIT times"
	LOOPF=1
fi

if [ -n "$ARGS" ];then 
	i=1
	while : 
	do
		echo Runtests pass $i
		[ "$LOOPF" -eq 1 ] && export RUNIT_LOOP=$i
		./runtests $ARGS "$@"
		if [ $i -eq $LOOPIT ]; then
			break;
		fi
		i=`expr $i + 1`
	done
fi

[ "$recovery" = "1" ] && ./runtests -r "$@"

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# Go cleanup server files/directories, and unshare $BASEDIR
# If NOCLEANUP is set to non-zero, DONNOT run go_cleanup
if [ -z "$NOCLEANUP" -o "$NOCLEANUP" = "0" ]; then
	echo "Journal for cleanup is at: $JOURNAL_CLEANUP"
	> $JOURNAL_CLEANUP
	su root -c "./go_cleanup" >> $JOURNAL_CLEANUP 2>&1
	if [ $? -ne 0 ]; then
   		echo "ERROR: go_cleanup failed to cleanup $SERVER"
		cat $JOURNAL_CLEANUP
   		exit 1
	fi
	cat $JOURNAL_CLEANUP
fi
