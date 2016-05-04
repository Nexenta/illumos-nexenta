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
# NFSv4 READDIR operation test - negative tests
#	verify SERVER errors returned with invalid Getattr.

# include all test enironment
source READDIR.env

Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Readdir from a bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Readdir from a bad-FH, expect $expcode"
set tag "$TNAME{a}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putrootfh; Lookup "__badfh"; Readdir type}]
#ckres "Readdir" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need nfsv4shell & server support on BADFH\n"


# h: Readdir with WrongSec, expect WRONGSEC
# XXX Need more set with w/Security
set expcode "WRONGSEC"
set ASSERTION "Readdir with WrongSec, expect $expcode"
set tag "$TNAME{h}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need <cfh> be changed w/SEC in server\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Readdir of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Readdir an expired FH, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook for FH to expire\n"


# o: try to Readdir with delay, expect DELAY
set expcode "DELAY"
set ASSERTION "Readdir with , expect $expcode"
set tag "$TNAME{o}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: need hooks for this?\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
