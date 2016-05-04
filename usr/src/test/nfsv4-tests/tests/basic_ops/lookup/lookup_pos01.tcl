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
# NFSv4 LOOKUP operation test - positive tests

# include all test enironment
source LOOKUP.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic lookup of a regular file, expect OK
set expcode "OK"
set ASSERTION "basic Lookup of a regular file, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(TEXTFILE)"; Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]
# Now verify - filehandle from LOOKUP should be good
verf_fh [lindex [lindex $res 2] 2] $cont $PASS


# b: lookup a non-regular file from putfh, expect OK
set expcode "OK"
set tpath "$env(SYMLDIR)"
set ASSERTION "Lookup a non-regular file from putfh, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]
# Now verify - filehandle from LOOKUP should be good
verf_fh [lindex [lindex $res 2] 2] $cont $PASS


# c: multiple lookups for a long dir, export OK
set expcode "OK"
set ASSERTION "multiple lookups for a long dir, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set LONGDIRS [path2comp $env(LONGDIR) $DELM]
set res [compound {Putfh $bfh; foreach c $LONGDIRS {Lookup $c}; Getfh}]
ckres "Lookup" $status $expcode $res $FAIL
# Now verify filehandle returned is good
verf_fh [lindex [lindex $res end] 2] $cont $PASS


# d: Lookup same dir after lookupp, expect OK
set expcode "OK"
set ASSERTION "Lookup same dir after lookupp, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set d1 $env(DIR0777)
set res [compound {Putfh $bfh; Lookup $d1; Lookupp; Lookup $d1; Lookupp; Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]
set nfh [lindex [lindex $res 5] 2]
# the filehandle returned should be same as the FH for $BASEDIRS
fh_equal $bfh $nfh $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
