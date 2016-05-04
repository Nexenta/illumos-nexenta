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

# global var
global OPEN4_RESULT_CONFIRM

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
	1 0 666 $fsize]
if {$nfh == -1} {
	putmsg stdout 0 "$tag: basic_open"
	putmsg stdout 0 "\t Test UNRESOLVED: status=($status)"
	cleanup $UNRESOLVED
}

# Reboot the server
putmsg stdout 0 "  ** Start to reboot the server ..."
reboot_server [file join $env(TMPDIR) $TNAME.tmp.[pid]] $tag
putmsg stdout 0 "  ** Now wait for server daemon to come up ..."
is_nfsd_up $tag
putmsg stdout 0 \
	"  ** then run the following assertions within the GRACE period:"

set cid [getclientid $owner]
if {$cid == -1} {
	putmsg stdout 0 "$tag: getclientid failed"
	putmsg stdout 0 "\t Test UNRESOLVED: unable to get clientid"
	putmsg stdout 1 "\t owner=<$owner>"
	cleanup $UNRESOLVED
}

# Start testing
# --------------------------------------------------------------
# a: Recovery after Open w/reclaim op during grace period test, expect GRACE
set expcode "GRACE"
set ASSERTION \
    "Recovery after Open w/reclaim op during grace period test, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

# Re-open same test file and get its osid
set oseqid 10
set res [compound {Putfh $nfh; \
	Open $oseqid 3 0 "$cid $owner" {0 0 {{mode 0666}}} {1 0}; Getfh}]
putmsg stderr 1 "compound {Putfh $nfh;"
putmsg stderr 1 \
	"Open $oseqid 3 0 \"$cid $owner\" {0 0 {{mode 0666}}} {1 0}; Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
set cont [ckres "Open" $status "OK" $res $FAIL]

if {$cont == "true"} {
   set osid [lindex [lindex $res 1] 2]
   set rflags [lindex [lindex $res 1] 4]
   putmsg stderr 1 "osid=$osid"
   putmsg stderr 1 "rflags=$rflags"
  
   if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	putmsg stderr 1 \
		"   unexpected request for an Open_confirm, rflags=($rflags)"
	putmsg stderr 1 "\tRes: $res"
	putmsg stdout 0 "\t Test FAIL"
	return -2
   } else {
	putmsg stdout 0 "\t Test PASS"
   }
}

# b: Recovery after Read operation during grace period test, expect GRACE
set expcode "GRACE"
set ASSERTION \
    "Recovery after Read operation during grace period test, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"

set res [compound {Putfh $bfh; Lookup $TFILE; Read $osid 0 1024}]
putmsg stderr 1 "compound {Putfh $bfh; Lookup $TFILE; Read $osid 0 1024}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
ckres "Read" $status $expcode $res $PASS

# c: Recovery after Write Op during the grace period test, expect GRACE
set expcode "GRACE"
set ASSERTION \
    "Recovery after Write Op during the grace period test, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"

set count 1023
set data [string repeat "a" $count]
set res [compound {Putfh $nfh; Write $osid 0 f a $data; Getfh}]
putmsg stderr 1 "compound {Putfh $nfh; Write $osid 0 f a $data; Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
ckres "Write" $status $expcode $res $PASS

# d: Recovery after Setattr Op during the grace period test, expect GRACE
set expcode "GRACE"
set ASSERTION \
    "Recovery after Setattr Op during the grace period test, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"

set nsize [expr $fsize - 16]
set res [compound {Putfh $nfh; Setattr $osid {{size $nsize}}; Getfh}]
putmsg stderr 1 "compound {Putfh $nfh; Setattr $osid {{size $nsize}}; Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
ckres "Setattr" $status $expcode $res $PASS

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
