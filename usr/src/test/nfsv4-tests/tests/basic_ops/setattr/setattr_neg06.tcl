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
# NFSv4 SETATTR operation test - negative tests
#	mostly UNTESTED tests

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# b: try to Setattr while the obj is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Setattr while obj is removed, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0775}} d; Getfh}]
#set tfh [lindex [lindex $res 2] 2]
#check_op "Putfh $bfh; Remove $tmpd" "OK" "UNINITIATED"
#set ntime "[clock seconds] 0"
#set res [compound {Putfh $tfh; 
#	Setattr {0 0} {{time_modify_set {$ntime}}}; Getfh}]
#ckres "Setattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need to remove <cfh> between PUTFH/SETATTR\n"


# g: Setattr from a bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Setattr from a bad-FH, expect $expcode"
set tag "$TNAME{g}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putrootfh; Lookup "__badfh"; Setattr 0 {{mode 000}}}]
#ckres "Setattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need nfsv4shell & server support on BADFH\n"


# h: Setattr with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Setattr with WrongSec, expect $expcode"
set tag "$TNAME{h}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need support on file-change-Sec on-the-fly.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_IO
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Setattr of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Setattr an expired FH, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook for FH to expire\n"


# o: try to Setattr with DELAY response, expect DELAY
set expcode "DELAY"
set ASSERTION "Setattr with DELAY response, expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server support on this?\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
