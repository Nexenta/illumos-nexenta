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
# Define necessary environments and config variables here
# prior to invoke TET test runner 'run_test'
#
export TET_ROOT=/opt/SUNWstc-tetlite
export CTI_ROOT=$TET_ROOT/contrib/ctitools
export TET_SUITE_ROOT=/opt
PATH=$PATH:$CTI_ROOT/bin
export PATH
export SCRATCH_DIR=/var/tmp

#
# Test needs to be run as root 
# Make sure /dev/lofi does not exist
#
if [ -d /dev/lofi ]; then
	rm -rf /dev/lofi
	if [$? != 0]; then
		echo Need to be run as root
		exit
	fi
fi

PATH=$PATH:$CTI_ROOT/bin
export PATH
#
# To run entire suite
#
run_test -U /var/tmp/test_results/lofi-tests lofi-tests $1

#
# To run component
#
#run_test lofi-tests compression_dynamic

#
# To run individual testcase
#
#run_test lofi-tests compression_dynamic:10
