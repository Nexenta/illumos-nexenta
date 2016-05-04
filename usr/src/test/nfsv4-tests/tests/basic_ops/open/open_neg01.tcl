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
# NFSv4 OPEN operation test - negative tests
#	Verify server returns correct errors with negative requests.

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set seqid 1
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open(NOCREATE) access=R, a file w/mode=000, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Open(NOCREATE) access=R, a file w/mode=000, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 1 0 "$cid $owner-a" \
	{0 0 {{mode 0644}}} {0 $env(FNOPERM)}}]
ckres "Open" $status $expcode $res $PASS


# b: Open(NOCREATE) access=W, a file w/mode=444, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Open(NOCREATE) access=W, a file w/mode=444, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 2 0 "$cid $owner-b" \
	{0 0 {{mode 0644}}} {0 $env(ROFILE)}}]
ckres "Open" $status $expcode $res $PASS


# c: Open(NOCREATE) a file under dir_noperm, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Open(NOCREATE) a file under dir_noperm, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM); 
	Open $seqid 3 0 "$cid $owner-c" {0 0 {{mode 0644}}} {0 $env(ROFILE)}}]
ckres "Open" $status $expcode $res $PASS


# d: Open(CREATE/UNCHECKED) in a dir w/o WRITE permission, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Open(CREATE/UNCHECKED) in a dir w/o WRITE perm, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0755); 
	Open $seqid 3 0 "$cid owner-d" {1 0 {{mode 0644}}} {0 "$TNAME-d"};
	Getfh}]
ckres "Open" $status $expcode $res $PASS


# e: Open(CREATE/UNCHECKED) access=RW, w/file exist & RO, expect ACCESS
set expcode "ACCESS"
set ASSERTION \
  "Open(CREATE/UNCHECKED) access=RW, w/file exist & RO, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-e" \
	{1 0 {{mode 0644}}} {0 "$env(ROEMPTY)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# m: Open(CREATE/UNCHECKED) size=1,access=R, w/file exist & RO, expect ACCESS
set expcode "ACCESS"
set ASSERTION \
  "Open(CREATE/UNCHECKED) sz=0,access=R, w/file is RO, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 1 0 "$cid $owner-m" \
	{1 0 {{size 0}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
