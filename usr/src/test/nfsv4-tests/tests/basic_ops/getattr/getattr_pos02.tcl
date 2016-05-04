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
#	verify getattr with certain attrs

# include all test enironment
source GETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: check Getattr of a file w/some attr, expect OK
set expcode "OK"
set ASSERTION "check Getattr of a file w/some attr, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set cal {fh_expire_type named_attr type size mode acl}
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;
	Getattr $cal; Getfh}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify the values returned for the attrs make sense
  if {! [string equal $cont "false"]} {
  	set attrs [lindex [lindex $res 3] 2]
	set cont true
	foreach al $attrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      type { if {"$val" != "reg"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      mode { if {"$val" != "666"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      fh_expire_type { if {"$val" != "0"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      named_attr { if {"$val" != "false"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		set cont false
		break
	      } }
	      default { # XX what other attr can we check here?
		break
	      }
	    }
	}
	if {[string equal $cont "false"]} {
		putmsg stderr 1 "\t res=($res)"
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
