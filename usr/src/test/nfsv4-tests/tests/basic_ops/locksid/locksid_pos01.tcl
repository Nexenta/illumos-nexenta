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
#   Basic fucntion of LOCK, LOCKT, LOCKU op (same owner)

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
set fsize 8192
set nfh [basic_open $bfh $TFILE 1 "$cid $owner" osid oseqid status \
	1 0 664 $fsize]
if {$nfh == -1} {
	putmsg stderr 0 "$TNAME: setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: status=($status)"
	exit $UNRESOLVED
}
set oseqid [expr $oseqid + 1]
set lowner "$TNAME-lower.[pid]"
set lseqid 1


# Start testing
# --------------------------------------------------------------
# a: new LOCK(READ,0,100), expect OK
set expcode "OK"
set ASSERTION "new LOCK(READ,0,100), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 1 F 0 100 T $osid $lseqid "$oseqid $cid $lowner"}]
if { [ckres "Lock(R)" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	incr lseqid
	incr oseqid
} else {
	set lsid {11 22}
}

# b: another cross boundary LOCK(WRITE,88,100), expect OK
set expcode "OK"
set ASSERTION "another cross boundary LOCK(WRITE,88,100), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Lock 2 F 88 100 F $lsid $lseqid "$oseqid $cid $lowner"}]
if { [ckres "Lock(W)" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	incr lseqid
} else {
	set lsid {11 22}
}

# e: Lockt(same lowner) to check the R/W locks, expect OK
set expcode "OK"
set ASSERTION "Lockt(same lowner) to check the READ locks, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 1 $cid $lowner 10 77;
	Lockt 2 $cid $lowner 88 10}]
ckres "Lockt" $status $expcode $res $PASS

# f: Lockt(same lowner) on bondary locks, expect OK
set expcode "OK"
set ASSERTION "Lockt(same lowner) on bondary locks, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 1 $cid $lowner 80 22}]
ckres "Lockt" $status $expcode $res $PASS

# i: Locku(same lowner) on bondary locks, expect OK
set expcode "OK"
set ASSERTION "Locku(same lowner) on bondary locks, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 1 $lseqid $lsid 80 22}]
if { [ckres "Locku" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	incr lseqid
} else {
	set lsid {11 22}
}

# j: Locku(same lowner) whole file w/holes in it, expect OK
set expcode "OK"
set ASSERTION "Locku(same lowner) whole file w/holes, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid 0 $fsize}]
if { [ckres "Locku" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
}

# o: new-lowner to Lock(W) to verify no conflict locks, expect OK
set expcode "OK"
set ASSERTION "new-lowner to Lock(W) whole file, expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 100
set lowner2 "$lowner-2"
set res [compound {Putfh $nfh;
	Lock 1 F 0 $fsize T $osid $lseqid "$oseqid $cid $lowner2"}]
if { [ckres "Lock(W)" $status $expcode $res $PASS] == "true" } {
	set lsid [lindex [lindex $res 1] 2]
	incr lseqid
	incr oseqid
} else {
	set lsid {11 22}
}

# p: Now Close the file to clear the locks, expect OK|LOCKS_HELD
#	some server not support CLOSE that file still has record locks held
set expcode "OK|LOCKS_HELD"
set ASSERTION "Now Close file to clear the locks, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid $osid}]
set clst $status
if { ($env(SRVOS) == "Solaris") } {
	ckres "Close" $status "OK" $res $PASS
} else {
	ckres "Close" $status $expcode $res $PASS
}


# q: verify w/Lockt locks clear for orig-lowner, expect OK
set expcode "OK"
set ASSERTION "verify w/Lockt locks clear for orig-lowner, expect $expcode"
set tag "$TNAME{q}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 2 $cid $lowner 10 10000}]
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
