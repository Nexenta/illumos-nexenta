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
set size 999
set open_owner $TFILE
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" \
	osid oseqid status $seqid 0 666 $size]
if {$nfh == -1} {
	putmsg stdout 0 "$TNAME: test setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to create tmp file=($TFILE)"
	putmsg stderr 0 "\t\t basic_open failed, status=($status)."
	exit $UNRESOLVED
}
set oseqid [expr $oseqid + 1]


# Start testing
# --------------------------------------------------------------
# a: try Lock(R) while file is removed, expect STALE
set expcode "STALE"
set ASSERTION "try Lock(R) while file is removed, expect $expcode"
set tag "$TNAME{a}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need different thread to remove <cfh> in server.\n"

# b: try Lockt(W) while file is removed, expect STALE
set expcode "STALE"
set ASSERTION "try Lockt(W) while file is removed, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need different thread to remove <cfh> in server.\n"

# c: try Locku() while file is removed, expect STALE
set expcode "STALE"
set ASSERTION "try Locku() while file is removed, expect $expcode"
set tag "$TNAME{c}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need different thread to remove <cfh> in server.\n"


# f: try to Lock on an expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Lock an expired FH, expect $expcode"
set tag "$TNAME{f}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"

# g: try to Lockt on an expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Lockt an expired FH, expect $expcode"
set tag "$TNAME{g}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"

# h: try to Locku on an expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Locku an expired FH, expect $expcode"
set tag "$TNAME{h}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# l: Lock with a Bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Lock with a Bad-FH, expect $expcode"
set tag "$TNAME{l}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need server hook to set Bad-FH for this test.\n"

# m: Lockt with a Bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Lockt with a Bad-FH, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need server hook to set Bad-FH for this test.\n"

# n: Locku with a Bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Locku with a Bad-FH, expect $expcode"
set tag "$TNAME{n}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need server hook to set Bad-FH for this test.\n"


# r: Lock with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Lock with <cfh> is changed SEC, expect $expcode"
set tag "$TNAME{r}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need diff thread in server to reset SEC on cfh\n"

# s: Lockt with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Lockt with <cfh> is changed SEC, expect $expcode"
set tag "$TNAME{s}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need diff thread in server to reset SEC on cfh\n"

# t: Locku with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Lockt with <cfh> is changed SEC, expect $expcode"
set tag "$TNAME{t}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need diff thread in server to reset SEC on cfh\n"


# y: XXX need a way to simulate these server errors:
#	NFS4ERR_MOVED
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE
  
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
