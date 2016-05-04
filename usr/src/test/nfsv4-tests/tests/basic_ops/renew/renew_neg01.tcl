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
# NFSv4 RENEW operation test - negative tests

# include all test enironment
source RENEW.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag "$TNAME.setup"
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Renew without correct clientid, expect STALE_CLIENTID
set expcode "STALE_CLIENTID"
set ASSERTION "Renew without correct clientid, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Renew "junk.id"}]
ckres "Renew" $status $expcode $res $PASS


# Get server lease time for the following assertions
set leasetm $LEASE_TIME

set overlease [expr ($leasetm + 8) * 1000]


# b: Renew with an old clientid, expect EXPIRED
set expcode "EXPIRED"
set ASSERTION "Renew with an old clientid, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$TNAME.[clock seconds]-b"
set clientid1 [getclientid $owner]
if {$clientid1 == -1} {
    putmsg stderr 0 "\t Test UNRESOLVED: getclientid failed"
} else {
    putmsg stdout 1 "leasetm=$leasetm, clientid1=$clientid1"
    # wait for lease to expire and verify it w/Open
    after $overlease
    set OPENexp "EXPIRED"
    set res [compound {Putfh $bfh; 
	Open 1 3 0 {$clientid1 $owner} \
       		{0 0 {{mode 0666}}} {0 $env(ROFILE)}}]
    if {[ckres "Open" $status $OPENexp $res $FAIL] == "true"} {
	# Get a new clientid
	set owner2 "$owner-2"
	set clientid2 [getclientid $owner2]
	if {$clientid2 == -1} {
	    putmsg stderr 0 "\t Test UNRESOLVED: getclientid2 failed"
	} else {
	    putmsg stdout 1 "clientid2=$clientid2"
	    after 5000
	    # But use clientid1 in Renew, should fail 
	    set res [compound {Renew $clientid1}]
            ckres "Renew" $status $expcode $res $PASS
        }
    }
}
    

# c: Renew fails when lease expired, expect EXPIRED
set expcode "EXPIRED"
set ASSERTION "Renew fails when expired, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$TNAME.[clock seconds]-c"
set clientid1 [getclientid $owner]
if {$clientid1 == -1} {
    putmsg stderr 0 "\t Test UNRESOLVED: getclientid failed"
} else {
    putmsg stdout 1 "leasetm=$leasetm, clientid1=$clientid1"
    # wait for lease to expire and verify it w/Open
    after $overlease
    set nfh [basic_open $bfh $env(ROFILE) 0 "$clientid1 $owner" \
	osid oseqid status 1 1]
    if {($status != "EXPIRED") && ($status != "$expcode")} {
	putmsg stderr 0 "Test UNRESOLVED: Open got status=($status)"
	putmsg stderr 0 "                 expected status=(EXPIRED|$expcode)"
    } else {
        set res [compound {Renew $clientid1}]
        ckres "Renew" $status $expcode $res $PASS
    }
}


# --------------------------------------------------------------
# disconnect and exit
set tag "$TNAME.cleanup"
Disconnect
exit $PASS
