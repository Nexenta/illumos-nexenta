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
# NFSv4 ACCESS operation test - negative tests
#	verify SERVER errors returned with invalid access.

# include all test enironment
source ACCESS.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Access without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Access without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Access rlmtdx}]
ckres "Access" $status $expcode $res $PASS


# b: try to Access while the obj is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Access while obj is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{b}: $ASSERTION"
#set res [compound {Putfh $tfh; Access rlmtdx; Getfh}]
#ckres "Access" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need separate thread to remove <cfh> in SERVER.\n"


# d: Access when CFH is bad, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Access when CFH is bad, expect $expcode"
#putmsg stdout 0 "$TNAME{d}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to set <cfh> bad in SERVER.\n"


# h: Access when CFH has WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Access when CFH has WrongSec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need support to change SEC of <cfh> from SERVER.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to getfh of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Access an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#putmsg stdout 0 "\t Test UNTESTED: XXX need hooks until migration"


# n: Access when CFH is no accessable, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Access when CFH no accessable, expect $expcode"
putmsg stdout 0 "$TNAME{n}: $ASSERTION"
puts "\t Test UNSUPPORTED: Invalid for Solaris.\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
