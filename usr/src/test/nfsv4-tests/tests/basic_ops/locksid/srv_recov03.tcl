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
# NFSv4 server state recovery test - network partition

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Get server lease time
set leasetm $LEASE_TIME

# First, basic setup
putmsg stdout 0 \
  "\n  ** Frist basic setup for $TNAME, if fails, program will exit ..."

# Start testing
# --------------------------------------------------------------
# a: Setclientid/Setclient_confirm, expect OK
set expcode "OK"
set ASSERTION "Setclientid/Setclient_confirm, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set hid "[pid][clock clicks]"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stderr 0 "Test FAIL: unable to get clientid"
	exit $FAIL
} else {
	logres PASS
}


# b: Open a test file w/good clientid, expect OK
set expcode "OK"
set ASSERTION "Open(& confirm if needed) file w/good clientid, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 1
set TFILE "$TNAME.[pid]-b"
set fs 8192
set open_owner $TFILE
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" osid oseqid status \
	$seqid 0 664 $fs]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test FAIL: basic_open failed, status=($status)"
	exit $FAIL
} else {
	putmsg stderr 0 "\t Test PASS"
	set oseqid [expr $oseqid + 1]
}

# c: LOCK(R) the test file w/cid+osid, expect OK
set expcode "OK"
set ASSERTION "LOCK(R) the test file w/cid+osid, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set lowner "lowner.[pid]-d"
set res [compound {Putfh $nfh; 
	Lock 1 F 0 512 T $osid $lseqid "$oseqid $cid $lowner"}]
if { [ckres "Lock(R)" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	incr oseqid

	# d: Read the LOCKed file w/lsid, expect OK
	set expcode "OK"
	set ASSERTION "Read the LOCKed file w/lsid, expect $expcode"
	putmsg stdout 0 "$TNAME{d}: $ASSERTION"
	set tag "$TNAME{d}"
	set res [compound {Putfh $nfh; Read $lsid 10 100}]
	ckres "Read" $status $expcode $res $PASS
} else {
	putmsg stderr 0 "\t Lock(R) failed, assertion d did not run"
	putmsg stderr 1 "\t res=($res)"
}
putmsg stdout 0 \
  "\n  ** Try to reset clientid w/out confirm, to verify states are valid:"

# f1: Reset clientid without confirm w/new hid, expect OK
set expcode "OK"
set ASSERTION "Reset clientid w/out confirm w/new hid, expect $expcode"
set tag "$TNAME{f1}"
putmsg stdout 0 "$tag: $ASSERTION"
set verf2 "[pid][expr int([expr [expr rand()] * 100000000])]"
set owner2 "$hid-2"
putmsg stdout 1 "getclientid: verifier=($verf2), owner=($owner2)"
set status [setclient $verf2 $owner2 cid2 cidverf2 res {0 0 0}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Setclientid failed on reset"
	putmsg stderr 0 "\t\t assertions (m's) will not run."
	putmsg stdout 1 "\t\t res=($res)"
} else {
	logres PASS

# ... and continue
# f2: Now try a conflict LOCKT w/unconfirmed cid2, new lowner2
set expcode "EXPIRED"
set ASSERTION "Conflict LOCKT w/unconfirmed cid2, lowner2, expect $expcode"
set tag "$TNAME{f2}"
putmsg stdout 0 "$tag: $ASSERTION"
incr lseqid
set lowner2 "$lowner-2"
set res [compound {Putfh $nfh; Lockt 2 $cid2 $lowner2 10 200}]
ckres "LockT" $status $expcode $res $PASS

# f3: LOCKT with cid1/lowner2, expect DENIED
set expcode "DENIED"
set ASSERTION "LOCKT with cid1/lowner2, expect $expcode"
set tag "$TNAME{f3}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 2 $cid $lowner2 10 200}]
ckres "LockT" $status $expcode $res $PASS

# f4: LOCKT with confirmed cid2/lowner1, expect DENIED
set expcode "DENIED"
set ASSERTION "LOCKT w/confirmed cid2/lowner1, expect $expcode"
set tag "$TNAME{f4}"
putmsg stdout 0 "$tag: $ASSERTION"
# confirm the clientid-2
set status [setclientconf $cid2 $cidverf2 res]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Setclientid_confirm failed on cid2"
	putmsg stdout 0 "\t\t res=($res)"
} else {
	set res [compound {Putfh $nfh; Lockt 2 $cid2 $lowner 10 200}]
	ckres "LockT" $status $expcode $res $PASS
}

# f5: Check upgrade a section to LOCK(W) w/lsid, expect OK
set expcode "OK"
set ASSERTION "Check upgrade a section to LOCK(W) w/lsid, expect $expcode"
set tag "$TNAME{f5}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 2 F 10 16 F $lsid $lseqid "$oseqid $cid $lowner"}]
if { [ckres "Lock(W)" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]

	# f6: Write using still valid lock-stateid, expect OK
	set expcode "OK"
	set ASSERTION "Write using still valid lock-stateid, expect $expcode"
	set tag "$TNAME{f6}"
	putmsg stdout 0 "$tag: $ASSERTION"
	set res [compound {Putfh $nfh; Write $lsid 5 f a "$tag"}]
	ckres "Write" $status $expcode $res $PASS
} else {
	putmsg stderr 0 "\t Lock(W) failed, assertion f4 did not run"
	putmsg stderr 1 "\t res=($res)"
}


}


# Wait for lease time to expire
putmsg stdout 0 \
  "\n  ** Now wait for lease($leasetm) to expire, then do following (l's):"
exec sleep [expr $leasetm + 10]

# l1: Now try to LOCK again w/lock_sid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Now try to LOCK w/lock_sid, expect $expcode"
set tag "$TNAME{l1}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 20
set res [compound {Putfh $nfh; 
	Lock 2 F 1024 10 F $lsid $lseqid "$oseqid $cid $lowner"}]
ckres "Lock" $status $expcode $res $PASS

# l2: Now try to LOCKT w/cid & lowner, expect STALE_CLIENTID
set expcode "STALE_CLIENTID"
set ASSERTION "Now try to LOCKT w/cid & lowner, expect $expcode"
set tag "$TNAME{l2}"
putmsg stdout 0 "$tag: $ASSERTION"
#incr lseqid
#set res [compound {Putfh $nfh; Lockt 1 $cid $lowner 10 200}]
#ckres "Lockt" $status $expcode $res $PASS
putmsg stdout 0 "\t Test UNSUPPORTED: invalid in Solaris"
putmsg stdout 1 "\t   This assertion is based on the variability of"
putmsg stdout 1 "\t   interpretation for the server implementation."

# l3: try to Read the file w/osid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "try to Read the file w/osid, expect $expcode"
set tag "$TNAME{l3}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Read $lsid 10 100}]
ckres "Read" $status $expcode $res $PASS

# l4: Now try to unLOCK the file w/lsid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Now try to unLOCK the file w/lsid, expect $expcode"
set tag "$TNAME{l4}"
putmsg stdout 0 "$tag: $ASSERTION"
incr lseqid
set res [compound {Putfh $nfh; Locku 1 $lseqid $lsid 10 200}]
ckres "Locku" $status $expcode $res $PASS

putmsg stdout 0 \
  "\n  ** Reset the clientid(w/confirm) w/new hid and do following(m's):"

# m1: Reset and confirm clientid w/new hid, expect OK
set expcode "OK"
set ASSERTION "Reset and confirm clientid w/new hid, expect $expcode"
set tag "$TNAME{m1}"
putmsg stdout 0 "$tag: $ASSERTION"
set cid2 [getclientid $hid-2]
if {$cid2 == -1} {
        putmsg stderr 0 "\t Test UNRESOLVED: getclientid failed on reset"
        putmsg stderr 0 "\t\t assertions (m's) will not run."
} else {
        logres PASS

# ... and continue
# m2: Now try a conflict LOCKT w/new cid and new lowner, expect OK
set expcode "OK"
set ASSERTION "Now try a conflict LOCKT w/new cid+lowner, expect $expcode"
set tag "$TNAME{m2}"
putmsg stdout 0 "$tag: $ASSERTION"
incr lseqid
set lowner3 "$lowner-m2"
set res [compound {Putfh $nfh; Lockt 2 $cid2 $lowner3 10 200}]
ckres "LockT" $status $expcode $res $PASS


# m3: new LOCK(WRITE) test file w/new cid, but osid,
#	expect STALE_STATEID|STALE_CLIENTID|EXPIRED
set expcode "STALE_STATEID|STALE_CLIENTID|EXPIRED"
set ASSERTION "new LOCK(WRITE) w/new cid, but osid, expect $expcode"
set tag "$TNAME{m3}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 10
set lowner "lowner.[pid]-m"
set res [compound {Putfh $nfh; 
	Lock 2 F 512 1024 T $osid $lseqid "$oseqid $cid2 $lowner"}]
ckres "Lock(W)" $status $expcode $res $PASS

# m4: re-Open test file w/new cid to get new-osid, expect OK
set expcode "OK"
set ASSERTION "Open(& confirm if needed) file w/new cid, expect $expcode"
set tag "$TNAME{m4}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 5
set nfh [basic_open $bfh $TFILE 0 "$cid2 $open_owner" osid2 oseqid2 status \
	$seqid 0 664 $fs]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test FAIL: basic_open2 failed, status=($status)"
	exit $FAIL
} else {
	putmsg stderr 0 "\t Test PASS"
	set oseqid2 [expr $oseqid2 + 1]
}

# m5: LOCK(WRITE) again w/new cid & new osid, expect OK
set expcode "OK"
set ASSERTION "LOCK(WRITE) again w/new cid & new osid, expect $expcode"
set tag "$TNAME{m5}"
putmsg stdout 0 "$tag: $ASSERTION"
set off 512
set res [compound {Putfh $nfh; 
	Lock 2 F $off 1024 T $osid2 $lseqid "$oseqid2 $cid2 $lowner"}]
if { [ckres "Lock(W)" $status $expcode $res $PASS] == "true" } {
	set lsid2 [lindex [lindex $res 1] 2]
	set lseqid [expr $lseqid + 1]
	incr oseqid2
} else {
	putmsg stderr 0 "\t ... following assertions may fail unexpectedly."
	putmsg stderr 1 "\t res=($res)"
}

# m6: WRITE some data w/new cid & new osid, expect OK
set expcode "OK"
set ASSERTION "WRITE some data w/new cid & new lsid, expect $expcode"
set tag "$TNAME{m6}"
putmsg stdout 0 "$tag: $ASSERTION"
set data [string repeat "m" 256]
set res [compound {Putfh $nfh; Write $lsid2 $off f a $data}]
ckres "Write" $status $expcode $res $PASS

# m7: SETATTR to truncate the file w/new lsid2, expect OK
set expcode "OK"
set ASSERTION "SETATTR to truncate the file w/new lsid, expect $expcode"
set tag "$TNAME{m7}"
putmsg stdout 0 "$tag: $ASSERTION"
set nfz [expr $off + 16]
set res [compound {Putfh $nfh; Setattr $lsid2 {{size $nfz} {mode 0600}} }]
ckres "Setattr" $status $expcode $res $PASS

# m8: try LOCKU portion w/new lsid, expect OK
set expcode "OK"
set ASSERTION "Now LOCKU ($off,10) w/new lsid, expect $expcode"
set tag "$TNAME{m8}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid2 $off 10}]
ckres "Locku" $status $expcode $res $PASS

# m9: try to Close file w/old osid, expect BAD_STATEID|EXPIRED
set expcode "BAD_STATEID|EXPIRED"
set ASSERTION "try to Close file w/old osid, expect $expcode"
set tag "$TNAME{m9}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid $osid}]
ckres "Close(old-osid)" $status $expcode $res $PASS

# m0: Finally Close it with good osid, expect OK
set expcode "OK"
set ASSERTION "Finally Close it w/good osid, expect $expcode"
set tag "$TNAME{m0}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid2 $osid2}]
ckres "Close(new-osid)" $status $expcode $res $PASS


}
  

# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
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
