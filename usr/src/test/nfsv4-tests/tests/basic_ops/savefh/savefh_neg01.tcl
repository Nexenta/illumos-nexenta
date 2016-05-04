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
# NFSv4 SAVEFH operation test - negative tests

# include all test enironment
source SAVEFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Savefh without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Savefh without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Savefh}]
ckres "Savefh" $status $expcode $res $PASS


# e: try to Savefh while file is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Savefh while file is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{e}: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0775}} d; Getfh
#	Putfh $bfh; Remove $tmpd; Savefh; Getfh}]
#set cont [ckres "Savefh" $status $expcode $res $PASS]
#puts "\t Test UNTESTED: XXX need support/hook in server to remove CFH.\n"


# g: Savefh with Bad-Fh, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Savefh with Bad-FH, expect $expcode"
#putmsg stdout 0 "$TNAME{g}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need support/hook in server to trash CFH.\n"


# h: Savefh with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Savefh with wrongsec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to change SEC of <CFH> in server.\n"


# m: try to getfh of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Savefh an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# u: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
