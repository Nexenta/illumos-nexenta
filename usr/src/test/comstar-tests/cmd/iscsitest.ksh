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
# Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
#

#
# Define necessary environments and config variables here
# prior to invoke TET test runner 'run_test'
#
# Test wrapper for COMSTAR iSCSI tests
#
# Initiator and free disks on target are required 
# Two additional NIF are required on both target and initiator
#
export TET_ROOT=/opt/SUNWstc-tetlite
export CTI_ROOT=$TET_ROOT/contrib/ctitools
export TET_SUITE_ROOT=/opt
export CTI_SUITE=$TET_SUITE_ROOT/comstar-tests
PATH=$PATH:$CTI_ROOT/bin
export PATH

usage() {
	echo "Usage: $0 ip disk"
	echo "Where"
	echo "   ip	Initiator IP address"
	echo "   disk	c0t0d0s0 c0t1d0s0"
	exit 1
}

#
# Must be run by root
#
if [ `id -u` -ne 0 ]; then
	echo Must run by root
	exit 1
fi

if [ $# -lt 1 ]; then
	usage
fi

#
# Heart beat check on initiator exit if fails
#
INITIATOR=$1		# Initiator IP
ping $INITIATOR 5
if [ $? != 0 ]; then
	echo "Invalid IP address for Initiator"
	exit 1
fi

shift
DISKS=$@

if [ `echo $DISKS|wc -w` -lt 3 ]; then
	echo "At least three free disk slices are required"
	exit 1
fi

#
# Two additional nif are needed
#
IFC="ifconfig -a|egrep -v 'ether|inet|ipib|lo0' | cut -d: -f1|sort -u|wc -w"
Lnif=`eval $IFC`
Rnif=`ssh $INITIATOR "$IFC"`

if [ $Lnif -lt 3 -o $Rnif -lt 3 ]; then
	echo "Two additional network interfaces are required for testing"
	exit 1
fi

#
# Initiator needs to have diskomizer package installed
#
ssh $INITIATOR ls /opt/SUNWstc-diskomizer/bin >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Need to install SUNWstc-diskomizer package on $INITIATOR"
	exit
fi

#
# Required configurations
#
HOST=`hostname`
TRANS=SOCKETS	# SOCKETS or ALL can be specified
TARG=`getent hosts $HOST|awk '{print $1}'`	# Target IP
ISNS=$Target		# We don't support iSNS, use target IP
BLKDEVS=
RAWDEVS=

#
# Construct block and raw devices
#
for d in $DISKS; do
	BLKDEVS="$BLKDEVS/dev/dsk/$d "
	RAWDEVS="$RAWDEVS/dev/rdsk/$d "
done

#
# Configure
#
run_test -v TRANSPORT=$TRANS \
	-v ISCSI_THOST=$TARG \
	-v ISCSI_IHOST=$INITIATOR \
	-v ISNS_HOST=$ISNS \
	-v "BDEVS=\"$BLKDEVS\"" \
	-v "RDEVS=\"$RAWDEVS\"" comstar-tests iscsi_configure

#
# To run the entire test suite
#
run_test comstar-tests iscsi

#
# To run individual scenarios (itadm iscsi_auth iscsi_discovery...etc)
#
# run_test comstar-tests iscsi/auth:1
# run_test comstar-tests iscsi/auth:1-2
#

#
# Unconfigure
#
run_test comstar-tests iscsi_unconfigure
