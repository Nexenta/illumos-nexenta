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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 RELEASE_LOCKOWNER operation test - negative tests

# include all test enironment
source RELEASE_LOCKOWNER.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set leasetm $LEASE_TIME
set bfh [get_fh "$BASEDIRS"]
set hid "[pid][expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $hid]
if {$cid == -1} {
        putmsg stderr 0 "$TNAME: setup - getclientid"
        putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
        exit $UNRESOLVED
}
# Create a test file and get its osid
set TFILE "$TNAME.[pid]"
set oowner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set nfh [basic_open $bfh $TFILE 1 "$cid $oowner" osid oseqid status \
        1 0 664 1024]
if {$nfh == -1} {
        putmsg stderr 0 "$TNAME: setup - basic_open"
        putmsg stderr 0 "\t Test UNRESOLVED: status=($status)"
        exit $UNRESOLVED
}
set oseqid [expr $oseqid + 1]
set lseqid 1
set lowner "$TNAME-lower.[pid]"


# Start testing
# --------------------------------------------------------------
# a: Release_lockowner w/new lock in file, expect LOCKS_HELD
set expcode "LOCKS_HELD"
set ASSERTION "Release_lockowner w/new lock in file, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
# First set a lock with the lock owner
set res [compound {Putfh $nfh; 
        Lock 1 F 0 100 T $osid $lseqid "$oseqid $cid $lowner"}]
if { [ckres "Lock(R)" $status "OK" $res $FAIL] != "true" } {
        set lsid {11 22}
} else {
	set lsid [lindex [lindex $res 1] 2]
        incr lseqid
        incr oseqid
	set res [compound {Release_lockowner $cid $lowner}]
	ckres "Release_lockowner" $status $expcode $res $PASS 
}

# b: Release_lockowner w/1 byte locked in file, expect LOCKS_HELD
set expcode "LOCKS_HELD"
set ASSERTION "Release_lockowner w/1-byte still locked, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
# Check if lock_stateid is valid
if { [lindex $lsid 1] == "22" } {
        putmsg stderr 0 "\t Test UNINITIATED: invalid lsid from previous run"
        putmsg stderr 0 "\t lsid=($lsid)"
} else {
	set res [compound {Putfh $nfh; Locku 1 $lseqid $lsid 0 99; 
		Release_lockowner $cid $lowner}]
	ckres "Release_lockowner/Locku" $status $expcode $res $PASS
	# Release all the locks in the file
	set lsid [lindex [lindex $res 1] 2]
	incr lseqid
	compound {Putfh $nfh; Locku 1 $lseqid $lsid 99 1}
}

# c: Release_lockowner w/invalid clientid, expect STALE_CLIENTID
set expcode "STALE_CLIENTID"
set ASSERTION "Release_lockowner w/invalid clientid, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set icid "xxxxxx"
set res [compound {Release_lockowner $icid $lowner}]
ckres "Release_lockowner" $status $expcode $res $PASS

# d: Release_lockowner w/expired clientid, expect EXPIRED
set expcode "EXPIRED"
set ASSERTION "Release_lockowner w/expired clientid, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
# wait for lease to expire and try the op again
after [expr [expr $leasetm + 1 ] * 1000]
set res [compound {Release_lockowner $cid $lowner}]
if { $status == "OK" } {
	putmsg stderr 0 "\t WARNING: The server return OK. Maybe the lockowner had been reaped"
	putmsg stderr 0 "\t          before the server received the release_lockowner request"
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
	putmsg stdout 0 "\t Test PASS"
} else {
	ckres "Release_lockowner" $status $expcode $res $PASS
}


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
