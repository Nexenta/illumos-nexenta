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
# NFSv4 VERIFY operation test - positive tests
#	verify verify with supported_attrs

# include all test enironment
source VERIFY.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set req_attrs "type fh_expire_type change size link_support
    symlink_support named_attr fsid unique_handles lease_time"

# Start testing
# --------------------------------------------------------------
# a: Verify of a file w/its FH, expect OK
set expcode "OK"
set ASSERTION "Verify of a file w/its FH, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;
	Verify {{type reg}}}]
set cont [ckres "Verify" $status $expcode $res $FAIL]
# try FH again:
  set fh1 [lindex [lindex $res 2] 2]
  set res [compound {Putfh $fh1; Verify {{filehandle "$fh1"}}; Getfh}]
  set cont [ckres "Verify" $status $expcode $res $FAIL]
# verify FH is not changed after successful Verify op
  set fh2 [lindex [lindex $res 2] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Verify a file w/list of attrs, all same from Getattr, expect OK
set expcode "OK"
set ASSERTION "Verify a file w/same attr list from Getattr, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getattr "$req_attrs"}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# Verify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getfh;
		Verify {$attrl}; Getfh}]
	set cont [ckres "Verify" $status $expcode $res $FAIL]
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Verify a dir w/list of attrs, all same from Getattr, expect OK
set expcode "OK"
set ASSERTION "Verify a dir w/same attr list from Getattr, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set mylist "type symlink_support lease_time filehandle mode owner time_access time_modify"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getattr "$mylist"}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# Verify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
		Verify {$attrl}; Getfh}]
	set cont [ckres "Verify" $status $expcode $res $FAIL]
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
