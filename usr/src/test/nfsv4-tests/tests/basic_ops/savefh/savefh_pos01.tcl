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
# NFSv4 SAVEFH operation test - positive tests

# include all test enironment
source SAVEFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic Savefh with CFH retains its value, expect OK
set expcode "OK"
set ASSERTION "basic Savefh with CFH retains its value, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Getfh}]
set cont [ckres "Savefh" $status $expcode $res $FAIL]
# verify filehandle remains the same
  set nfh [lindex [lindex $res 2] 2]
  fh_equal $bfh $nfh $cont $PASS


# b: Savefh more than Once, expect OK
set expcode "OK"
set ASSERTION "Savefh more than Once, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Lookup $env(DIR0711); Getfh;
	Savefh; Putfh $bfh; Restorefh; Getfh}]
set cont [ckres "Savefh" $status $expcode $res $FAIL]
# verify filehandle returned was the saved FH
  set sfh [lindex [lindex $res 3] 2]
  set nfh [lindex [lindex $res 7] 2]
  fh_equal $sfh $nfh $cont $PASS


# c: Savefh of ROOT-FH, expect OK
set expcode "OK"
set ASSERTION "Savefh of root-FH, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set tdir "$BASEDIRS $env(DIR0711)"
set tdir "$BASEDIRS $env(DIR0711)"
set res [compound {Putrootfh; Getfh; Savefh; foreach c $tdir {Lookup $c};
        Restorefh; Getfh; foreach c $tdir {Lookup $c}}]
set cont [ckres "Savefh" $status $expcode $res $FAIL]
# verify filehandle restored was the saved FH
  set sfh [lindex [lindex $res 1] 2]
  set nfh [lindex [lindex $res [expr [llength $tdir] + 4]] 2]
  fh_equal $sfh $nfh $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
