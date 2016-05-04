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
# NFSv4 ACCESS operation test - positive tests
#	verify access checking of directories with different mode 
#	using different bit masks

# include all test enironment
source ACCESS.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Access to a dir with RW-perm for all bits, expect OK
set expcode "OK"
set ASSERTION "Access a dir w/RW-perm for all bits, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
	Access rlmtdx; Getfh}]
set cont [ckres "Access" $status $expcode $res $FAIL]
# verify the access bits returned are expected="rlmtd"
  set acl [lindex [lindex [lindex [lindex $res 3] 2] 1] 1]
  set cont [ckaccess $acl "rlmtd" $cont $FAIL]
# verify FH is not changed after successful Access op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Access to a dir with RX-perm for all bits, expect OK
set expcode "OK"
set ASSERTION "Access a dir w/RX-perm for all bits, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0755); Getfh;
	Access rlmtdx; Getfh}]
set cont [ckres "Access" $status $expcode $res $FAIL]
# verify the access bits returned are expected="rlx"
  set acl [lindex [lindex [lindex [lindex $res 3] 2] 1] 1]
  set cont [ckaccess $acl "rl" $cont $FAIL]
# verify FH is not changed after successful Access op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Access to a dir with no-perm for all bits, expect OK
set expcode "OK"
set ASSERTION "Access a dir w/no-perm for all bits, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM); Getfh;
	Access rlmtdx; Getfh}]
set cont [ckres "Access" $status $expcode $res $FAIL]
# verify the access bits returned are expected=""
  set acl [lindex [lindex [lindex [lindex $res 3] 2] 1] 1]
  if {"$acl" != ""} {
	putmsg stderr 0 "\t Test FAIL: expected no access, got($acl)"
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "\t   exp=( )"
	putmsg stderr 1 " "
  } else {
	# verify FH is not changed after successful Access op
  	set fh1 [lindex [lindex $res 2] 2]
  	set fh2 [lindex [lindex $res 4] 2]
  	fh_equal $fh1 $fh2 $cont $PASS
  }


# d: Access to a symlink with R-X perm for 'rtx' bits, expect OK
set expcode "OK"
set ASSERTION "Access symlink w/R-X perm for 'rtx' bits, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLFILE); Getfh;
	Access rtx; Getfh}]
set cont [ckres "Access" $status $expcode $res $FAIL]
# verify the access bits returned are expected="rtx"
  set acl [lindex [lindex [lindex [lindex $res 3] 2] 1] 1]
  set cont [ckaccess $acl "rtx" $cont $FAIL]
# verify FH is not changed after successful Access op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# e: Access to a dir with EXECUTE (no meaning), expect OK
set expcode "OK"
set ASSERTION "Access a dir w/EXECUTE (no meaning), expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0755); Getfh;
	Access x; Getfh}]
set cont [ckres "Access" $status $expcode $res $FAIL]
# verify the access bits returned are expected=""
  set acl [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
  if {"$acl" != ""} {
	putmsg stderr 0 "\t Test FAIL: expected not supported, got($acl)"
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "\t   exp=( )"
	putmsg stderr 1 " "
  } else {
	# verify FH is not changed after successful Access op
	set fh1 [lindex [lindex $res 2] 2]
	set fh2 [lindex [lindex $res 4] 2]
	fh_equal $fh1 $fh2 $cont $PASS
  }


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
