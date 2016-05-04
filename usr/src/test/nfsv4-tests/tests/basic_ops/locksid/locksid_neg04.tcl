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
set fsize 999
set open_owner $TFILE
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" \
	osid oseqid status $seqid 0 666 $fsize]
if {$nfh == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($TFILE)"
	putmsg stderr 0 "\t\t basic_open failed, status=($status)."
	exit $UNRESOLVED
}
incr oseqid
putmsg stderr 1 "  Good osid=($osid)"

# Set a lock(R) in file for testing
set lowner "[pid].lo"
set lseqid 1
set res [compound {Putfh $nfh; 
	Lock 1 F 0 $fsize T $osid $lseqid "$oseqid $cid $lowner"}]
if { $status != "OK" } {
	putmsg stdout 0 "$TNAME: test setup - set a Read-lock"
	putmsg stderr 0 "\t Test UNRESOLVED: Lock() returned status=$(status)"
	putmsg stderr 1 "\t\t  Res=($res)"
	exit $UNRESOLVED
}
set lsid_good [lindex [lindex $res 1] 2]

# Start testing
# --------------------------------------------------------------
# a: Resend the LOCK(R), server should see it as dup, expect OK
set expcode "OK"
set ASSERTION "Resend the LOCK(R), server should see it as dup, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 1 F 0 $fsize T $osid $lseqid "$oseqid $cid $lowner"}]
if { [string first "BAD" $status] == -1} {
	incr oseqid
	incr lseqid
}	
if { [ckres "Lock(R)" $status $expcode $res $FAIL] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	if { "$lsid_good" != "$lsid" } {
		putmsg stderr 0 "\t Test FAIL: lock_sid different on dup"
		putmsg stderr 0 "\t\t  lsid_good=($lsid_good), lsid=($lsid)"
	} else {
		logres "PASS"
		putmsg stderr 1 "  Good lsid=($lsid)"
	}
} else {
	set lsid $lsid_good
}

# a1: Resend the LOCK(R)w/new lockowner, server should see it as dup, expect OK
set expcode "OK"
set ASSERTION \
	"Resend the LOCK(R) w/new lockowner, server should see it as dup,"
set ASSERTION "$ASSERTION expect $expcode"
set tag "$TNAME{a1}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh;
        Lock 1 F 0 $fsize F $lsid $lseqid "oseqid clientid lowner"}]
if { [string first "BAD" $status] == -1} {
	incr oseqid
	incr lseqid
}	
if { [ckres "Lock(R)" $status $expcode $res $FAIL] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	set tmp_lsid "[expr [lindex $lsid_good 0] + 1] [lindex $lsid_good 1]"
	if { "$tmp_lsid" != "$lsid" } {
		putmsg stderr 0 \
			"\t Test FAIL: lock_sid different on dup w/new lowner"
		putmsg stderr 0 "\t\t  expt_lsid=($tmp_lsid), lsid=($lsid)"
	} else {
		set lsid_new $lsid
		logres "PASS"
		putmsg stderr 1 "  Good lsid=($lsid) new lsid=($lsid_new)"
	}
} else {
	set lsid $lsid_good
}


# b: new Lock w/bad open_seqid (0), expect BAD_SEQID
set expcode "BAD_SEQID"
set bseq 0
set ASSERTION "new Lock w/bad open_oseqid ($bseq), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 2 F 1024 10 T $osid 1 "$bseq $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS

# c: Lock(R) w/same lowner, but bad_lseqid(0), expect BAD_SEQID
set expcode "BAD_SEQID"
set bseq 0 
set ASSERTION "Lock(R) same lowner, but bad_lseqid($bseq), expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 1 F 10 20 F $lsid $bseq "$oseqid $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS

# d: Locku(R,10,20) w/same lowner, but bad_lseqid, expect BAD_SEQID
set expcode "BAD_SEQID"
set bseq 0
set ASSERTION "Locku(R,10,20) w/bad_lseqid($bseq), expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $bseq $lsid 10 20}]
ckres "Locku" $status $expcode $res $PASS

# f: new Lock w/bad stateid{1234567890 0987654321}
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "new Lock w/bad sid{1234567890 0987654321}, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set bad_osid {1234567890 0987654321}
set res [compound {Putfh $nfh; 
	Lock 2 F 1024 10 T $bad_osid 2 "$oseqid $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS

# g: Locku(R) w/invalid stateid{0 1}  - expect BAD_STATEID|STALE_STATEID
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Locku w/invalid sid{0 1}, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
set bad_lsid {0 1}
set res [compound {Putfh $nfh; Locku 1 $lseqid $bad_lsid 10 20}]
ckres "Locku" $status $expcode $res $PASS

# i: new Lock(R) w/invalid osid (seqid+1) - expect BAD_STATEID
set expcode "BAD_STATEID"
set ASSERTION "new Lock w/invalid osid (seqid+1), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set bseqid [expr [lindex $osid 0] + 1]
set bad_osid "$bseqid [lindex $osid 1]"
putmsg stderr 1 "  new osid with trashed seqid: bad_osid=($bad_osid)"
set res [compound {Putfh $nfh; 
	Lock 1 F 30 10 T $bad_osid 30 "$oseqid $cid $lowner-2"}]
ckres "Lock" $status $expcode $res $PASS

# j: 2nd Lock(R) w/invalid lsid (seqid+1) - expect BAD_STATEID
set expcode "BAD_STATEID"
set ASSERTION "2nd Lock w/invalid lsid (seqid+1), expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set bseqid [expr [lindex $lsid 0] + 1]
set bad_lsid "$bseqid [lindex $lsid 1]"
putmsg stderr 1 "  new lsid with trashed seqid: bad_lsid=($bad_lsid)"
set res [compound {Putfh $nfh; 
	Lock 1 F 30 10 F $bad_lsid $lseqid "$oseqid $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS

# k: Locku(R) w/invalid lsid (seqid+1) - expect BAD_STATEID
set expcode "BAD_STATEID"
set ASSERTION "Locku w/invalid sid (seqid+1), expect $expcode"
set tag "$TNAME{k}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $lseqid $bad_lsid 10 20}]
ckres "Locku" $status $expcode $res $PASS

# m: 2nd Lock(R) w/invalid lsid (trash-other) 
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "2nd Lock w/invalid sid (trash-other), expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set newS ""
set oldS [lindex $lsid 1]
set l [string length $oldS]
for {set i 0} {$i < $l} {incr i} {
    	append newS [string index $oldS end-$i]
}
set bad_lsid "[lindex $lsid 0] $newS"
putmsg stderr 1 "  new lsid with trashed other: bad_lsid=($bad_lsid)"
set res [compound {Putfh $nfh; 
	Lock 1 F 30 10 F $bad_lsid 30 "$oseqid $cid $lowner-2"}]
ckres "Lock" $status $expcode $res $PASS

# n: Locku(R) w/invalid lsid (trash-other)
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Locku w/invalid lsid (trash-other), expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $lseqid $bad_lsid 10 20}]
ckres "Locku" $status $expcode $res $PASS

# s: Check Lock(R) w/previous lsid - expect BAD_SEQID
set expcode "BAD_SEQID"
set ASSERTION "Check Lock(R) w/previous lsid, expect $expcode"
set tag "$TNAME{s}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 1 F 100 10 F $lsid_good $lseqid "$oseqid $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS
putmsg stderr 1 "\t   Res=($res)"


# t: Check Locku w/previous lsid - expect BAD_SEQID
set expcode "BAD_SEQID"
set ASSERTION "Check Locku w/previous lsid, expect $expcode"
set tag "$TNAME{t}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $lseqid $lsid_good 100 20}]
ckres "Locku" $status $expcode $res $PASS
putmsg stderr 1 "\t   Res=($res)"


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
