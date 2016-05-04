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
# a: Open(NOCREATE) '.', expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Open (NOCREATE) of '.', expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-a" \
	{0 0 {{mode 0644}}} {0 "."}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# b: Open(CREATE/UNCHECKED) '.', expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Open (CREATE/UNCHECKED) of '.', expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-b" \
	{1 0 {{mode 0644}}} {0 "."}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# c: Open(NOCREATE) '..', expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Open (NOCREATE) of '..', expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-c" \
	{0 0 {{mode 0644}}} {0 ".."}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# d: Open(CREATE/UNCHECKED) '..', expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Open (CREATE/UNCHECKED) of '..', expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-d" \
	{1 0 {{mode 0644}}} {0 ".."}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# g: Open(CREATE) with empty filename, expect INVAL
set expcode "INVAL"
set ASSERTION "Open(CREATE) with empty filename, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-g" \
	{1 0 {{mode 0644}}} {0 ""}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# h: Open(CREATE) with 'name' includes path delimiter, expect INVAL
set expcode "INVAL"
set ASSERTION "Open with 'name' includes path delimiter, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-h" \
	{1 0 {{mode 0644}}} {0 "XX${DELM}xx"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# m: Open(NOCREATE) with invalid access(0), expect INVAL
set expcode "INVAL"
set ASSERTION "Open(NOCREATE) with invalid access(0), expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 0 0 "$cid $owner-m" \
	{0 0 {{mode 0644}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# n: Open(NOCREATE) with invalid access(4), expect INVAL
set expcode "INVAL"
set ASSERTION "Open(NOCREATE) with invalid access(4), expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 4 0 "$cid $owner-n" \
	{0 0 {{mode 0644}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# o: Open(NOCREATE) with invalid deny(4), expect INVAL
set expcode "INVAL"
set ASSERTION "Open(NOCREATE) with invalid deny(4), expect $expcode"
set tag "$TNAME{o}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 4 "$cid $owner-o" \
	{0 0 {{mode 0644}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# p: Open(NOCREATE) with invalid deny(-1), expect INVAL
set expcode "INVAL"
set ASSERTION "Open(NOCREATE) with invalid deny(-1), expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 -1 "$cid $owner-p" \
	{0 0 {{mode 0644}}} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# q: Open(CREATE/GUARDED) w/RO attribute, expect INVAL
set expcode "INVAL"
set ASSERTION "Open(CREATE) w/read-only attribute, expect $expcode"
set tag "$TNAME{q}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid owner-q" \
	{1 1 {{maxname 257}}} {0 "$TNAME-m"};
	Getfh}]
ckres "Open" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
