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
# NFSv4 GETATTR operation test - negative tests
#	verify SERVER errors returned with invalid Getattr.

# include all test enironment
source GETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Getattr without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Getattr without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Getattr type}]
ckres "Getattr" $status $expcode $res $PASS


# b: try to Getattr while the obj is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Getattr while obj is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{b}: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; Getfh}]
#set tfh [lindex [lindex $res 2] 2]
#check_op "Putfh $bfh; Remove $tmpd" "OK" "UNINITIATED"
#set res [compound {Putfh $tfh; Getattr cansettime; Getfh}]
#ckres "Getattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need support/hooks to remove <cfh> on SERVER\n"


# c: Getattr when no access permission to file, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Getattr when no access permission to file, expect $expcode"
#putmsg stdout 0 "$TNAME{c}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hooks in server to change obj after Putfh\n"


# d: Getattr from a bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Getattr from a bad-FH, expect $expcode"
#putmsg stdout 0 "$TNAME{d}: $ASSERTION"
#set res [compound {Putrootfh; Lookup "__badfh"; Getattr type}]
#ckres "Getattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need nfsv4shell & server support on BADFH\n"


# h: Getattr with WrongSec, expect WRONGSEC
# XXX Need more set with w/Security
set expcode "WRONGSEC"
set ASSERTION "Getattr with WrongSec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need more on Sec support\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Getattr of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Getattr an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook for FH to expire\n"


# n: try to Getattr with invalid bit set, expect INVAL
# XXX need nfsv4shell to set invalid bits?
set expcode "INVAL"
set ASSERTION "Getattr with invalid bits set, expect $expcode"
#putmsg stdout 0 "$TNAME{n}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need nfsv4shell to set invalid bits?\n"


# o: try to Getattr with <cfh> delay'ed, expect DELAY
set expcode "DELAY"
set ASSERTION "Getattr with , expect $expcode"
#putmsg stdout 0 "$TNAME{o}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server support on this?\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
