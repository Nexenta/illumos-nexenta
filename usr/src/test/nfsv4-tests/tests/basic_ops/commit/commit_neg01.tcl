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
# NFSv4 COMMIT operation test - negative tests

# include all test enironment
source COMMIT.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Commit without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Commit without <cfh>, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Commit 0 0}]
ckres "Commit" $status $expcode $res $PASS


# b: Commit with <cfh> is a readonly file, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Commit <cfh> is a readonly file, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); 
	Commit 0 10; Getfh}]
ckres "Commit" $status $expcode $res $PASS


# c: Commit with <cfh> is a symlink, expect INVAL
set expcode "INVAL"
set ASSERTION "Commit with <cfh> is a symlink, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(SYMLDIR)"; 
	Commit 1 2; Getfh}]
ckres "Commit" $status $expcode $res $PASS


# d: Commit with <cfh> is a fifofile, expect INVAL
set expcode "INVAL"
set ASSERTION "Commit with <cfh> is a fifofile, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(FIFOFILE)"; 
	Commit 2 3; Getfh}]
ckres "Commit" $status $expcode $res $PASS


# e: Commit with <cfh> is a dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Commit with <cfh> is a directory, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DIR0711)"; 
	Commit 1 2; Getfh}]
ckres "Commit" $status $expcode $res $PASS


# f: Commit with <cfh> is in ROFS, expect ROFS
set expcode "ROFS"
set ASSERTION "Commit with <cfh> is in ROFS, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh "[path2comp $env(ROFSDIR) $DELM] $env(RWFILE)"]
set res [compound {Putfh $tfh; Commit 10 2; Getfh}]
ckres "Commit" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
