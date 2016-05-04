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
# NFSv4 GETATTR operation test - positive tests
#	verify getattr to get supported_attrs

# include all test enironment
source GETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set req_attrs "supported_attrs type fh_expire_type change size link_support
    symlink_support named_attr fsid unique_handles lease_time rdattr_error"

# Start testing
# --------------------------------------------------------------
# a: Getattr of a file w/supported_attr, expect OK
set expcode "OK"
set ASSERTION "Getattr of a file w/supported_attr, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;
	Getattr {supported_attrs type}; Getfh}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify the attr return the min require attrs
  if {! [string equal $cont "false"]} {
  	set attrs [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
	foreach an $req_attrs {
	    if {[lsearch -exact $attrs "$an"] == -1} {
		putmsg stderr 0 "\t Test FAIL: attr($an) was not returned."
		putmsg stderr 1 "\t   res=($res)"
		putmsg stderr 1 "\t   attrs=($attrs)"
		putmsg stderr 1 "\t   an=($an)"
		putmsg stderr 1 "  "
		set cont false
		break
	    }
	}
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Get supported_attrs of a file & check its value, expect OK
set expcode "OK"
set ASSERTION "Get supported_attrs of a file & check its value, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getfh;
	Getattr "$req_attrs"; Getfh}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify all attr returned and with good value
  if {! [string equal $cont "false"]} {
  	set attrs [lrange [lindex [lindex $res 3] 2] 1 end]
	foreach al $attrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      type { if {"$val" != "reg"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      rdattr_error { if {"$val" != "OK"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      default { # XX what other attr can we check here?
		break
	      }
	    }
	}
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Get supported_attrs of a dir & check its value, expect OK
set expcode "OK"
set ASSERTION "Get supported_attrs of a dir & check its value, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
	Getattr "$req_attrs"; Getfh}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify all attr returned and with good value
  if {! [string equal $cont "false"]} {
  	set attrs [lrange [lindex [lindex $res 3] 2] 1 end]
	foreach al $attrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      type { if {"$val" != "dir"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      rdattr_error { if {"$val" != "OK"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      default { # XX what other attr can we check here?
		break
	      }
	    }
	}
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# d: Get supported_attrs of noperm_dir & check its value, expect OK
set expcode "OK"
set ASSERTION "Get supported_attrs of noperm_dir & check its value, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM); Getfh;
	Getattr "$req_attrs"; Getfh}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify all attr returned and with good value
  if {! [string equal $cont "false"]} {
  	set attrs [lrange [lindex [lindex $res 3] 2] 1 end]
	foreach al $attrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      type { if {"$val" != "dir"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      rdattr_error { if {"$val" != "OK"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      default { # XX what other attr can we check here?
		break
	      }
	    }
	}
  }
# verify FH is not changed after successful Getattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
