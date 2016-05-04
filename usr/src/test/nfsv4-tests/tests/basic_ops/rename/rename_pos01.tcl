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
# NFSv4 RENAME operation test - positive tests

# include all test enironment
source RENAME.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic Rename of a file, expect OK
set expcode "OK"
set ASSERTION "Basic Rename of a file, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set newf "NewRenF.[pid]"
set nffh [creatv4_file [file join $BASEDIR $newf]]
if { $nffh != $NULL } {
    # now the rename test:
    set res [compound {Putfh $bfh; Savefh;
	Putfh $bfh; Rename $newf "a.new"; Getfh}]
    set cont [ckres "Rename" $status $expcode $res $FAIL]
    set fh1 [lindex [lindex $res 4] 2]
} else {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp file."
    putmsg stderr 1 "\t   res=($res)"
    set cont "false"
}
# verify original file is removed and new file exist:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $newf}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: orig file exists after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      } else {
        set res [compound {Putfh $bfh; Lookup "a.new"}]
        if { $status != "OK" } {
	  putmsg stderr 0 "\t Test FAIL: new file doesn't exist after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
	}
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# b: basic Rename of a dir entry, expect OK
set expcode "OK"
set ASSERTION "Basic Rename of a dir entry, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set newd "NewRenD.[pid]"
set res [compound {Putfh $bfh; Savefh; Create $newd {{mode 0777}} d;
	Putfh $bfh; Rename $newd "b.new"; Getfh}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
set fh1 [lindex [lindex $res 5] 2]
# verify original file is removed and new file exist:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $newd}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: orig file exists after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      } else {
        set res [compound {Putfh $bfh; Lookup "b.new"}]
        if { $status != "OK" } {
	  putmsg stderr 0 "\t Test FAIL: new file doesn't exist after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
	}
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# c: Rename the same file, expect OK
set expcode "OK"
set ASSERTION "Rename same file (oldname hardlink-to newname), expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set newl "NewRenL.[pid]"
set res [compound {Putfh $bfh; Create $newl {{mode 0755}} s; Savefh;
	Putfh $bfh; Link "c.new"; Savefh; Rename $newl "c.new"; Getfh}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
set fh1 [lindex [lindex $res 7] 2]
# verify both files exist:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $newl; 
		Putfh $bfh; Lookup "c.new"}]
      if { $status != "OK" } {
	  putmsg stderr 0 "\t Test FAIL: files don't exist after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      }
  }
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# d: Rename when new name exists (same type), expect OK
set expcode "OK"
set ASSERTION "Rename when new name exists (same type), expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set newk "NewRenK.[pid]"
set res [compound {Putfh $bfh; Savefh; Create $newk {{mode 0777}} d; 
	Putfh $bfh; Create "d.new" {{mode 0775}} d; 
	Putfh $bfh; Lookup "d.new"; Setattr {0 0} {{mode 0751}};
	Putfh $bfh; Lookup $newk; Getattr mode;
	Putfh $bfh; Rename $newk "d.new"; Getfh}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
set fh1 [lindex [lindex $res 13] 2]
set expm [lindex [lindex $res 10] 2]
# verify original file is removed and new file exist:
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $newk}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: orig obj exists after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
      } else {
        set res [compound {Putfh $bfh; Lookup "d.new"; Getattr mode}]
        if { $status != "OK" } {
	  putmsg stderr 0 "\t Test FAIL: new obj doesn't exist after Rename."
	  putmsg stderr 1 "\t   res=($res)"
	  set cont false
	} else {
	    set dm [lindex [lindex $res 2] 2]
	    if { $dm == 751 } {
	  	putmsg stderr 0 "\t Test FAIL: new obj has incorrect mode."
	  	putmsg stderr 0 "\t              expected=($dm), got($dm)."
	  	putmsg stderr 1 "\t   res=($res)"
	  	set cont false
	    }
	}
      }
  }
# verify FH is not changed after successful Readdir op
# verify FH is not changed after successful Readdir op
  fh_equal $fh1 $bfh $cont $PASS


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp link files
set res [compound {Putfh $bfh; Remove "a.new"; Remove "b.new"; 
	Remove $newl; Remove "c.new"; Remove "d.new"}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created files failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
