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
# NFSv4 NVERIFY operation test - positive tests
#	verify nverify with supported_attrs

# include all test enironment
source NVERIFY.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set req_attrs "type fh_expire_type change size link_support
    symlink_support named_attr fsid unique_handles lease_time"

# Start testing
# --------------------------------------------------------------
# a: Nverify of a file w/attr=dir, expect OK
set expcode "OK"
set ASSERTION "Nverify of a file w/attr=dir, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;
	Nverify {{type dir}}; Getfh}]
set cont [ckres "Nverify" $status $expcode $res $FAIL]
# verify FH is not changed after successful Nverify op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Nverify a file w/list of attrs, but one not match, expect OK
set expcode "OK"
set ASSERTION "Nverify a file w/attr list, but one not match, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getattr "$req_attrs"}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# Nverify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# Let's change the "size"
	set si [lsearch -regexp $attrl "size .*"]
	set nal [lreplace $attrl $si $si {size 0}]
	# Then do a nverify
	set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getfh;
		Nverify {$nal}; Getfh}]
	set cont [ckres "Nverify" $status $expcode $res $FAIL]
  }
# verify FH is not changed after successful Nverify op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Nverify a dir w/list of attrs, but one not match, expect OK
set expcode "OK"
set ASSERTION "Nverify a dir w/attr list, but one not match, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getattr "$req_attrs"}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# Nverify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# Let's change the "mode"
	set si [lsearch -regexp $attrl "mode .*"]
	set nal [lreplace $attrl $si $si {mode 751}]
	# Then do a nverify
	set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
		Nverify {$nal}; Getfh}]
	set cont [ckres "Nverify" $status $expcode $res $FAIL]
  }
# verify FH is not changed after successful Nverify op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
