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
# Test wrapper for COMSTAR FC test
# FC switch is a must to run the test
# The following switch port variable need to be set
#
#	FC_TARGET_SWITCH_PORT 
#
# FC_TARGET_SWITCH_PORT=<FC Switch Model:FC Switch IP:Admin:Passwd:Port1,Port2>
# Example: FC_TARGET_SWITCH_PORT=QLOGIC:127.0.0.1:admin:password:1,2
#
# Initiator and free disks on target are required 
#
export TET_ROOT=/opt/SUNWstc-tetlite
export CTI_ROOT=$TET_ROOT/contrib/ctitools
export TET_SUITE_ROOT=/opt
export CTI_SUITE=$TET_SUITE_ROOT/comstar-tests
PATH=$PATH:$CTI_ROOT/bin
export PATH

usage() {
	echo "Usage: $0 ip switch disk"
	echo "Where"
	echo "    ip	Initiator IP address"
	echo "switch	In form of \"Model:IP:Admin:Passwd:port\""
	echo "  disk	c0t0d0s0 c0t1d0s0"
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
# At least one disk is required
#
if [ $# -lt 3 ]; then
	usage
fi

#
# Check heart beat on initiator exit if fails
#
INITIATOR=$1		# Initiator IP
ping $INITIATOR 5
if [ $? != 0 ]; then
	echo "Invalid IP address for Initiator"
	exit 1
fi

#
# Check FC HBA port mode on target and initiator
#
fcinfo hba-port|grep 'Port Mode'|nawk '{print $3}'|grep Target
Tres=$?
IHBA="fcinfo hba-port|grep 'Port Mode'|nawk '{print \$3}'|grep Initiator"
ssh $INITIATOR "$IHBA"
Ires=$?

if [ $Tres -ne 0 -o $Ires -ne 0 ]; then
	print Check FC HBA port configuration on the systems
	exit 1
fi

#
# FC switch
# There is no easy direct way to validate the switch info
# But test will fail if the info entered is not correct
#
FC_SW=$2
NF=`echo $FC_SW | nawk -F":" '{print NF}'`
if [ $NF -lt 5 ]; then
	echo "Invalid FC switch info"
	exit 1
fi

shift 2
DISKS=$@

#
# Initiator needs to have diskomizer package installed
#
ssh $INITIATOR ls /opt/SUNWstc-diskomizer/bin >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Need to install SUNWstc-diskomizer package on $INITIATOR"
	exit
fi

#
# FC target should have other port provider disabled
# to avoid unexpected test results
#
svcadm disable iscsi/target

#
# Construct block and raw devices
#
BLKDEVS=
RAWDEVS=
for d in $DISKS; do
	BLKDEVS="$BLKDEVS/dev/dsk/$d "
	RAWDEVS="$RAWDEVS/dev/rdsk/$d "
done

#
# Configure
#
# fc target host topology in fabric switch is a must
# QLOGIC and BROCADE fabric switches are supported
#
run_test -v FC_IHOST=$INITIATOR \
	-v "BDEVS=\"$BLKDEVS\"" \
	-v "RDEVS=\"$RAWDEVS\"" \
	-v FC_TARGET_SWITCH_PORT=$FC_SW \
	comstar-tests fc_configure

#
# To run the entire test suite
#
run_test comstar-tests fc

#
# To run individual scenarios (itadm iscsi_auth iscsi_discovery...etc)
#
# run_test comstar-tests fc/visible:1
# run_test comstar-tests fc/visible:1-2

#
# Unconfigure
#
run_test comstar-tests fc_unconfigure
