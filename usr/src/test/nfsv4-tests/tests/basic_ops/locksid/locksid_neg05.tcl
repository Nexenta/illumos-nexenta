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
	putmsg stdout 0 "$TNAME: test setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($TFILE)"
	putmsg stderr 0 "\t\t basic_open failed, status=($status)."
	exit $UNRESOLVED
}
set oseqid [expr $oseqid + 1]

# Set a lock(R) in whole file for testing
set lowner "[pid].lo"
set lseqid 1
set ltype 1
set res [compound {Putfh $nfh; 
	Lock $ltype F 0 $fsize T $osid $lseqid "$oseqid $cid $lowner"}]
if { $status != "OK" } {
	putmsg stdout 0 "$TNAME: test setup - lock(R) for following testing"
	putmsg stderr 0 "\t Test UNRESOLVED: Lock() returned status=($status)"
	putmsg stderr 1 "\t\t  Res=($res)"
	exit $UNRESOLVED
}
set lsid [lindex [lindex $res 1] 2]
set lseqid [expr $lseqid + 1]
incr oseqid


# Start testing
# --------------------------------------------------------------
# a: Lock(W,12,99) with different lowner, expect DENIED
set expcode "DENIED"
set ASSERTION "Lock(W,12,99) with different lowner, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set lowner2 "$lowner-2"
set lseqid2 1
set res [compound {Putfh $nfh; 
	Lock 2 F 12 99 T $osid $lseqid2 "$oseqid $cid $lowner2"}]
if { $status != "DENIED" } {
	putmsg stderr 0 "\t Test FAIL: Lock(W) returned status=($status)"
	putmsg stderr 1 "\t  Res=($res)"
	set exp ""
} else {
	# Check for conflict info
	set olt [lindex [lindex $res 1] 2]
	set exp [list 0 $fsize $ltype]
	if { $olt != $exp } {
		putmsg stderr 0 \
	"\t Test FAIL: good return status, but conflict off/len/type incorrect"
		putmsg stderr 0 "\t   exp=($exp), got=($olt)"
		putmsg stderr 1 "\t   Res=($res)"
	} else {
		set ncid [lindex [lindex [lindex $res 1] 3] 0]
		if { $ncid != $cid } {
			putmsg stderr 0 \
	"\t Test FAIL: good return status, conflict cid incorrect"
			putmsg stderr 0 "\t   exp=($cid), got=($ncid)"
			putmsg stderr 1 "\t   Res=($res)"
		} else {
			logres "PASS"
		}
	}
}
 
# b: Lockt(W) with different lowner, expect DENIED
set expcode "DENIED"
set ASSERTION "Lockt(W,88,10) with different lowner, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set lowner3 "$lowner-3"
set res [compound {Putfh $nfh; Lockt 2 $cid $lowner3 88 10}]
if { $status != "DENIED" } {
	putmsg stderr 0 "\t Test FAIL: Lockt(W) returned status=($status)"
	putmsg stderr 1 "\t  Res=($res)"
} else {
	# Check for conflict info
	set olt [lindex [lindex $res 1] 2]
	if { $olt != $exp } {
		putmsg stderr 0 \
	"\t Test FAIL: good return status, but conflict off/len/type incorrect"
		putmsg stderr 0 "\t   exp=($exp), got=($olt)"
		if { $exp == ""} {
			putmsg stderr 0 \
			    "\t     the previous LOCK was not set correctly?"
		}
		putmsg stderr 1 "\t   Res=($res)"
	} else {
		set ncid [lindex [lindex [lindex $res 1] 3] 0]
		if { $ncid != $cid } {
			putmsg stderr 0 \
	"\t Test FAIL: good return status, conflict cid incorrect"
			putmsg stderr 0 "\t   exp=($cid), got=($ncid)"
			putmsg stderr 1 "\t   Res=($res)"
		} else {
			logres "PASS"
		}
	}
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
