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
set OPEN4_RESULT_LOCKTYPE_POSIX 4

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
set TFILE "$TNAME.[pid]"

# Start testing
# --------------------------------------------------------------
# First open a file w/access=READ for the lock tests
putmsg stdout 0 \
  "  ** Now Open/create ($TFILE)) w/access=R for following assertions(a,b):"
set open_owner "[pid][clock seconds]"
set oseqid 10
set tag "$TNAME-OPEN"
set res [compound {Putfh $bfh; Open $oseqid 1 0 "$cid $open_owner" \
	{1 0 {{mode 0644}}} {0 $TFILE}; Getfh}]
if {$status != "OK"} {
	putmsg stdout 0 "$TNAME: test setup - OPEN file for access=READ"
	putmsg stderr 0 \
		"\t Test UNRESOLVED: unable to Open ($TFILE) for read"
	putmsg stderr 0 "\t\t  Assertions(a,b) will not run"
	putmsg stderr 1 "\t Res=($res)."
	exit $UNRESOLVED
}

set osid [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh [lindex [lindex $res 2] 2]
# do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	set oseqid [expr $oseqid + 1]
	set res [compound {Putfh $nfh; Open_confirm $osid $oseqid}]
	if {$status != "OK"} {
		putmsg stdout 0 "$TNAME: test setup - OPEN_CONFIRM"
		putmsg stderr 0 "\t Test UNRESOLVED: unable to Open_confirm"
		putmsg stderr 0 "\t\t  Assertions(a,b) will not run"
		putmsg stderr 1 "\t Res=($res)."
		exit $UNRESOLVED
	}
	set osid [lindex [lindex $res 1] 2]
}
set oseqid [expr $oseqid + 1]


# Now the test assertions
# a: Try to set a WRITE Lock, expect OPENMODE
set expcode "OPENMODE"
set ASSERTION "Try to set a WRITE Lock, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set res [compound {Putfh $nfh; 
	Lock 2 F 0 125 T $osid $lseqid "$oseqid $cid $open_owner"}]
if {[expr $rflags & $OPEN4_RESULT_LOCKTYPE_POSIX] == \
	$OPEN4_RESULT_LOCKTYPE_POSIX} {
	ckres "Lock(WR)" $status $expcode $res $PASS
} else {
	ckres "Lock(WR)" $status "OK|OPENMODE" $res $PASS
}


# b: Try to set a WRITEW Lock, expect OPENMODE
set expcode "OPENMODE"
set ASSERTION "Try to set a WRITEW Lock, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 2
incr oseqid
set res [compound {Putfh $nfh; 
	Lock 4 F 0 125 T $osid $lseqid "$oseqid $cid $open_owner"}]
if {[expr $rflags & $OPEN4_RESULT_LOCKTYPE_POSIX] == \
	$OPEN4_RESULT_LOCKTYPE_POSIX} {
	ckres "Lock(WRW)" $status $expcode $res $PASS
} else {
	ckres "Lock(WRW)" $status "OK|OPENMODE" $res $PASS
}


# Set a READ lock on the file
putmsg stdout 0 "  ** Now set a READ lock for following assertions(m,p):"

# i: Set a READ lock on the file (for the following assertions), expect OK
set expcode "OK"
set ASSERTION "set a READ Lock on file (for assertions m,p), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 3
incr oseqid
set res [compound {Putfh $nfh; 
	Lock 1 F 0 125 T $osid $lseqid "$oseqid $cid $open_owner"}]
if {$status != "OK"} {
	putmsg stderr 0 "Test UNRESOLVED: READ-lock failed, status=$status"
	putmsg stderr 0 "\t\t  Assertions(m,p) will not run"
	putmsg stderr 1 "\t Res=($res)."
} else {
  logres "PASS"
  set lseqid [expr $lseqid + 1]
  set lsid [lindex [lindex $res 1] 2]

  # m: Try Lockt of WRITE lock w/lock-range, diff lowner, expect DENIED
  set expcode "DENIED"
  set ASSERTION "Lockt(WRITE) w/lock-range, diff lowner, expect $expcode"
  set tag "$TNAME{m}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $nfh; Lockt 2 $cid "lowner.[pid]-s" 1 124}]
  ckres "Lockt" $status $expcode $res $PASS


  # p: Try Locku WRITE lock of the RD-lock expect INVAL
  set expcode "INVAL"
  set ASSERTION "Try Locku WRITE lock of the RD-lock, expect $expcode"
  set tag "$TNAME{p}"
  putmsg stdout 0 "$tag: $ASSERTION"
  set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid 1 0}]
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
