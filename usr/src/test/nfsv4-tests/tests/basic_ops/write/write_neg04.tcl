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
# NFSv4 WRITE operation test - more negative tests
#	verify SERVER errors returned with invalid write.

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Write a file where <cfh> is bad - expect BADHANDLE
#
set expcode "BADHANDLE"
set ASSERTION "Write a file w/<cfh> bad, expect $expcode"
set tag "$TNAME{a}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need hook to trash <cfh> from server.\n"


# b: Write a file to update lease but <cfh> moved - expect LEASE_MOVED
#
set expcode "LEASE_MOVED"
set ASSERTION "Write a file to update lease but <cfh> moved, expect $expcode"
set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need migration support.\n"


# c: the FS if <cfh> is moved to a new server - expect MOVED
#
set expcode "MOVED"
set ASSERTION "Write a file but the FS of <cfh> moved, expect $expcode"
set tag "$TNAME{c}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need migration support.\n"


# d: Write a file w/<cfh> is volatile and expired - expect FHEXPIRED
#
set expcode "FHEXPIRED"
set ASSERTION "Write a file w/<cfh> is volatile and expired, expect $expcode"
set tag "$TNAME{d}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need migration support.\n"


# e: Write w/special stateid, server unable to obtain lock - expect DENIED
#
set expcode "DENIED"
set ASSERTION "Write w/special stateid, server unable to obtain lock, expect $expcode"
set tag "$TNAME{e}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need migration support.\n"


# f: Write when server delay to response - expect DELAY
#
set expcode "DELAY"
set ASSERTION "Write when server delay to response, expect $expcode"
set tag "$TNAME{f}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t TEST UNTESTED: XXX need hook on this.\n"


# XXX the following errors are different to simulate
# 
#I    NFS4ERR_IO
#I    NFS4ERR_RESOURCE
#I    NFS4ERR_SERVERFAULT
#I    NFS4ERR_WRONGSEC
#?    NFS4ERR_NXIO (not in WRITE)


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
