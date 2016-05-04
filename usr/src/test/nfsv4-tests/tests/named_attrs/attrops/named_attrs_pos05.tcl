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
# Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 named attributes:
#
# a: Test READ of named attrs after call to Openattr, expect OK
#

set TESTROOT $env(TESTROOT)

# include common code and init section
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]

source READ_proc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Get the size of the $ATTRDIR_AT1 file
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr f; Getfh; Lookup $env(ATTRDIR_AT1); Getfh; Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 6] 2] 0] 1]
set tfh [lindex [lindex $res 3] 2]

# Start testing
# ------------------------------------------------------------------------
# a: Test READ of named attrs after call to Openattr, expect OK

set ASSERTION "Test READ of named attrs after call to Openattr, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Do the read on the attrdir file

set count 8192
ckread $tfh $env(ATTRDIR_AT1) 0 $count $expcode $fsize $PASS

Disconnect 
exit 0
