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
# NFSv4 SETATTR operation test - negative tests
#	verify SERVER errors returned with invalid Setattr op.

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}

# create a tmp file for manipulation
set tmpF "Sattr_tmpF.[pid]"
set owner "$TNAME-OpenOwner"
set tfh [basic_open $bfh $tmpF 1 "$cid $owner" osid oseqid status \
	1 0 664 88]
if {$tfh == -1} {
	putmsg stderr 0 "$TNAME: test setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: status=($status)"
	exit $UNRESOLVED
}
incr oseqid


# Start testing
# --------------------------------------------------------------
# a: Setattr with an invalid stateid for size changing, 
#	expect BAD_STATEID|STALE_STATEID
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Setattr w/invalid sid for changing size, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {22 812322}
set res [compound {Putfh $tfh; Setattr $stateid {{size 888}}; Getattr size}]
ckres "Setattr" $status $expcode $res $PASS


# b: Setattr(size) w/invalid stateid (seqid+1), expect BAD_STATEID
set expcode "BAD_STATEID"
set ASSERTION "Setattr(size) w/invalid stateid (seqid+1), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set bseqid [expr [lindex $osid 0] + 1]
set bosid "$bseqid [lindex $osid 1]"
putmsg stderr 1 "  new open_sid with trashed seqid: bosid=($bosid)"
set res [compound {Putfh $tfh; Setattr $bosid {{mode 0664} {size 1025}}; 
	Getattr size}]
ckres "Setattr" $status $expcode $res $PASS


# c: Setattr(size) w/invalid stateid (trashed other), expect BAD_STATEID
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Setattr(size) w/invalid stateid (trashed other), expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set newS ""
set oldS [lindex $osid 1]
set l [string length $oldS]
for {set i 0} {$i < $l} {incr i} {
    	append newS [string index $oldS end-$i]
}
set cosid "[lindex $osid 0] $newS"
putmsg stderr 1 "  new open_sid with trashed other: cosid=($cosid)"
set res [compound {Putfh $tfh; Setattr $cosid {{size 1}}}]
ckres "Setattr" $status $expcode $res $PASS


# g: Setattr(size) with stateid on a closed file, expect BAD_STATEID|OLD_STATEID
set expcode "BAD_STATEID|OLD_STATEID"
set ASSERTION "Setattr(size) w/stateid on a closed file, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
# first close the file
set res [compound {Putfh $tfh; Close $oseqid $osid}]
if {$status != "OK"} {
        putmsg stderr 0 "\t Test UNRESOLVED: CLOSE failed, status=($status)"
} else {
        set res [compound {Putfh $tfh; Setattr $osid {{size 333}}}]
        ckres "Setattr" $status $expcode $res $PASS
}


# i: try OPEN,LOCK-1,LOCK-2,SETATTR(LOCK-1-sid), expect OLD_STATEID
set expcode "OLD_STATEID"
set ASSERTION "try OPEN,LOCK-1,LOCK-2,SETATTR(LOCK-1-sid), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
# OPEN and LOCK(2 locks) the file:
set tmpFi "Sattr_tmpFi.[pid]"
set nfh [basic_open $bfh $tmpFi 1 "$cid $tmpFi" osid oseqid status]
if {$nfh == -1} {
    putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=($status)"
} else {
    incr oseqid
    set lowner1 "$owner-l1"
    set lseqid 1
    set res [compound {Putfh $nfh; 
	Lock 1 F 0 10 T $osid $lseqid {$oseqid $cid $lowner1}}]
    if {[ckres "Lock-1" $status "OK" $res $FAIL] == "true" } {
	# Get 2nd Lock
	set lsid1 [lindex [lindex $res 1] 2]
	set oseqid [expr $oseqid + 1]
	set lseqid [expr $lseqid + 1]
	set res [compound {Putfh $nfh; 
		Lock 2 F 16 10 F $lsid1 $lseqid {$oseqid $cid $lowner1}}]
	if {[ckres "Lock-2" $status "OK" $res $FAIL] == "true" } {
	    # now Setattr/size using $osid instead of $lock_sid
    	    set res [compound {Putfh $nfh; Setattr $lsid1 {{size 222}}}]
    	    ckres "Setattr" $status $expcode $res $PASS
    	    compound {Putfh $nfh; Close $oseqid $osid}
	}
    }
}


# m: Setattr(size) w/file open READ only, expect OPENMODE
set expcode "OPENMODE"
set ASSERTION "Setattr(size) w/file open READ only, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
# OPEN a file with access=READ
set oowner "[pid][expr [clock seconds] / 2]"
set nfh [basic_open $bfh $env(ROFILE) 0 "$cid $oowner" \
	osid oseqid status 1 0 666 0 1]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: open failed, status=($status)"
} else {
	# Now try to setattr size of this file:
	set res [compound {Putfh $nfh; Setattr $osid {{size 1023}}}]
	ckres "Setattr" $status $expcode $res $PASS
	incr oseqid
	set res [compound {Putfh $nfh; Close $oseqid $osid}]
	putmsg stderr 1 "  Close res=$res"
}


# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created file
set res [compound {Putfh $bfh; Remove $tmpF; Remove $tmpFi}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}
# disconnect and exit
Disconnect
exit $PASS
