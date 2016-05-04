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
# Control script to run all or user specified test suites
#
. $TESTROOT/nfs4test.env

[ -n "$DEBUG" ] && [ "$DEBUG" != "0" ] && set -x

NAME=`basename $0`
DIR=`dirname $0`

function usage
{
	echo "usage: runtests <tests>"
	echo "	tests:	-a=all tests listed below"
	echo "		-l=acl"
	echo "		-b=basic_ops"
	echo "		-n=num_attrs"
	echo "		-m=named_attrs"
	echo "		-o=other_tests"
	echo "		-s=srv_namespc"
	echo "		-r=recovery"
	exit 1
}

# runtests script requires an arguments to run.
# runtests requires "-a" option to run all tests.
# Or provide the associated option to run
# specific(s) tests. See usage message.
if [ $# -lt 1 ]; then
	usage
fi

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi
. $CONFIGFILE

# If using runtests script, set TESTDIR to directory
# test framework is installed in for testing purposes.
TESTDIR=`pwd`/../tests

# This will be expanded to include arguments to select
# new tests developed to test nfsv4
while getopts ablnmosr option
do
	case "$option"
        in
                a)      dirs="acl basic_ops num_attrs named_attrs \
				other_tests srv_namespc recovery" ;;
                b)      dirs="$dirs basic_ops"		;;
		l)	dirs="$dirs acl"		;;
		n)	dirs="$dirs num_attrs"		;;
		m)	dirs="$dirs named_attrs"	;;
		o)	dirs="$dirs other_tests"	;;
                r)      dirs="$dirs recovery"		;;
                s)      dirs="$dirs srv_namespc"	;;
                *)      usage
                        exit 1				;;
        esac
done

# Set the name of the test driver for all test suites
TDRIVER=`basename $0`

# This is where we want the logs to go
if [ ! -d ${LOGDIR} ]; then
	mkdir -m 777 -p ${LOGDIR} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "WARNING: unable to create $LOGDIR"
	fi
fi

# journal for setup was saved at father dir of LOGDIR
oldjnl=$(dirname $LOGDIR)/$(basename $JOURNAL_SETUP)
if [[ -f $oldjnl && $oldjnl_setup != $JOURNAL_SETUP ]]; then
	mv $oldjnl $JOURNAL_SETUP
	echo "Journal for setup is at: $JOURNAL_SETUP"
fi

echo ""
# Start the tests with some information
echo ""
echo "running tests:"
echo "--------------"
echo ""

# Create a general & summary LOG file for each test suite
function logs
{
	echo "  "
	echo "SUMMARY LOG :"
	echo "  $LOGDIR/${dir}/Summary.log"
	echo "Detail journal file is : "
	echo "  $LOGDIR/${dir}/journal.${dir}"
	echo " "

	cd $LOGDIR/${dir}
	# Remove Summary.log file from previous run
	rm -rf Summary.log
	nawk '
/^[\.\/a-zA-Z0-9\-_\|\+]+{[a-zA-Z0-9\-\+_]+}:[ \t]+/,/^[ \t]+T[eE][sS][tT][ \t]+[A-Z]+$/ {
	if ($1 ~ /^[\.\/a-zA-Z0-9\-_\|\+]+{[a-zA-Z0-9\-\+_]+}:/) {
                testname = $1
                sub(":$", "", testname)
        }

        if ($0 ~ /^[ \t]+T[eE][sS][tT][ \t]+[A-Z]+/) {
		resname = $2
		sub(":$","",resname)
		testlist[count++] = testname
                results[testname] = resname 
                rescount[resname]++
 }

        }
        END {
        print "\nSummary:"
	for (i=0; i < count; i++) {
		testname = testlist[i]
		resname = results[testname]
                print "\t" testname ": " resname
        }

                print "\nResult Total:"
                for (res in rescount) {
                        print "\t" res ": " rescount[res]
                }
        }' journal.${dir} > Summary.log

        cd $cur_dir
}
	
# Keep track of the current directory for cleanup purposes
cur_dir=$TESTDIR

# run the tests, one by one
for dir in $dirs; do
	if [ ! -d "${cur_dir}/${dir}" ]; then
		echo "ERROR: $dirs: no such directory"
		exit 1
	fi 

	# first, check to see if test driver there
	if [ ! -f ${TESTDIR}/${dir}/${TDRIVER} ]; then
		echo "ERROR: $dir/$TDRIVER not found"
		exit 1
	fi

	# create testdir log directory 
	if [ ! -d ${LOGDIR}/${dir} ]; then
        	mkdir -m 777 -p ${LOGDIR}/${dir} > /dev/null 2>&1
        	if [ $? -ne 0 ]; then
                	echo "ERROR: unable to create $LOGDIR/${dir}"
                	exit 1
        	fi
	fi

	touch $LOGDIR/${dir}/journal.${dir}
	if [ $? -ne 0 ]; then
		# if there's no log, don't bail out, just
		# print an error.  Run the test anyway
		echo "WARNING: could not create log file $LOGDIR/journal.${dir}"
	fi

	# run the test
	echo "$(date) : <$dir> ..."
	cd ${TESTDIR}/${dir}
	./${TDRIVER} > ${LOGDIR}/${dir}/journal.${dir} 2>&1
	logs
	if [ "0$RUNIT_LOOP" -gt 0 ]; then
		mv ${LOGDIR}/${dir}/journal.${dir} \
			${LOGDIR}/${dir}/journal.${dir}.${RUNIT_LOOP}
		mv ${LOGDIR}/${dir}/Summary.log \
			${LOGDIR}/${dir}/Summary.log.${RUNIT_LOOP}
	fi
done
