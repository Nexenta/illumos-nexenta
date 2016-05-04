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

# include all test enironment
source RENEW.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag "$TNAME.setup"
set bfh [get_fh "$BASEDIRS"]

# first setup clientid for the tests and get the server lease_time
set owner "$TNAME.[pid]"
set clientid [getclientid $owner]
if {$clientid == -1} {
	putmsg stdout 0 "$TNAME: test setup"
	putmsg stderr 0 "Test UNRESOLVED: getclientid failed"
	exit $UNRESOLVED
}

set leasetm $LEASE_TIME

set tf "$env(RWFILE)"


# Start testing
# --------------------------------------------------------------
# a: Renew with a good clientid, expect OK
set expcode "OK"
set ASSERTION "Renew with a good clientid, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Renew $clientid; Putfh $bfh; Lookup $tf; Getfh}]
set cont [ckres "Renew" $status $expcode $res $FAIL]
if {![string equal $cont "false"]} {
    # verify client is now able to do Open before lease_time
    set nlt [expr $leasetm - 10]
    if {$nlt < 0} {
	set nlt 1
    }
    exec sleep $nlt
    set nfh [basic_open $bfh $tf 0 "$clientid $owner" osid oseqid status 1 1]
    # open should return a good filehandle
    if {($nfh < 0) && ($status != "OK")} {
	putmsg stderr 0 "\tTest FAIL: basic_open failed, got status=($status)"
	putmsg stderr 0 "\t           expected status=(OK), nfh=($nfh)"
    } else {
	set fh2 [lindex [lindex $res 3] 2]
	fh_equal $nfh $fh2 $cont $PASS
    }
}


# b: Renew before lease expired then Open, expect OK
set expcode "OK"
set ASSERTION "Renew before lease expired then Open, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Renew $clientid}]
if {[ckres "Renew" $status $expcode $res $FAIL] == "true"} {
    # wait before lease expired, then RENEW
    exec sleep [expr $leasetm - 1]
    set res [compound {Renew $clientid; Putfh $bfh; Lookup $tf; Getfh}]
    if {[ckres "Renew" $status $expcode $res $FAIL] == "true"} {
	# make sure to pass the original lease time
        exec sleep 5
	set nfh \
	[basic_open $bfh $tf 0 "$clientid $owner-b" osid oseqid status 2 1]
	if {($nfh < 0) && ($status != "OK")} {
	    putmsg stderr 0 \
		"\tTest FAIL: basic_open failed, got status=($status)"
	    putmsg stderr 0 "\t           expected status=(OK), nfh=($nfh)"
	} else {
	    set fh2 [lindex [lindex $res 3] 2]
	    fh_equal $nfh $fh2 $cont $PASS
	}
    }
}


# --------------------------------------------------------------
# disconnect and exit
set tag "$TNAME.cleanup"
Disconnect
exit $PASS
