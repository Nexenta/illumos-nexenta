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
# NFSv4 OPEN operation test - negative tests
#	Verify server returns correct errors with negative requests.
#	(NOTE: currently all tests are UNTESTED due to not test'ble
#		under current environments.)

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set seqid 1
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: try to Open while dir is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Open while dir is removed, expect $expcode"
set tag "$TNAME{a}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need different thread to remove <cfh> in server.\n"


# m: try to Open of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Open an expired FH, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# s: Open with a Bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Open with a Bad-FH, expect $expcode"
set tag "$TNAME{s}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __bad_fh; 
#	Open $seqid 3 0 "$cid $owner-s" {0 0 {{mode 0644}}} {0 $env(ROFILE)}}]
#ckres "Open" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX Need server hook to set Bad-FH for this test.\n"


# x: Open with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
#set ASSERTION "Open with wrongSec, expect $expcode"
#puts "\t Test UNTESTED: Need file with different favor to get WRONGSEC?\n"


# y: XXX need a way to simulate these server errors:
#	NFS4ERR_MOVED
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
