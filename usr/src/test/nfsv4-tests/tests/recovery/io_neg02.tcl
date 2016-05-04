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
	"$tag: Open a regular file and its states, then bring down the server."
set bfh [get_fh "$BASEDIRS"]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$tag: getclientid failed"
	putmsg stdout 0 "\t Test UNRESOLVED: unable to get clientid"
	putmsg stdout 1 "\t owner=<$TNAME.[pid]>"
	cleanup $UNRESOLVED
}
set seqid 1
set owner "$TNAME-OpenOwner"

# First Open a regular file to establish some state
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner" \
		    {0 0 {{mode 0777}}} {0 "$env(RWFILE)"}; Getfh}]
putmsg stderr 1 "compound {Putfh $bfh; Open $seqid 3 0 \"$cid $owner\""
putmsg stderr 1 "{0 0 {{mode 0777}}} {0 \"$env(RWFILE)\"}; Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
if {$status != "OK"} {
	putmsg stdout 0 "$tag: open regular file"
	putmsg stdout 0 "\t Test UNRESOLVED: Open failed, status=($status)"
	cleanup $UNRESOLVED
}

# Reboot the server
putmsg stdout 0 "  ** Start to reboot the server ..."
reboot_server [file join $env(TMPDIR) $TNAME.tmp.[pid]] $tag
putmsg stdout 0 "  ** Now wait for server daemon to come up ..."
is_nfsd_up $tag
putmsg stdout 0 \
	"  ** then run the following assertions within the GRACE period:"

set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$tag: getclientid failed"
	putmsg stdout 0 "\t Test UNRESOLVED: unable to get clientid"
	putmsg stdout 1 "\t owner=<$TNAME.[pid]>"
	cleanup $UNRESOLVED
}

# Start testing
# --------------------------------------------------------------
# a: Open(reclaim) when <cfh>=dir during GRACE, expect GRACE
set expcode "ISDIR|GRACE"
set ASSERTION "Open(reclaim) when <cfh>=dir during GRACE, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

# Now try to Open <cfh>=dir after reboot
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner" \
		    {0 0 {{mode 0777}}} {1 0}}]
putmsg stderr 1 "compound {Putfh $bfh; Open $seqid 3 0 \"$cid $owner\""
putmsg stderr 1 "{0 0 {{mode 0777}}} {1 0}}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
ckres "Open" $status $expcode $res $PASS

# b: Open(reclaim) w/<cfh> not from open , expect OK
set expcode "OK"
set ASSERTION "Open(reclaim) w/<cfh> not from open, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"

set res [compound {
	Putfh $bfh;
	Lookup $env(ROFILE);
	Open $seqid 1 0 "$cid $owner-100" {0 0 {{mode 0666}}} {1 0};
	Getfh; Putfh $bfh; Lookup $env(ROFILE); Getfh}]
putmsg stderr 1 "compound {Putfh $bfh; Lookup $env(ROFILE);"
putmsg stderr 1 \
	"Open $seqid 1 0 \"$cid $owner-100\" {0 0 {{mode 0666}}} {1 0};"
putmsg stderr 1 "Getfh; Putfh $bfh; Lookup $env(ROFILE); Getfh}"
putmsg stderr 1 "\tstatus=$status; res=$res"
putmsg stderr 1 "\t[clock format [clock seconds]]"
set cont [ckres "Open" $status $expcode $res $FAIL]

if {$cont == "true"} {
   # verify the FH of OPEN is good (to close) and is same as LOOKUP
   set stateid [lindex [lindex $res 2] 2]
   set rflags [lindex [lindex $res 2] 4]
   set fh1 [lindex [lindex $res 3] 2]
   set fh2 [lindex [lindex $res 6] 2]
   incr seqid
   set cont [ckclose $fh1 $rflags $seqid $stateid]
   if {$cont == "true"} {
      fh_equal $fh1 $fh2 $cont $PASS
   }
}

# --------------------------------------------------------------
# All are good; so exit PASS
cleanup $PASS
