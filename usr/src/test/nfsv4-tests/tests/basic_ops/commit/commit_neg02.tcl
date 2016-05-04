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
# NFSv4 COMMIT operation test - more of negative tests

# include all test enironment
source COMMIT.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# b: Commit but the file is removed, expect STALE
set expcode "STALE"
set ASSERTION "Commit but the file is removed, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to remove <cfh> in server\n"


# m: Commit with <cfh> is bad, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Commit with <cfh> is bad, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook from server to set <cfh> to a bad FH\n"


# n: try to Commit of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Commit an expired FH, expect $expcode"
set tag "$TNAME{n}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server hook for FH expired.\n"


# x: Commit with WrongSec, expect WRONGSEC
# XXX Need more setup with w/Security
set expcode "WRONGSEC"
#set ASSERTION "Commit with wrongSec, expect $expcode"
set tag "$TNAME{x}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putrootfh; Commit $env(KRB5DIR)}]
#ckres "Commit" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need hook to change SEC in <cfh>.\n"

# y: XXX how do we simulate some server errors:
#	NFS4ERR_MOVED
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE
#	NFS4ERR_IO


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
