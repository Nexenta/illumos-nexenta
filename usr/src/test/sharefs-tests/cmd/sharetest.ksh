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
PATH=$PATH:$CTI_ROOT/bin:/opt/SUNWstc-genutils/bin
export PATH
export SCRATCH_DIR=/var/tmp

#
# Test suite wide configurations
#
export report_only="FALSE"
export verbose="FALSE"
export setup_once="TRUE"

export TESTDIR=/share_tests # no default as promised so set here
#export ZFSPOOL=
#export SHR_TMPDIR=         # default to /var/tmp/share

#
# Configure the test by using run_test (see README)
#
run_test sharefs-tests configure

#
# To run entire suite
#
run_test -U /var/tmp/test_results/sharefs-tests sharefs-tests $1

#
# To run component sharemgr
#
#run_test sharefs-tests sharemgr

#
# To run individual testcase
#
#run_test sharefs-tests sharemgr/create:3

#
# Start with clean test environment
#
run_test sharefs-tests unconfigure
