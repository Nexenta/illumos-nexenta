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
# NFSv4 OPEN operation test - more of negative tests
# 	Test EXPIRED error

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
# Get server lease time
set leasetm $LEASE_TIME

# now set/confirm the clientid
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set oseqid 1
set oowner $TNAME-oowner

# and wait for the least to expire
after [expr ($leasetm + 12) * 1000]

# Start testing
# --------------------------------------------------------------
# a: Open(non-CREATE) with lease time expired, expect EXPIRED|STALE_CLIENTID
set expcode "EXPIRED|STALE_CLIENTID"
set ASSERTION "Open(non-CREATE) w/lease time expired, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $oseqid 1 0 "$cid $oowner-a" \
		    {0 0 {{mode 0666}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# b: Open(CREATE) with lease time expired, expect EXPIRED|STALE_CLIENTID
set expcode "EXPIRED|STALE_CLIENTID"
set ASSERTION "Open(CREATE) w/lease time expired, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set tf "$TNAME-b.[pid]"
set res [compound {Putfh $bfh; Open $oseqid 3 0 "$cid $oowner-b" \
		    {1 0 {{mode 0666}}} {0 "$tf"}; Getfh}]
if { [ckres "Open" $status $expcode $res $FAIL] == "true" } {
  # check the test file is not created
  set res [compound {Putfh $bfh; Lookup $tf}]
  ckres "Open" $status NOENT $res $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
