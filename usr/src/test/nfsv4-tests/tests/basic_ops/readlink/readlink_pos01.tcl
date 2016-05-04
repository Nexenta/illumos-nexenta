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
# NFSv4 READLINK operation test - positive tests

# include all test enironment
source READLINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Reading an existing symlink file, expect OK
set expcode "OK"
set ASSERTION "Reading an existing symlink file, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLFILE); 
	Getfh; Readlink; Getfh}]
set cont [ckres "Readlink" $status $expcode $res $FAIL]
# verify Readlink result
  if {! [string equal $cont "false"]} {
      set ldata [lindex [lindex $res 3] 2]
      set expd $env(EXECFILE)
      if { $ldata != $expd } {
	  putmsg stderr 0 "\t Test FAIL: linktext returned incorrect"
	  putmsg stderr 0 "\t            expected=($expd), got=($ldata)"
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# b: Reading an existing symlink dir_noperm, expect OK
set expcode "OK"
set ASSERTION "Reading an existing symlink dir_noperm, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMNOPD); 
	Getfh; Readlink; Getfh}]
set cont [ckres "Readlink" $status $expcode $res $FAIL]
# verify Readlink result
  if {! [string equal $cont "false"]} {
      set ldata [lindex [lindex $res 3] 2]
      set expd $env(DNOPERM)
      if { $ldata != $expd } {
	  putmsg stderr 0 "\t Test FAIL: linktext returned incorrect"
	  putmsg stderr 0 "\t            expected=($expd), got=($ldata)"
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Reading a symlink created by NFS client, expect OK
set expcode "OK"
set ASSERTION "Reading a symlink created by NFS client, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set nlc "NewSymL.[pid]"
set res [compound {Putfh $bfh; Create "$nlc" {{mode 0666}} l "$env(DIR0755)";
	Getfh; Readlink; Getfh}]
set cont [ckres "Readlink" $status $expcode $res $FAIL]
# verify Readlink result
  if {! [string equal $cont "false"]} {
      set ldata [lindex [lindex $res 3] 2]
      set expd $env(DIR0755)
      if { $ldata != $expd } {
	  putmsg stderr 0 "\t Test FAIL: linktext returned incorrect"
	  putmsg stderr 0 "\t            expected=($expd), got=($ldata)"
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# d: Reading a symlink points to invalid obj, expect OK
set expcode "OK"
set ASSERTION "Reading a symlink points to invalid obj, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set nld "BadSymL.[pid]"
set lksrc "No-such-thing"
set res [compound {Putfh $bfh; Create "$nld" {{mode 0666}} l $lksrc;
	Getfh; Readlink; Getfh}]
set cont [ckres "Readlink" $status $expcode $res $FAIL]
# verify Readlink result
  if {! [string equal $cont "false"]} {
      set ldata [lindex [lindex $res 3] 2]
      set expd $lksrc
      if { $ldata != $expd } {
	  putmsg stderr 0 "\t Test FAIL: linktext returned incorrect"
	  putmsg stderr 0 "\t            expected=($expd), got=($ldata)"
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp link files
set res [compound {Putfh $bfh; Remove $nlc; Remove $nld}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created links failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
