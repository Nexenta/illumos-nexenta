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
# NFSv4 PUTFH operation test - positive tests

# include all test enironment
source PUTFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: basic putfh - put cfh got from Getfh, expect OK
set expcode "OK"
set ASSERTION "Putfh cfh got from Getfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh}]
set cont [ckres "Putfh" $status $expcode $res $UNINITIATED]
if {! [string equal $cont "false"]} {
    set fh1 [lindex [lindex $res 2] 2]
    set res2 [compound {Putfh $fh1; Getfh}]
    set fh2 [lindex [lindex $res2 1] 2]
    # Now verify - both filehandles should be same
    fh_equal $fh1 $fh2 $cont $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
