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
# NFSv4 LOCK, LOCKT, LOCKU operation test - negative tests
#	Verify server returns correct errors with negative requests.

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set hid "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set seqid 1

# Create a temp test file and get it's filehandle
set TFILE "$TNAME.[pid]"
set size 999
set open_owner $TFILE
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" \
	osid oseqid status $seqid 0 666 $size]
if {$nfh == -1} {
	putmsg stdout 0 "$TNAME: test setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($TFILE)"
	putmsg stderr 0 "\t\t basic_open failed, status=($status)."
	exit $UNRESOLVED
}
incr oseqid


# Start testing
# --------------------------------------------------------------
# a: Lock without setting <cfh>, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Lock without setting <cfh>, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set res [compound {Lock 1 F 0 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS


# b: Lock with <cfh> is a directory, expect ISDIR|BAD_STATEID
set expcode "ISDIR|BAD_STATEID"
set ASSERTION "Lock with <cfh> is a directory, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set res [compound {Putfh $bfh; 
	Lock 1 F 0 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS


# c: Lock with <cfh> is a symlink, expect INVAL|BAD_STATEID
set expcode "INVAL|BAD_STATEID"
set ASSERTION "Lock with <cfh> is a symlink, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set res [compound {Putfh $bfh; Lookup $env(SYMLFILE);
	Lock 1 F 0 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS


# Now set a lock in the file for the following Lockt/Locku assertions:
putmsg stdout 0 "  ** Now Set a WRITE lock to the file,"
putmsg stdout 0 "  ** for the following assertions(h,i,j, r,s,t)."
# d: set new Lock(WR) with osid/oseqid, expect OK
set expcode "OK"
set ASSERTION "set new Lock(WR) with osid/oseqid, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 2 F 0 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
if {$status != "OK"} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: Lock(WR) failed; expected=OK, got=$status"
	putmsg stderr 0 "\t\t  Assertions(r, s) will not run"
	putmsg stderr 1 "\t\t  Res=($res)"
} else {
  logres "PASS"
  set lsid [lindex [lindex $res 1] 2]
  incr lseqid

  # h: Lockt without setting <cfh>, expect NOFILEHANDLE
  set expcode "NOFILEHANDLE"
  set ASSERTION "Lockt without setting <cfh>, expect $expcode"
  set tag "$TNAME{h}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Lockt 2 $cid "lowner.[pid]-h" 0 10}]
  ckres "Lockt" $status $expcode $res $PASS
  
  
  # i: Lockt w/<cfh> is a directory, expect ISDIR|BAD_STATEID
  set expcode "ISDIR|BAD_STATEID"
  set ASSERTION "Lockt w/<cfh> is a directory, expect $expcode"
  set tag "$TNAME{i}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $bfh; Lockt 1 $cid "lowner.[pid]-i" 0 15}]
  ckres "Lockt" $status $expcode $res $PASS
  
  
  # j: Lockt w/<cfh> is a FIFO file, expect INVAL|BAD_STATEID
  set expcode "INVAL|BAD_STATEID"
  set ASSERTION "Lockt w/<cfh> is a FIFO file, expect $expcode"
  set tag "$TNAME{j}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $bfh; Lookup $env(FIFOFILE);
  	Lockt 1 $cid "lowner.[pid]-j" 0 15}]
  ckres "Lockt" $status $expcode $res $PASS
  
  
  # r: Locku without setting <cfh>, expect NOFILEHANDLE
  set expcode "NOFILEHANDLE"
  set ASSERTION "Locku without setting <cfh>, expect $expcode"
  set tag "$TNAME{r}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Locku 3 $lseqid $lsid 0 10}]
  ckres "Locku" $status $expcode $res $PASS
  # get new lock-stateid in case test failed and LOCK OK for next assertion:
  if {$status == "OK"} {
  	set lsid [lindex [lindex $res 1] 2]
  }
  
  
  # s: Locku w/<cfh> is a directory, expect ISDIR|BAD_STATEID
  set expcode "ISDIR|BAD_STATEID"
  set ASSERTION "Locku w/<cfh> is a directory, expect $expcode"
  set tag "$TNAME{s}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $bfh; Getattr type; Locku 3 $lseqid $lsid 0 10}]
  ckres "Locku" $status $expcode $res $PASS
  # get new lock-stateid in case test failed and LOCKU OK for next assertion:
  if {$status == "OK"} {
  	set lsid [lindex [lindex $res 2] 2]
  }


  # t: Locku w/<cfh> is a CHAR file, expect INVAL|BAD_STATEID
  set expcode "INVAL|BAD_STATEID"
  set ASSERTION "Locku w/<cfh> is a CHAR file, expect $expcode"
  set tag "$TNAME{t}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $bfh; Lookup $env(CHARFILE); Getattr type;
	Locku 3 $lseqid $lsid 0 10}]
  ckres "Locku" $status $expcode $res $PASS
  # get new lock-stateid in case test failed and LOCKU OK for next assertion:
  if {$status == "OK"} {
  	set lsid [lindex [lindex $res 3] 2]
  }

  # v: Locku w/length=0, expect INVAL
  set expcode "INVAL"
  set ASSERTION "Locku w/length=0, expect $expcode"
  set tag "$TNAME{v}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid 1 0}]
  ckres "Locku" $status $expcode $res $PASS
  # get new lock-stateid in case test failed and LOCKU OK for next assertion:
  if {$status == "OK"} {
  	set lsid [lindex [lindex $res 3] 2]
  }

  # w: Locku w/offset+length over max, expect INVAL
  set expcode "INVAL"
  set ASSERTION "Locku w/offset+length over max, expect $expcode"
  set tag "$TNAME{w}"
  putmsg stdout 0 "$tag: $ASSERTION"
  incr lseqid
  set halfmax 9300000000000000000 
  set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid $halfmax $halfmax}]
  ckres "Locku" $status $expcode $res $PASS
}
  
  
# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set tag "$TNAME-cleanup"
set res [compound {Putfh $bfh; Remove $TFILE}]
if {($status != "OK") && ($status != "NOENT")} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
