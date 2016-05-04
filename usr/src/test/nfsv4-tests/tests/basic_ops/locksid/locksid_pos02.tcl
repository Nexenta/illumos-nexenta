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
# NFSv4 LOCK, LOCKT, LOCKU operations test - positive tests
#   Basic fucntion of LOCK, LOCKT, LOCKU op (different owners)

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set TFILE "$TNAME.[pid]"
set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $owner]
if {$cid == -1} {
	putmsg stderr 0 "$TNAME: setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}

# Create a test file and get its osid
set fsize 8193
set nfh [basic_open $bfh $TFILE 1 "$cid $owner" osid oseqid status \
	1 0 664 $fsize]
if {$nfh == -1} {
	putmsg stderr 0 "$TNAME: setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: status=($status)"
	exit $UNRESOLVED
}
set oseqid [expr $oseqid + 1]
set lowner1 "[pid].lo1"
set lowner2 "[pid].lo2"
set lseqid1 1
set lseqid2 1


# Start testing
# --------------------------------------------------------------
# a: new LOCK(lowner-1,READW,0,100), expect OK
set expcode "OK"
set ASSERTION "new LOCK(lowner-1,Rw,0,100), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 3 F 0 100 T $osid $lseqid1 "$oseqid $cid $lowner1"}]
if { [ckres "Lock(Rw1)" $status $expcode $res $PASS] == "true" } {
	set lsid1 [lindex [lindex $res 1] 2]
	incr lseqid1
	incr oseqid
} else {
	set lsid1 {11 22}
}

# b: new LOCK(lowner-2,READW,90,10), expect OK
set expcode "OK"
set ASSERTION "new LOCK(lowner-2,Rw,90,10), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 3 F 10 10 T $osid $lseqid2 "$oseqid $cid $lowner2"}]
if { [ckres "Lock(Rw2)" $status $expcode $res $PASS] == "true" } {
	set lsid2 [lindex [lindex $res 1] 2]
	incr lseqid2
	incr oseqid
} else {
	set lsid2 {22 22}
}

# c: LOCK(lowner-2,WRITEW,100,100) also, expect OK
set expcode "OK"
set ASSERTION "LOCK(lowner-2,Ww,100,100) also, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 4 F 100 100 F $lsid2 $lseqid2 "$oseqid $cid $lowner2"}]
if { [ckres "Lock(Ww2)" $status $expcode $res $PASS] == "true" } {
	set lsid2 [lindex [lindex $res 1] 2]
	incr lseqid2
} else {
	set lsid2 {32 22}
}

# e: Lockt(lowner1) to check its own & share locks, expect OK
set expcode "OK"
set ASSERTION "Lockt(lowner1) check its own & share locks, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 2 $cid $lowner1 0 10;
	Lockt 1 $cid $lowner1 10 81}]
ckres "Lockt" $status $expcode $res $PASS

# f: Lockt(lowner2) to check its own & share locks, expect OK
set expcode "OK"
set ASSERTION "Lockt(lowner2) to check its own & share locks, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 1 $cid $lowner2 88 10;
	Lockt 2 $cid $lowner2 101 1024}]
ckres "Lockt" $status $expcode $res $PASS

# g: Lockt(anotherlo) for exclusive in other area, expect OK
set expcode "OK"
set ASSERTION "Lockt(anotherlo) for exclusive in other area, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 4 $cid "anotherlo" 1024 100}]
ckres "Lockt" $status $expcode $res $PASS

# i: Locku(lowner1) to split its READ lock(10-20), expect OK
set expcode "OK"
set ASSERTION "Locku(lowner1) to split(10-20), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $lseqid1 $lsid1 10 10}]
if { [ckres "Locku" $status $expcode $res $PASS] == "true" } {
	set lsid1 [lindex [lindex $res 1] 2]
	incr lseqid1
} else {
	set lsid1 {11 22}
}

# j: Locku(lowner2) over (W-nolock) boundary, expect OK
set expcode "OK"
set ASSERTION "Locku(lowner2) over (W-nolock) boundary, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 2 $lseqid2 $lsid2 188 80}]
if { [ckres "Locku" $status $expcode $res $PASS] == "true" } {
	set lsid2 [lindex [lindex $res 1] 2]
	incr lseqid2
} else {
	set lsid2 {22 22}
}

# o: lowner2 to Lock(W) to verify split locks, expect OK
set expcode "OK"
set ASSERTION "lowner2 to Lock(W) to verify split locks, expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 2 F 10 10 F $lsid2 $lseqid2 "$oseqid $cid $lowner2"}]
if { [ckres "Lock(W2)" $status $expcode $res $PASS] == "true" } {
	set lsid2 [lindex [lindex $res 1] 2]
	incr lseqid2
} else {
	set lsid2 {32 22}
}

# p: Lockt(lowner1) to verify new lock in split region, expect DENIED
set expcode "DENIED"
set ASSERTION "Lockt(lowner1) to verify new lock, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 1 $cid $lowner1 5 8}]
ckres "Lockt" $status $expcode $res $PASS

# s: Now Close the file to clear the locks, expect OK|LOCKS_HELD
set expcode "OK|LOCKS_HELD"
set ASSERTION "Now Close file to clear the locks, expect $expcode"
set tag "$TNAME{s}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid $osid}]
set clst $status
if { ($env(SRVOS) == "Solaris") } {
	ckres "Close" $status "OK" $res $PASS
} else {
	ckres "Close" $status $expcode $res $PASS
}

# t: verify w/Lockt all locks are cleared, expect OK
set expcode "OK"
set ASSERTION "verify w/Lockt all locks are cleared, expect $expcode"
set tag "$TNAME{t}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 2 $cid "anotherlo" 10 10000}]
ckres "Lockt" $status $expcode $res $PASS
putmsg stdout 1 "\t Close returned $clst"


# --------------------------------------------------------------
# Now cleanup, close and removed created tmp file
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
