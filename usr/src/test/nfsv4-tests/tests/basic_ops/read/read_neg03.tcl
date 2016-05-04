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
# NFSv4 READ operation test - more negative tests
#	verify SERVER errors returned with invalid read.

# include all test enironment
source READ.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

set hid "[pid][clock seconds]"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}


# Test assertions 
# --------------------------------------------------------------
# b: Test READ w/OPEN,LOCK-1,LOCK-2,READ(LOCK-1-stateid), expect OLD_STATEID
#
proc assertion_b { Tfile } {
    global TNAME bfh PASS cid

    set expcode "OLD_STATEID"
    set ASSERTION \
	"READ w/OPEN,LOCK-1,LOCK-2,READ(LOCK-1-sid), expect $expcode"
    set tag "$TNAME{b}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set owner "owner[pid]-b"
    # open a file to get the stateid
    set nfh [basic_open $bfh $Tfile 1 "$cid $owner" osid oseqid status]
    if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=$status."
	return
    }
    # Set a lock on the file w/lower1
    set oseqid [expr $oseqid + 1]
    set lower1 "$owner-l1"
    set lseqid 1
    set res [compound {Putfh $nfh; 
	Lock 1 F 2 16 T $osid $lseqid {$oseqid $cid $lower1}}]
    if {$status !=  "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Lock1 failed, status=($status)"
	putmsg stderr 1 "\t   Res: $res"
	return
    }
    set lsid1 [lindex [lindex $res 1] 2]
    incr oseqid
    incr lseqid
    set res [compound {Putfh $nfh; 
	Lock 1 F 10 16 F $lsid1 $lseqid {$oseqid $cid $lower1}}]
    if {$status !=  "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Lock2 failed, status=($status)"
	putmsg stderr 1 "\t   Res: $res"
	return
    }
    # Now try to READ with Lock-stateid-1
    set res [compound {Putfh $nfh; Read $lsid1 0 64}]
    ckres "Read" $status $expcode $res $PASS
    set res [compound {Putfh $nfh; Close $oseqid $osid}]
}


# e: Read w/file opened WRITE only - expect OPENMODE
#
proc assertion_e { Tfile } {
    global TNAME bfh PASS cid

    set expcode "OPENMODE"
    set ASSERTION "Read w/file opened accsss=W, deny=0, expect $expcode"
    set tag "$TNAME{e}"
    putmsg stdout 0 "$tag: $ASSERTION"

    # open a RW file with WRITE only access:
    set oowner "[pid][expr [clock seconds] / 2]"
    set nfh [basic_open $bfh $Tfile 1 "$cid $oowner" \
	osid oseqid status 1 0 666 0 2]
    if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=$status."
	return
    }

    # Now try to read this file:
    set res [compound {Putfh $nfh; Read $osid 0 10}]
    if { $status == "OK"} {
	# Some servers allow this, so must check another open w/deny=R
	set oowner2 "oowner2[pid]"
    	set nfh2 [basic_open $bfh $Tfile 0 "$cid $oowner2" \
		osid2 oseqid2 status 100 0 666 0 2 1]
	if {$nfh2 == -1} {
		putmsg stderr 0 \
		    "\t Test UNRESOLVED: basic_open2 failed, status=$status."
		incr oseqid
    		set res [compound {Putfh $nfh; Close $oseqid $osid}]
    		putmsg stderr 1 "Close1 res=$res"
		return
	}
	# Now try to read this file:
    	set res [compound {Putfh $nfh; Read $osid 0 10}]
	ckres "Read" $status $expcode $res $PASS
    } else {
	ckres "Read" $status $expcode $res $PASS
    }
}


# z: Read a file when lease expired - expect EXPIRED|STALE_STATEID
# 	(run last as it expires the lease)
#
proc assertion_z { Tfile } {
    global TNAME bfh PASS cid LEASE_TIME

    set expcode "EXPIRED|STALE_STATEID"
    set ASSERTION "Read a file when lease expired, expect $expcode"
    set tag "$TNAME{z}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set leasetm $LEASE_TIME
    # open a file to get the stateid
    set owner "$tag-[pid]-zz"
    set nfh [basic_open $bfh $Tfile 0 "$cid $owner" osid oseqid status]
    if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=$status."
	return
    }
    # wait for lease time to expired; then read
    putmsg stdout 1 "  wait for lease time to expire, then read"
    after [expr ($leasetm + 18) * 1000]
    set res [compound {Putfh $nfh; Read "$osid" 0 64}]
    ckres "Read" $status $expcode $res $PASS
}


# Start testing
# --------------------------------------------------------------

set TFileb "tfile-b.[pid]"
assertion_b $TFileb
set TFilee "tfile-e.[pid]"
assertion_e $TFilee
assertion_z $env(RWFILE)

# Cleanup the temp file:
set res [compound {Putfh $bfh; Remove $TFileb; Remove $TFilee}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove tmp files failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
