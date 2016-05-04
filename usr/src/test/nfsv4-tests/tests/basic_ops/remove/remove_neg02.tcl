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
# NFSv4 REMOVE operation test - negative tests

# include all test enironment
source REMOVE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Remove with CFH=file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Try to remove with CFH=file, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Remove "something"}]
ckres "Remove" $status $expcode $res $PASS


# b: Remove with CFH=symlink_dir, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Try to remove with CFH=symlink_dir, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Remove "xxx"}]
ckres "Remove" $status $expcode $res $PASS


# f: Remove an non-empty dir, expect NOTEMPTY
set expcode "NOTEMPTY"
set ASSERTION "Try to remove a non-empty dir, expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putfh $bfh; Remove $env(LARGEDIR); Getfh}]
ckres "Remove" $status $expcode $res $PASS


# i: Remove with FS is READONLY, expect ROFS
set expcode "ROFS"
set ASSERTION "Try to remove FS is READONLY, expect $expcode"
putmsg stdout 0 "$TNAME{i}: $ASSERTION"
set rofh [get_fh [path2comp $env(ROFSDIR) $DELM]]
if {"$rofh" == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: ROFS is not setup in server."
} else {
	set res [compound {Putfh $rofh; ; Remove $env(ROFILE)}]
	ckres "Remove" $status $expcode $res $PASS
}


# j: Remove is not supported in SERVER, expect NOTSUPP
set expcode "NOTSUPP"
set ASSERTION "Remove is not supported in SERVER, expect $expcode"
putmsg stdout 0 "$TNAME{j}: $ASSERTION"
putmsg stdout 0 "\t Test NOTINUSE: Invalid for Solaris server."
putmsg stdout 1 "\t\t Solaris supports REMOVE op."


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
