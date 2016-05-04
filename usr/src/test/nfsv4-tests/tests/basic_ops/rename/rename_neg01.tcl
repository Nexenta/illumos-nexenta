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
# NFSv4 RENAME operation test - negative tests

# include all test enironment
source RENAME.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# create a tmp file to be rename
set tmpf Renm2file.[pid]
creatv4_file [file join $BASEDIR $tmpf]

# Start testing
# --------------------------------------------------------------
# a: Rename without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to Rename with no Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Rename $tmpf Renm1A.[pid]}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname does not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "Renm1A.[pid]"}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# b: Rename without SaveFH, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to Rename with no SaveFH, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Rename $tmpf Renm1B.[pid]}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname does not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "Renm1B.[pid]"}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# c: Rename with oldname=file, newname=dir and exist, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Rename w/oldname=file,newname=dir and exist, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh;
	Putfh $bfh; Rename "$env(TEXTFILE)" "$env(DIR0777)"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check both newname and oldname exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $env(TEXTFILE);
		Putfh $bfh; Lookup $env(DIR0777)}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 \
		"\t Test FAIL: old/new name doesn't exist after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# d: Rename with oldname=dir, newname=file and exist, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Try to Rename to a directory, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Getattr type; Savefh;
	Putfh $bfh; Rename $env(DIR0777) $env(RWFILE)}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check both newname and oldname exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup $env(RWFILE);
		Putfh $bfh; Lookup $env(DIR0777)}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 \
		"\t Test FAIL: old/new name doesn't exist after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# e: Rename with CURRENT_FH is a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Rename with CURRENT_FH is a file, expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Savefh; 
	Rename $tmpf "Ren1E.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname does not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "Renm1E.[pid]"}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# f: Rename with SAVED_FH is a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Rename with SAVED_FH is a file, expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Savefh; 
	Putfh $bfh; Rename $tmpf "Renm1F.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: oldname is gone after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
	  putmsg stderr 1 "\t   oldname=($tmpf)"
      } else {
	logres PASS
      }
  }


# g: Rename with oldname=dir, newname=dir but not empty, expect EXIST
set expcode "EXIST"
set ASSERTION "Rename w/oldname&newname=dir but not empty, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set tmpG "RendirG.[pid]"
set res [compound {Putfh $bfh; Savefh; Create $tmpG {{mode 0777}} d;
	Putfh $bfh; Rename "$tmpG" "$env(DIR0777)"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$env(DIR0777)"}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname is gone after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
	  putmsg stderr 1 "\t   newname=($env(DIR0777))"
      } else {
	logres PASS
      }
  }


# h: Rename with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Rename with WrongSec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server to change <cfh> w/KRB5.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Rename with CFH expired, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Rename with CFH expired, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# n: try to Rename with SFH expired, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Rename with SFH expired, expect $expcode"
#putmsg stdout 0 "$TNAME{n}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# u: try to Rename into noperm_dir, expect ACCESS
set expcode "ACCESS"
set ASSERTION "try to Rename into noperm_dir, expect $expcode"
putmsg stdout 0 "$TNAME{u}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Lookup "$env(DNOPERM)";
	Rename $env(ROFILE) "Ren1u.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname should not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "en1u.[pid]"}]
      if { $status == "OK" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# v: try to Rename a file from noperm_dir, expect ACCESS
set expcode "ACCESS"
set ASSERTION "try to Rename a file from noperm_dir, expect $expcode"
putmsg stdout 0 "$TNAME{v}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DNOPERM)"; Savefh;
	Putfh $bfh; Rename $tmpf "Ren1u.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status == "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: oldname is gone after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp files/dirs
set res [compound {Putfh $bfh; Remove $tmpf; Remove $tmpG}]
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
