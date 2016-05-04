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
# NFSv4 REMOVE operation test - positive tests

# include all test enironment
source REMOVE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Try to remove a file, expect OK
set expcode "OK"
set ASSERTION "Try to Remove a file, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
# first create a temp file to be removed:
set tmpf "RemF.[pid]"
set ffh [creatv4_file [file join $BASEDIR $tmpf]]
if { $ffh != $NULL } {
    # now the remove test:
    set res [compound {Putfh $bfh; Remove $tmpf; Getfh}]
    set cont [ckres "Remove" $status $expcode $res $FAIL]
    set fh1 [lindex [lindex $res 2] 2]
} else {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp file."
    putmsg stderr 1 "\t   res=($res)"
    set cont "false"
}
# verify file is removed:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $tmpf}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: file exists after Remove."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# b: Try to remove a dir that is empty, expect OK
set expcode "OK"
set ASSERTION "Remove a dir that is empty, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
# first create a temp dir to be removed:
set tmpd "RemD.[pid]"
set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; Getfh}]
if { $status != "OK" } {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp dir."
    putmsg stderr 1 "\t   res=($res)"
    set cont false
}
# now remove it:
if {! [string equal $cont "false"]} {
    set res [compound {Putfh $bfh; Remove $tmpd; Getfh}]
    set cont [ckres "Remove" $status $expcode $res $FAIL]
    set fh1 [lindex [lindex $res 2] 2]
}
# verify file is removed:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $tmpd}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: dir exists after Remove."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# c: Try to remove an entry of other file type w/mode=0 , expect OK
set expcode "OK"
set ASSERTION "Remove a Socket file w/mode=0, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
# first create a temp socket file to be removed:
set tmps "RemS.[pid]"
set res [compound {Putfh $bfh; Create $tmps {{mode 0777}} s;
	Getfh; Setattr {0 0} {{mode 0}}}]
if { $status != "OK" } {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp sock."
    putmsg stderr 1 "\t   res=($res)"
    set cont false
}
# now remove it:
if {! [string equal $cont "false"]} {
    set res [compound {Putfh $bfh; Remove $tmps; Getfh}]
    set cont [ckres "Remove" $status $expcode $res $FAIL]
    set fh1 [lindex [lindex $res 2] 2]
}
# verify file is removed:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $tmps}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: sock exists after Remove."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
