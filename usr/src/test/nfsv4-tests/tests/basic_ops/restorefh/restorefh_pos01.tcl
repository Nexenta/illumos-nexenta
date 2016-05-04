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
# NFSv4 RESTOREFH operation test - positive tests

# include all test enironment
source RESTOREFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic Restorefh after Lookup, expect OK
set expcode "OK"
set ASSERTION "basic Restorefh after Lookup, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Lookup $env(TEXTFILE); 
	Restorefh; Getfh}]
set cont [ckres "Restorefh" $status $expcode $res $FAIL]
# verify filehandle returned was the saved FH
  set nfh [lindex [lindex $res 4] 2]
  fh_equal $bfh $nfh $cont $PASS


# b: Restorefh used for post-op attr, expect OK
set expcode "OK"
set tdir "Restorefh_tdir.[pid]"
set ASSERTION "Restorefh after Create, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Savefh; Getfh
	Create $tdir {{mode 0755}} d; Restorefh; Remove $tdir; Getfh}]
set cont [ckres "Restorefh" $status $expcode $res $FAIL]
#putmsg stderr 1 "\t res=($res)"
# verify filehandle returned was the saved FH
  set sfh [lindex [lindex $res 3] 2]
  set nfh [lindex [lindex $res 7] 2]
  fh_equal $sfh $nfh $cont $PASS


# c: Restorefh of ROOT-FH, expect OK
set expcode "OK"
set ASSERTION "Restorefh of root-FH, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putrootfh; Getfh; Savefh; Putfh $bfh; Restorefh; Getfh}]
set cont [ckres "Restorefh" $status $expcode $res $FAIL]
#putmsg stderr 1 "\t res=($res)"
# verify filehandle returned was the saved FH
  set sfh [lindex [lindex $res 1] 2]
  set nfh [lindex [lindex $res 5] 2]
  fh_equal $sfh $nfh $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
