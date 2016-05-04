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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 io client recovery tests - negative tests
#   io tests to test client recovery during grace period after server reboots.

# include common code and init section
source RECOV_proc

# Connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag $TNAME{setup}

# First check this test is not started before previous tests
# grace period ends.
ckgrace_period

putmsg stdout 0 \
	"$tag: Create a test file and its states, then bring down the server."
set bfh [get_fh "$BASEDIRS"]
set TFILE "$TNAME.[pid]"
set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $owner]
if {$cid == -1} {
	putmsg stdout 0 "$tag: getclientid failed"
	putmsg stdout 0 "\t Test UNRESOLVED: unable to get clientid"
	putmsg stdout 1 "\t owner=<$owner>"
	cleanup $UNRESOLVED
}

# Create a test file and get its osid
set fsize 8192
set nfh [basic_open $bfh $TFILE 1 "$cid $owner" osid oseqid status \
	1 0 664 $fsize]
if {$nfh == -1} {
	putmsg stdout 0 "$tag: basic_open"
	putmsg stdout 0 "\t Test UNRESOLVED: status=($status)"
	cleanup $UNRESOLVED
}
incr oseqid
set lowner "$tag.[pid]"
set lseqid 1

# Lock the file before server reboot
set res [compound {Putfh $nfh;
	Lock 2 F 0 100 T $osid $lseqid "$oseqid $cid $lowner"}]
putmsg stderr 1 "compound {Putfh $nfh;"
putmsg stderr 1 "Lock 2 F 0 100 T $osid $lseqid \"$oseqid $cid $lowner\"}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
if {$status != "OK"} {
	putmsg stdout 0 "$tag: original lock"
	putmsg stdout 0 "\t Test UNRESOLVED: original lock status=($status)"
	cleanup $UNRESOLVED
}
incr oseqid
incr lseqid

# Reboot the server
putmsg stdout 0 "  ** Start to reboot the server ..."
reboot_server [file join $env(TMPDIR) $TNAME.tmp.[pid]] $tag
putmsg stdout 0 "  ** Now wait for server daemon to come up ..."
is_nfsd_up $tag
putmsg stdout 0 \
	"  ** then run the following assertions within the GRACE period:"

# Start testing
# --------------------------------------------------------------
# a: Try open(reclaim) with different open-owner during GRACE, expect NO_GRACE
set expcode "NO_GRACE"
set ASSERTION \
    "Open(reclaim) w/different open-owner during GRACE, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

set towner "diff-owner.[pid]"
set cid [getclientid $towner]
if {$cid == -1} {
    putmsg stderr 0 "Test UNRESOLVED: failed to getclientid, owner=($towner)"
} else {
    set res [compound {Putfh $nfh; \
	Open $oseqid 3 0 "$cid $towner" {0 0 {{mode 0664}}} {1 0}; Getfh}]
    putmsg stderr 1 "compound {Putfh $nfh;"
    putmsg stderr 1 \
	"Open $oseqid 3 0 \"$cid $towner\" {0 0 {{mode 0664}}} {1 0}; Getfh}"
    putmsg stderr 1 "\tstatus=$status; res=$res"
    putmsg stderr 1 "\t[clock format [clock seconds]]"
    ckres "Open(reclaim-diff-oo)" $status $expcode $res $PASS
    if {$status == $expcode} {
	incr oseqid
    }
}

# b: Open(reclaim) with same open-owner during GRACE, expect OK
set expcode "OK"
set ASSERTION "Open(reclaim) w/same open-owner during GRACE, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"

set cid [getclientid $owner]
if {$cid == -1} {
    putmsg stderr 0 "Test UNRESOLVED: failed to getclientid, owner=($owner)"
} else {
    set res [compound {Putfh $nfh; \
	Open $oseqid 3 0 "$cid $owner" {0 0 {{mode 0664}}} {1 0}; Getfh}]
    putmsg stderr 1 "compound {Putfh $nfh;"
    putmsg stderr 1 \
	"Open $oseqid 3 0 \"$cid $owner\" {0 0 {{mode 0664}}} {1 0}; Getfh}"
    putmsg stderr 1 "\tstatus=$status; res=$res"
    putmsg stderr 1 "\t[clock format [clock seconds]]"
    ckres "Open(reclaim-same-oo)" $status $expcode $res $PASS
    if {$status == $expcode} {
	incr oseqid
	set newsid [lindex [lindex $res 1] 2]
	set open_sid $newsid
	set norun 0
    } else {
	putmsg stdout 0 \
		"\t Open(reclaim) failed, can't run following assertions"
	set norun 1
    }
}

# c: Lock(reclaim) during GRACE, expect OK
set expcode "OK"
set ASSERTION "Lock(reclaim) during GRACE, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"

if {$norun == 0} {
    set res [compound {Putfh $nfh;
	Lock 2 T 0 100 T $newsid $lseqid "$oseqid $cid $lowner"}]
    putmsg stderr 1 "compound {Putfh $nfh;"
    putmsg stderr 1 "Lock 2 T 0 100 T $newsid $lseqid \"$oseqid $cid $lowner\"}"
    putmsg stderr 1 "\tstatus=$status; res=$res"
    putmsg stderr 1 "\t[clock format [clock seconds]]"
    ckres "Lock(W)" $status $expcode $res $PASS
    if {[should_seqid_incr $status] == 1} {
	incr oseqid
	incr lseqid
    }
    if {$status == "OK"} {
	set newsid [lindex [lindex $res 1] 2]
    }
} else {
    putmsg stderr 0 "Test UNRESOLVED: Open(reclaim) failed, no valid states"
}
	
# d: Lock(reclaim) when <cfh>=dir during GRACE, expect ISDIR|GRACE|BAD_STATEID
set expcode "ISDIR|GRACE|BAD_STATEID"
set ASSERTION "Lock(reclaim) when <cfh>=dir during GRACE, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"

if {$norun == 0} {
    set lowner2 "$tag"
    set res [compound {Putfh $bfh;
	Lock 2 T 0 200 T $open_sid $lseqid "$oseqid $cid $lowner2"}]
    putmsg stderr 1 "compound {Putfh $bfh;"
    putmsg stderr 1 \
	"Lock 2 T 0 200 T $open_sid $lseqid \"$oseqid $cid $lowner2\"}"
    putmsg stderr 1 "\tstatus=$status; res=$res"
    putmsg stderr 1 "\t[clock format [clock seconds]]"
    ckres "Lock(W)" $status $expcode $res $PASS
    if {[should_seqid_incr $status] == 1} {
	incr oseqid
	incr lseqid
    }
    if {$status == "OK"} {
	set newsid [lindex [lindex $res 1] 2]
    }
} else {
    putmsg stderr 0 "Test UNRESOLVED: Open(reclaim) failed, no valid states"
}

# e: Lock(reclaim) w/file has no such lock
set expcode "OK"
set ASSERTION \
	"Lock(reclaim) w/file has no such lock during GRACE, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"

set owner "$tag-oowner"
set oseqid2 1
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh; \
	Open $oseqid2 3 0 "$cid $owner" {0 0 {{mode 0666}}} {1 0}; Getfh}]
putmsg stderr 1 "compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;"
putmsg stderr 1 \
	"Open $oseqid2 3 0 \"$cid $owner\" {0 0 {{mode 0666}}} {1 0}; Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
if {[should_seqid_incr $status] == 1} {
	incr oseqid2
}
if {$status != "OK" } {
	putmsg stdout 0 "\t Test FAIL: Open failed, status=($status)"
} else {
	set lseqid2 1
	set nsid2 [lindex [lindex $res 3] 2]
	set open_sid2 $nsid2
	set nfh2 [lindex [lindex $res 4] 2]

	# Now try to Lock(reclaim) on file w/no such lock after reboot
	set res [compound {Putfh $nfh2;
		Lock 2 T 0 100 T $nsid2 $lseqid2 "$oseqid2 $cid $lowner"}]
	putmsg stderr 1 "compound {Putfh $nfh2;"
	putmsg stderr 1 \
		"Lock 2 T 0 100 T $nsid2 $lseqid2 \"$oseqid2 $cid $lowner\"}"
	putmsg stderr 1 "\tstatus=$status; res=$res"
	putmsg stderr 1 "\t[clock format [clock seconds]]"
	ckres "Lock(W)" $status $expcode $res $PASS
	if {[should_seqid_incr $status] == 1} {
		incr oseqid2
		incr lseqid2
	}
	# wait for grace period to end.
	ckgrace_period OTHER
	if {$status == "OK"} {
		set nsid2 [lindex [lindex $res 1] 2]
		set res [compound {Putfh $nfh2; Locku 2 $lseqid2 $nsid2 0 100}]
		putmsg stderr 1 \
			"compound {Putfh $nfh2; Locku 2 $lseqid2 $nsid2 0 100}"
		putmsg stderr 1 "\tstatus=$status; res=$res"
		putmsg stderr 1 "\t[clock format [clock seconds]]"
		if {[should_seqid_incr $status] == 1} {
			incr oseqid2
			incr lseqid2
		}
	}
	set res [compound {Putfh $nfh2; Close $oseqid2 $open_sid2}]
	putmsg stderr 1 "compound {Putfh $nfh2; Close $oseqid2 $open_sid2}"
	putmsg stderr 1 "\tstatus=$status; res=$res"
	putmsg stderr 1 "\t[clock format [clock seconds]]"
}

# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set tag $TNAME{cleanup}
set res [compound {Putfh $bfh; Remove $TFILE}]
putmsg stderr 1 "compound {Putfh $bfh; Remove $TFILE"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
if { "$status" != "OK" } {
	putmsg stdout 0 "$tag:"
	putmsg stdout 0 "\t WARNING: cleanup to remove created tmp file failed"
	putmsg stdout 0 "\t   status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	cleanup $WARNING
}

# All are good; so exit PASS
cleanup $PASS
