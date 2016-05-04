#!/usr/bin/ksh -p
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
# dom_env.sh - this file sets up script execution environment for domain
# test scripts. It does the following:
#
#	1) source $CONFIGFILE $TESTROOT/{libsmf.sh, testsh} files
#	2) source ./dom_functions file
#	3) define variables that can be used by domain testcases.
# 
# The file is expected to be sourced by all domain testscripts.

[[ -n "$DEBUG" ]] && [[ $DEBUG != 0 ]] && set -x

# Note that since the file is supposed to be included by test scripts, 
# $NAME variable below actually holds the value of the test script which 
# include this file.
NAME=$(basename $0)
CDIR=$(pwd)
TESTROOT=${TESTROOT:-"$CDIR/../../"}

# sourcing framework global environment variables created after go_setup
# and for this purpose only this file should be sourced
CONFIGFILE=/var/tmp/nfsv4/config/config.suite
if [[ ! -f $CONFIGFILE ]]; then
	echo "$NAME: CONFIGFILE[$CONFIGFILE] not found;"
	echo "\texit UNINITIATED."
	exit 6
fi

for i in $CONFIGFILE \
	 $TESTROOT/libsmf.sh \
	 $TESTROOT/testsh \
	 ./dom_functions
do
	. $i
	[[ $? != 0 ]] && echo "$NAME: failed to source $i;" \
	    && echo "\texit UNINITIATED." \
	    && exit $UNINITIATED
done

#
# Varibles
#

LOGFILE=$TMPDIR/$NAME.$$.log
TMPFILE=$TMPDIR/$NAME.$$.tmp
TIMEOUT=60
