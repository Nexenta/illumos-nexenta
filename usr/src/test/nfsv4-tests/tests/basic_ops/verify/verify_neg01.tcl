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
# NFSv4 VERIFY operation test - negative tests
#	verify SERVER errors returned with invalid Verify.

# include all test enironment
source VERIFY.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Verify without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Verify without Putrootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Verify {{type reg}}}]
ckres "Verify" $status $expcode $res $PASS


# b: try to Verify while the obj is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Verify while obj is removed, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0755}} d; Getfh}]
#set tfh [lindex [lindex $res 2] 2]
#check_op "Putfh $bfh; Remove $tmpd" "OK" "UNINITIATED"
#set res [compound {Putfh $tfh; Verify {{cansettime true}}; Getfh}]
#ckres "Verify" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need to remove <cfh> between PUTFH/VERIFY\n"


# c: Verify an attribute is not supported, expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Verify an attribute is not supported, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set nsattr "hidden"
# check this attr is not in supported_attrs list
set res [compound {Putfh $bfh; Getattr supported_attrs}]
if {[lsearch -exact [lindex [lindex [lindex $res 1] 2] 1] $nsattr] >= 0} {
    putmsg stdout 0 "\t Test NOTINUSE: attr($nsattr) is in supported_attrs list"
} else {
    set res [compound {Putfh $bfh; Verify {{$nsattr "true"}}; Getfh}]
    ckres "Verify" $status $expcode $res $PASS
}


# d: Verify from a bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Verify from a bad-FH, expect $expcode"
set tag "$TNAME{d}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putrootfh; Lookup "__badfh"; Verify {{mode 000}}}]
#ckres "Verify" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need nfsv4shell & server support on BADFH\n"


# g: Verify without permission, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Verify without permission, expect $expcode"
set tag "$TNAME{g}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need <cfh> permission changed in server\n"


# h: Verify with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Verify with WrongSec, expect $expcode"
set tag "$TNAME{h}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to change Sec of <CFH> from SERVER\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Verify of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Verify an expired FH, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook for FH to expire\n"


# n: try to Verify with DELAY, expect with DELAY
set expcode "DELAY"
set ASSERTION "Verify with DELAY, expect $expcode"
set tag "$TNAME{n}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server hooks on the delay??\n"


# o: Verify with rdattr_error, expect INVAL
set expcode "INVAL"
set ASSERTION "Verify with rdattr_error, expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Verify {{rdattr_error "OK"}}}]
ckres "Verify" $status $expcode $res $PASS

# p: Verify with time_access_set to time value, expect INVAL
set expcode "INVAL"
set ASSERTION "Verify w/time_access_set to time value, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set nta "[clock seconds] 0"
set res [compound {Putfh $bfh; Verify {{time_access_set {$nta}}}}]
ckres "Verify" $status $expcode $res $PASS

# q: Verify with time_modify_set to server time, expect INVAL
set expcode "INVAL"
set ASSERTION "Verify w/time_access_set to server time, expect $expcode"
set tag "$TNAME{q}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Verify {{time_modify_set 0}}}]
ckres "Verify" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
