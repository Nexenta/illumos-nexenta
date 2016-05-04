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
# NFSv4 PUTROOTFH operation test - positive tests

# include all test enironment
source PUTROOTFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0

# Start testing
# --------------------------------------------------------------
# a: basic putrootfh - make sure gets a cfh, expect OK
set expcode "OK"
set ASSERTION "Putrootfh to set cfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putrootfh; Getfh}]
set cont [ckres "Putrootfh" $status $expcode $res $FAIL]
# verify filehandle from PUTROOTFH should be good
verf_fh [lindex [lindex $res 1] 2] $cont $PASS


# b: use putrootfh to go back to root, expect OK
set expcode "OK"
set ASSERTION "Putrootfh to go back to root, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set tpath "$BASEDIRS $env(DIR0777)"
set res [compound {Putrootfh; Getfh; foreach c $tpath {Lookup $c};
	Putrootfh; Getfh}]
set cont [ckres "Putrootfh" $status $expcode $res $FAIL]
# verify filehandle from PUTROOTFH should be same
set fh1 [lindex [lindex $res 1] 2]
set fh2 [lindex [lindex $res end] 2]
fh_equal $fh1 $fh2 $cont $PASS


# c: putrootfh as cfh to later go back
set expcode "OK"
set ASSERTION "Putrootfh as cfh to later go back, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set tpath "$BASEDIRS [path2comp $env(LONGDIR) $DELM]"
set res [compound {Putrootfh; Getfh}]
set cont [ckres "Putrootfh" $status $expcode $res $FAIL]
# verify filehandle from PUTROOTFH should be good
set fh1 [lindex [lindex $res 1] 2]
set res [compound {Putrootfh; foreach c $tpath {Lookup "$c"};
	Putfh $fh1; Getfh}]
set fh2 [lindex [lindex $res end] 2]
fh_equal $fh1 $fh2 $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
