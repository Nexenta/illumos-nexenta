#!/usr/bin/ksh

#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#

#
# Copyright 2016 Nexenta Systems, Inc.  All rights reserved.
#

#
# Test wrapper for NFS v4 tests
#
# Define necessary environments and config variables here
#
export STF_SUITE=/opt/nfsv4-tests
export TESTROOT=$STF_SUITE/bin
export LANG=C

ALL="-a -l -b -n -m -o -s -r"	# valid tests
Tests="-a	all
	-l	acl tet.ksht
	-b	basic ops test
	-n	num_attrs test
	-m	named_attrs test
	-o	other tests
	-s	srv namespc test
	-r	recovery test
"

#
# Option is passed to the actual run script
#
usage() {
	echo "Usage: $0 ip test"
	echo "Where"
	echo "   ip	nfs server IP address"
	echo "   test	has to be one of the following options:"
	echo
	echo "      	$Tests"
	echo "      	If not specified, run all"	
	exit 1
}

#
# Must be run by root
#
if [ `id -u` -ne 0 ]; then
	echo Must run by root
	exit 1
fi

#
# IP is a must and is $1
#
if [ $# -lt 1 ]; then
	usage
fi

SERVER=$1
ping $SERVER 5
if [ $? != 0 ]; then
	echo Invalid nfs server is specified
	exit 1
fi
export SERVER

shift
TEST=$@

#
# Bail out if an invalid test is specified
# No test specified == run all
#
if [ -z "$TEST" ]; then
	TEST='-a'	# Run all tests
elif [ "${ALL#*$TEST}" = "$ALL" ]; then
	usage
fi

#
# Setup the server and client
#
./go_setup

#
# Run the test, run all if TEST is -a
#
./runtests $TEST

#
# Cleanup
#
./go_cleanup
