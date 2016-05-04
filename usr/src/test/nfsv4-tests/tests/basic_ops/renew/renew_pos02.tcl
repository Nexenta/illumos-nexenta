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
# NFSv4 RENEW operation test - positive tests
#	verify ops that renew the lease

# include all test enironment
source RENEW.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag "$TNAME.setup"
set bfh [get_fh "$BASEDIRS"]

# a procedure for cleanup
proc do_cleanup {fname exitcode} {
	global bfh TNAME
	set tag "$TNAME.cleanup"

	# First remove the test file
	set res [compound {Putfh $bfh; Remove $fname}]
	if { ("$status" != "OK") && ($status != "NOENT") } {
            putmsg stderr 0 "\t WARNING: cleanup to remove ($fname) failed"
            putmsg stderr 0 \
		"\t          status=$status; please cleanup manually."
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    exit $WARNING
	}

	# disconnect and exit
	Disconnect
	exit $exitcode
}

# first setup clientid for the tests and get the server lease_time
set leasetm $LEASE_TIME
putmsg stderr 1 "server lease time is ($leasetm) seconds."

set hid "[pid][clock seconds]99"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "Test UNINITIATED: getclientid failed"
	exit $UNINITIATED
}

set halttime [expr ($leasetm / 2) * 1000]
set 3qltime [expr 3 * $halttime / 2]
set tf "$TNAME.[pid]"
putmsg stderr 1 "\nNow wait 1/2 leasetime=($halttime) to prepare for the test"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $halttime


# Start testing
# --------------------------------------------------------------
# a: Verify successful OPEN op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful OPEN op renew the lease, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set filesize 8193
set open_owner "$TNAME-oowner"
set nfh [basic_open $bfh $tf 1 "$cid $open_owner" osid oseqid status \
	1 0 666 $filesize 3]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
if {$nfh == -1} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: basic_open failed, status=($status)"
	putmsg stderr 0 \
		"\t      Exiting ... rest of the assertions will not be run."
	do_cleanup $tf $UNRESOLVED
}

# OPEN is OK, the lease should have been renewed
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after OPEN"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
set res [compound {Putfh $nfh; Read $osid 0 10; Getattr size}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "OPEN/READ" $status $expcode $res $PASS


# Lease should be renewed by the READ op above.
# b: Verify successful READ op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful READ op renew the lease, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after READ"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
set wdata [string repeat "b" 110]
set off [expr $filesize - 10]
set res [compound {Putfh $nfh; Write $osid $off f a $wdata}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "READ/WRITE" $status $expcode $res $PASS


# Lease should be renewed by the WRITE op above.
# c: Verify successful WRITE op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful WRITE op renew the lease, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after WRITE"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
set newsize [expr $filesize - 100]
set res [compound {Putfh $nfh; Setattr $osid {{size $newsize}}}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "WRITE/SETATTR" $status $expcode $res $PASS


# Lease should be renewed by the SETATTR op above.
# d: Verify successful SETATTR op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful SETATTR op renew the lease, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after SETATTR"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
incr oseqid
set lseqid 10
set lowner "[pid]-$newsize"
set res [compound {Putfh $nfh;
	Lock 2 F 10 100 T $osid $lseqid {$oseqid $cid $lowner}}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
if {[ckres "SETATTR/LOCK" $status $expcode $res $PASS] == "true"} {
	# save the lock_sid 
	set lsid [lindex [lindex $res 1] 2]
} else {
	set lsid {1234 5678}
}


# Lease should be renewed by the LOCK op above.
# e: Verify successful LOCK op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful LOCK op renew the lease, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after LOCK"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
incr lseqid
set res [compound {Putfh $nfh; Locku 2 $lseqid $lsid 0 $newsize}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "SETATTR/LOCK" $status $expcode $res $PASS


# Lease should be renewed by the LOCKU op above.
# f: Verify successful LOCKU op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful LOCKU op renew the lease, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after LOCKU"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
incr oseqid
set res [compound {Putfh $nfh; Open_downgrade $osid $oseqid 2 0}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
if {[ckres "LOCKU/OPEN_DOWNGRADE" $status $expcode $res $PASS] == "true"} {
	set osid2 [lindex [lindex $res 1] 2]
} else {
	set osid2 $osid
}


# Lease should be renewed by the OPEN_DOWNGRADE op above.
# g: Verify successful OPEN_DOWNGRADE op renew the lease, expect OK
set newop "OPEN_DOWNGRADE"
set expcode "OK"
set ASSERTION "Verify successful $newop renew the lease, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after $newop"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
incr oseqid
set res [compound {Putfh $nfh; Close $oseqid $osid2 }]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "OPEN_DOWNGRADE/CLOSE" $status $expcode $res $PASS


# Lease should be renewed by the CLOSE op above.
# i: Verify successful CLOSE op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful CLOSE renew the lease, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after CLOSE"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
putmsg stdout 0 " ** Since file is closed, need to reopen the file to get a new"
putmsg stdout 0 "    valid stateid for the following assertions ..."
set open_owner2 "${open_owner}--2"
set nfh2 [basic_open $bfh $tf 0 "$cid $open_owner2" osid2 oseqid2 status]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
if {$nfh2 == -1} {
	putmsg stderr 0 \
		"\t Test FAIL: open again failed, status=($status)"
	putmsg stderr 0 \
		"\t      Exiting ... rest of the assertions will not be run."
	do_cleanup $tf $FAIL
}
logres "PASS"


# m: Verify successful OPEN op renew the lease, expect OK
set expcode "OK"
set ASSERTION "Verify successful OPEN renew the lease, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should still be valid after OPEN"
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
set res [compound {Putfh $bfh; Lookup $tf; Read {1 1} 0 99}]
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "OPEN/READ{1,1}" $status $expcode $res $PASS


# n: Verify successful READ w/stateid{1 1} does not renew lease, next read
#	would expect EXPIRED|STALE_STATEID
set expcode "EXPIRED|STALE_STATEID"
set ASSERTION "Verify successful READ w/special stateid 1 does not renew lease"
set ASSERTION "$ASSERTION\n\tnext READ w/good osid will fail, expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stderr 1 \
    "  wait for 3/4 of leasetime, lease should have been expired."
putmsg stderr 1 "  start at [clock format [clock seconds]] ..."
after $3qltime
set res [compound {Putfh $nfh2; Read $osid2 1 99}] 
putmsg stderr 1 "  end at [clock format [clock seconds]]"
ckres "READ{1,1}/READ(osid)" $status $expcode $res $PASS 


putmsg stdout 0 " ** Since the lease has expired, we need to reestablish the"
putmsg stdout 0 "    clientid for the next assertion ..."
# r: Verify successful WRITE w/stateid{0 0} does not renew lease, next OPEN 
#	will fail, expect EXPIRED|STALE_CLIENTID
set expcode "EXPIRED|STALE_CLIENTID"
set ASSERTION "Verify successful WRITE w/stateid{0 0} does not renew lease,"
set ASSERTION "$ASSERTION\n\tnext OPEN w/new cid will fail, expect $expcode"
set tag "$TNAME{r}"
putmsg stdout 0 "$tag: $ASSERTION"
set hid2 "[pid][clock seconds]88"
set cid2 [getclientid $hid]
if {$cid2 == -1} {
    putmsg stderr 0 "Test UNRESOLVED: getclientid failed"
} else {
    after $halttime
    set res [compound {Putfh $nfh; Write {0 0} 1 f a $wdata}]
    if {[ckres "WRITE{0,0}" $status "OK" $res $FAIL] == "true"} {
	putmsg stderr 1 \
	    "  wait for 3/4 of leasetime, lease should have been expired."
	after $3qltime
	# an OPEN call should fail now
	set res [compound {Putfh $bfh; 
	    Open 1 3 0 "$cid2 $tag-00111" {0 0 {{mode 0644}}} {0 $tf}; Getfh}]
	ckres "OPEN" $status $expcode $res $PASS 
    }
}


# --------------------------------------------------------------
# Final cleanup
do_cleanup $tf $PASS
