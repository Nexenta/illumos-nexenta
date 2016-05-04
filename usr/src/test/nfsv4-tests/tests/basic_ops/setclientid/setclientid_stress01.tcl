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
# NFSv4 stress test for Setclientid

# Get the TESTROOT directory; set to '.' if not defined
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0
set tag "$TNAME{1}"
set LOOP 10000

if { $argc > 0 } {
	set LOOP [lindex $argv 0]
}

putmsg stdout 0 "\n"
putmsg stdout 0 "$tag: looping $LOOP times on Setclientid/Setclient_confirm"
putmsg stdout 0 "\t START TIME: [clock format [clock seconds]]"


# connect to the test server
Connect


# Place the preparation of the test here
# --------------------------------------------------------------
# set unique and common string ids and verifiers

set common_id_string $env(USER)

set i 0

while { ${i} < $LOOP } {
    set id_string "$common_id_string-[clock clicks]"
    set clientid [getclientid $id_string]
    if {$clientid == -1} {
	putmsg stderr 0 "Test FAIL: failed to get clientid"
	putmsg stderr 0 "\t loop=$i"
	Disconnect
	exit $FAIL
    }
    incr i
}

putmsg stdout 0 "\t Test PASS: test run completed successfully"
putmsg stdout 0 "\t END TIME: [clock format [clock seconds]]"
putmsg stdout 0 "\n"

# Final cleanup (your cleanup stuffs can go here)
# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
