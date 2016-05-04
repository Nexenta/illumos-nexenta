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
# NFSv4 OPENATTR operation test - negative tests
#	verify SERVER errors returned under error conditions

# include all test enironment
source OPENATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Try to openattr with bad <cfh> - expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "openattr with bad <cfh>, expect $expcode"
set tag "$TNAME{a}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __badfh; Openattr T}]
#ckres "Openattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: need different thread to trash <cfh> in server."


# b: Openattr when the <cfh> expired - expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Openattr when the <cfh> expired, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __fhexp; Openattr T}]
#ckres "Openattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: need migration support in server."


# c: Openattr when the <cfh> moved - expect MOVED
set expcode "MOVED"
set ASSERTION "Openattr when the <cfh> moved, expect $expcode"
set tag "$TNAME{c}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __moved; Openattr T}]
#ckres "Openattr" $status $expcode $res $PASS
puts "\t Test UNTESTED: need migration support in server."


# d: Openattr when the <cfh> removed - expect STALE
set expcode "STALE"
set ASSERTION "Openattr when the <cfh> is revmoed, expect $expcode"
set tag "$TNAME{d}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __stale; Openattr T}]
#ckres "Openattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: need different thread to remove <cfh> in server."


# e: Openattr when the <cfh> changed SEC - expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Openattr when the <cfh> is changed SEC, expect $expcode"
set tag "$TNAME{e}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup __wsec; Openattr T}]
#ckres "Openattr" $status $expcode $res $PASS
#puts "\t Test UNTESTED: need different thread to change sec to <cfh> in server"


# m: Openattr when the server errors - expect XXX
# XXX current there is no way to simulate the following errors:
#	NFS4ERR_IO
#	NFS4ERR_RESOURCE
#	NFS4ERR_SERVERFAULT


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
