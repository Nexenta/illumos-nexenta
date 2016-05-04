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
# NFSv4 server state recovery test - XXX recovery

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set TFILE "$TNAME.[pid]"

# Get server lease time
set leasetm $LEASE_TIME

# --------------------------------------------------------------
# clean proc to removed created tmp file
proc cleanup { exitcode } {
    global bfh TFILE WARNING

    # remove tmp file
    set res [compound {Putfh $bfh; Remove $TFILE}]
    if {($status != "OK") && ($status != "NOENT")} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        set exitcode $WARNING
    }

    # disconnect and exit
    Disconnect
    exit $exitcode
}

putmsg stdout 0 \
  "\n  ** Frist basic setup for $TNAME, if fails, program will exit ..."

# Start testing
# --------------------------------------------------------------
# a: Setclientid/Setclient_confirm, expect OK
set expcode "OK"
set ASSERTION "Setclientid/Setclient_confirm, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set hid "[pid][expr int([expr [expr rand()] * 100000000])]"
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
set fs 8192
set open_owner $TFILE
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" osid oseqid status \
	$seqid 0 664 $fs]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test FAIL: basic_open failed, status=($status)"
	cleanup $FAIL
} else {
	putmsg stderr 0 "\t Test PASS"
	set oseqid [expr $oseqid + 1]
}

# c: LOCK(lower-1) the test file w/cid+osid, expect OK
set expcode "OK"
set ASSERTION "LOCK(lower-1) the test file w/cid+osid, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set lowner1 "lowner.[pid]-1"
set res [compound {Putfh $nfh; 
	Lock 1 F 0 512 T $osid $lseqid "$oseqid $cid $lowner1"}]
if { [ckres "Lock(lo1)" $status $expcode $res $PASS] != "true" } {
	cleanup $FAIL
}
set lsid1 [lindex [lindex $res 1] 2]
incr oseqid

# d: conflict LOCK(lower-2) file w/cid+osid, expect DENIED
set expcode "DENIED"
set ASSERTION "conflict LOCK(lower-2) file w/cid+osid, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid2 20
set lowner2 "lowner.[pid]-2"
set res [compound {Putfh $nfh; 
	Lock 2 F 0 10 T $osid $lseqid2 "$oseqid $cid $lowner2"}]
if { [ckres "Lock(lo2)" $status $expcode $res $PASS] != "true" } {
	cleanup $FAIL
}


putmsg stdout 0 \
  "\n  ** Reset the clientid w/new hid and do following assertions."

# h: Reset cid Setclientid w/new hid, expect OK
set expcode "OK"
set ASSERTION "Reset clientid Setclientid w/new hid, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set newverf "3388[pid]"
set cid2 ""
set cidverf2 ""
set status [setclient $newverf $hid cid2 cidverf2 res]
if { [ckres "Setclientid(2)" $status $expcode $res $PASS] != "true" } {
	cleanup $FAIL
}
set cid2 [lindex [lindex $res 0] 2]


# Verify states in server are not clear until Setclient_confirm.
# i: try conflict LOCK(lower-2) again w/out confirm, expect DENIED
set expcode "DENIED"
set ASSERTION "conflict LOCK(lower-2) again w/out confirm, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
incr lseqid2
incr oseqid
set res [compound {Putfh $nfh; 
	Lock 2 F 0 10 T $osid $lseqid2 "$oseqid $cid2 $lowner2"}]
if { [ckres "Lock(lo3)" $status $expcode $res $PASS] != "true" } {
	cleanup $FAIL
}

# j: Now confirm the new clientid, expect OK
set expcode "OK"
set ASSERTION "Now confirm the new clientid, expect $expcode"
putmsg stdout 0 "$TNAME{j}: $ASSERTION"
set status [setclientconf $cid2 $cidverf2 res]
if { [ckres "Setclientid_confirm(2)" $status $expcode $res $PASS] != "true" } {
	cleanup $FAIL
}

# k: then try conflict LOCK again w/old-osid,
#	expect STALE_STATEID|STALE_CLIENTID|EXPIRED
set expcode "STALE_STATEID|STALE_CLIENTID|EXPIRED"
set ASSERTION "then try conflict LOCK again w/old-osid, expect $expcode"
putmsg stdout 0 "$TNAME{k}: $ASSERTION"
incr lseqid2
set res [compound {Putfh $nfh; 
	Lock 2 F 0 10 T $osid $lseqid2 "$oseqid $cid2 $lowner2"}]
ckres "Lock(lo4)" $status $expcode $res $PASS

# l: Open the file again w/new confirmed cid, expect OK
set expcode "OK"
set ASSERTION "Open(& confirm if needed) file w/new cid, expect $expcode"
putmsg stdout 0 "$TNAME{l}: $ASSERTION"
set seqid 100
set nfh2 [basic_open $bfh $TFILE 0 "$cid2 $open_owner" osid2 oseqid2 status]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test FAIL: basic_open again failed"
	putmsg stderr 0 "\t   status=($status)"
	cleanup $FAIL
} else {
	putmsg stderr 0 "\t Test PASS"
	set oseqid2 [expr $oseqid2 + 1]
}

# m: try conflict LOCK one more time w/new-osid, expect OK
set expcode "OK"
set ASSERTION "try conflict LOCK one more time w/new-osid, expect $expcode"
putmsg stdout 0 "$TNAME{m}: $ASSERTION"
incr lseqid2
set res [compound {Putfh $nfh2; 
	Lock 2 F 0 10 T $osid2 $lseqid2 "$oseqid2 $cid2 $lowner2"}]
ckres "Lock(lo5)" $status $expcode $res $PASS
incr oseqid2

# n: try to Close the file with old osid, expect OLD_STATEID
set expcode "OLD_STATEID"
set ASSERTION "try to Close file w/old osid, expect $expcode"
putmsg stdout 0 "$TNAME{n}: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid2 $osid}]
ckres "Close(old-osid)" $status $expcode $res $PASS

# o: Finally Close it with good osid, expect OK
set expcode "OK"
set ASSERTION "Finally Close it w/good osid, expect $expcode"
putmsg stdout 0 "$TNAME{o}: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid2 $osid2}]
ckres "Close(new-osid)" $status $expcode $res $PASS

cleanup $PASS
