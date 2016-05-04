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
# NFSv4 GETFH operation test - negative tests

# include all test enironment
source GETFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Getfh without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Getfh without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Getfh}]
ckres "Getfh" $status $expcode $res $PASS


# b: try to Getfh while file is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Getfh while file is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{b}: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; Getfh}]
#set tfh [lindex [lindex $res 3] 2]
#check_op "Putrootfh; Lookup \"$BASEDIRS\"; Remove $tmpd" "OK" "UNINITIATED"
#set res [compound {Putfh $tfh; Create $tobj f; Getfh}]
#ckres "Getfh" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need a better way to remove files (in server?)\n"


# h: getfh with WrongSec, expect WRONGSEC
# Need more set with w/Security
set expcode "WRONGSEC"
set ASSERTION "Getfh with wrongsec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hooks to change SEC of <cfh> in server.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to getfh of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Getfh an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need migration support.\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
