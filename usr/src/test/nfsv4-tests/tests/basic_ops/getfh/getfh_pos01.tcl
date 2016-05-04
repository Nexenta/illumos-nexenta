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
# NFSv4 GETFH operation test - positive tests

# include all test enironment
source GETFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic getfh after Lookup, expect OK
set expcode "OK"
set ASSERTION "basic Getfh after Lookup, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(TEXTFILE)"; Getfh}]
set cont [ckres "Getfh" $status $expcode $res $FAIL]
# Now verify filehandle returned is new 
  set nfh [lindex [lindex $res 2] 2]
  if { [fh_equal $bfh $nfh $cont $FAIL] } {
	putmsg stderr 0 "\t Test FAIL: new FH was not changed."
	putmsg stderr 1 "\t   nfh=($nfh)"
	putmsg stderr 1 "\t   bfh=($bfh)"
	putmsg stderr 1 "  "
  } else {
	logres PASS
  }


# b: basic getfh after Create, expect OK
set expcode "OK"
set tdir "getfh_tdir.[pid]"
set ASSERTION "basic Getfh after Create, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Create "$tdir" {{mode 0700}} d; Getfh}]
set cont [ckres "Getfh" $status $expcode $res $FAIL]
# Now verify filehandle returned is good
  verf_fh [lindex [lindex $res 2] 2] $cont $PASS


# c: basic getfh after Putrootfh, expect OK
set expcode "OK"
set ASSERTION "basic Getfh after Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putrootfh; Getfh}]
set cont [ckres "Getfh" $status $expcode $res $FAIL]
# Now verify filehandle returned is good
  verf_fh [lindex [lindex $res 1] 2] $cont $PASS


# d: basic getfh after Putpubfh, expect OK
# This test assume $SERVER have 'public' filesystem exported.
set expcode "OK"
set ASSERTION "basic Getfh after Putpubfh, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putpubfh; Getfh}]
set cont [ckres "Getfh" $status $expcode $res $FAIL]
# Now verify filehandle returned is good
  verf_fh [lindex [lindex $res 1] 2] $cont $PASS


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp dir $tdir
set res [compound {Putfh $bfh; Remove $tdir}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
