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
# a: Rename with oldname not exist, expect ENOENT
set expcode "NOENT"
set ASSERTION "Rename with oldname not exist, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename "ENOENT" "Ren2a.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname does not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "Ren2a.[pid]"}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# b: try to Rename while target dir is removed, expect STALE
set expcode "STALE"
set ASSERTION "Rename while target dir is removed, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set tmpd "tmp.[pid]"
set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; 
	Getfh; Create xx {{mode 0775}} d;}]
set tfh [lindex [lindex $res 2] 2]
check_op "Putfh $tfh; Remove xx; Lookupp; Remove $tmpd" "OK" "UNINITIATED"
set res [compound {Putfh $bfh; Savefh; Putfh $tfh; Rename xx "Ren2b.[pid]"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname does not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "Ren2b.[pid]"}]
      if { $status != "NOENT" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# c: Rename with newname has zero length, expect INVAL
set expcode "INVAL"
set ASSERTION "Rename with newname has zero length, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename $tmpf ""}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# d: Rename with newname is not UTF-8, expect INVAL
set expcode "INVAL"
set ASSERTION "Rename with newname is not UTF-8, expect $expcode"
#putmsg stdout 0 "$TNAME{d}: $ASSERTION"
#puts "\t Test UNTESTED: XXX how to create non-UTF-8 compliance name??\n"


# e: Rename with newname set to ".", expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Rename with newname set to '.', expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename $tmpf "."}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# f: Rename with newname set to "..", expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Rename with newname set to '..', expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename $tmpf ".."}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# g: Rename w/newname include path delimiter, expect INVAL
set expcode "INVAL"
set ASSERTION "Rename w/newname include path delimiter, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename $tmpf "XX${DELM}xx"}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# h: Rename with oldname has zero length, expect INVAL
set expcode "INVAL"
set ASSERTION "Rename with oldname has zero length, expect $expcode"
putmsg stdout 0 "$TNAME{h}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename "" XXX}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname should not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "XXX"}]
      if { $status == "OK" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# i: Rename with oldname is not UTF-8, expect INVAL
set expcode "INVAL"
set ASSERTION "Rename with oldname is not UTF-8, expect $expcode"
#putmsg stdout 0 "$TNAME{i}: $ASSERTION"
#puts "\t Test UNTESTED: XXX how to create non-UTF-8 compliance name??\n"


# j: Rename with oldname set to ".", expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Rename with oldname set to '.', expect $expcode"
putmsg stdout 0 "$TNAME{j}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename "." XXX}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname should not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "XXX"}]
      if { $status == "OK" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# k: Rename with oldname set to "..", expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Rename with oldname set to '..', expect $expcode"
putmsg stdout 0 "$TNAME{k}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename ".." XXX}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname should not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "XXX"}]
      if { $status == "OK" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# l: Rename with oldname include path delimiter, expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Rename w/oldname include path delimiter, expect $expcode"
putmsg stdout 0 "$TNAME{l}: $ASSERTION"
set res [compound {Putfh $bfh; Savefh; Rename "XX${DELM}xx" XXX}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check newname should not exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "XXX"}]
      if { $status == "OK" } {
	  putmsg stderr 0 "\t Test FAIL: newname exists after Rename failed"
	  putmsg stderr 1 "\t   res=($res)"
      } else {
	logres PASS
      }
  }


# m: Rename with newname longer than maxname, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Rename with newname longer than maxname, expect $expcode"
putmsg stdout 0 "$TNAME{m}: $ASSERTION"
set nli [set_maxname $bfh]
set res [compound {Putfh $bfh; Savefh; Rename $tmpf $nli}]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $bfh; Lookup "$tmpf"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
		putmsg stderr 1 "\t   length of newname=([string length $nli])"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# n: Rename across filesystems, expect XDEV
set expcode "XDEV"
set ASSERTION "Rename to a file across filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{n}: $ASSERTION"
set ofh [get_fh [path2comp $env(SSPCDIR) $DELM]]
set res [compound {Putfh $bfh; Getattr numlinks; Savefh;
	Putfh $ofh; Rename $env(RWFILE) "RendirN" }]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $ofh; Lookup "$env(RWFILE)"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }

# o: Rename of named_attr across filesystems, expect XDEV
set expcode "XDEV"
set ASSERTION "Rename of named_attr across filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{o}: $ASSERTION"
set ofh [get_fh [path2comp $env(SSPCDIR) $DELM]]
set res [compound {Putfh $ofh; Savefh; 
	Putfh $bfh; Lookup $env(ATTRDIR); Openattr f;
	Rename $env(RWFILE) "RendirO" }]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set res [compound {Putfh $ofh; Lookup "$env(RWFILE)"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }

# p: Rename a file into named_attrd across filesystems, expect XDEV
set expcode "XDEV"
set ASSERTION "Rename a file into named_attrd across FSs, expect $expcode"
putmsg stdout 0 "$TNAME{p}: $ASSERTION"
set ofh [get_fh [path2comp $env(SSPCDIR) $DELM]]
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr f; Savefh;
	Getfh; Putfh $ofh; Rename $env(ATTRDIR_AT1) "RendirP" }]
set cont [ckres "Rename" $status $expcode $res $FAIL]
# check oldname still exist
  if {! [string equal $cont "false"]} {
      set nfh [lindex [lindex $res 4] 2]
      set res [compound {Putfh $nfh; Lookup "$env(ATTRDIR_AT1)"}]
      if { $status != "OK" } {
          if { $status == "NOENT" } {
		putmsg stderr 0 \
			"\t Test FAIL: oldname is gone after Rename failed"
	  	putmsg stderr 1 "\t   res=($res)"
          } else {
		putmsg stderr 0 \
			"\t Test FAIL: 2nd compound got=($status), expected OK"
	  }
      } else {
	logres PASS
      }
  }


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp files
set res [compound {Putfh $bfh; Remove $tmpf}]
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
