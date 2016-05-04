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
# NFSv4 OPEN operation test - more of negative tests

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
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
# a: Open(NOCREATE) with 'name' not exist, expect NOENT
set expcode "NOENT"
set ASSERTION "Open(NOCREATE) with 'name' not exist, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-a" \
	{0 0 {{mode 0644}}} {0 "NOENT.[pid]"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# b: Open(NOCREATE) w/'name' not in namespace (Solaris only), expect NOENT
set expcode "NOENT"
set ASSERTION "Open(NOCREATE) w/name(/usr) not in namespace, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putrootfh; Open $seqid 3 0 "$cid $owner-b" \
	{0 0 {{mode 0644}}} {0 "usr"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# c: Open(NOCREATE) w/name exists & is a dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Open(NOCREATE) w/name exists & is a dir, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-c" \
	{0 0 {{mode 0644}}} {0 "$env(DIR0777)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# d: Open(NOCREATE) with CFH is a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Open(NOCREATE) with CFH is a file, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(RWFILE)";
	Open $seqid 3 0 "$cid $owner-d" {0 0 {{mode 0644}}} {0 "XXX"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# e: Open(CREATE) with CFH as a fifo, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Open(CREATE) with CFH as a fifo, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(FIFOFILE)";
	Open $seqid 3 0 "$cid $owner-e" {1 0 {{mode 0644}}} {0 "XXX"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# h: Open(CREATE) with filename too long, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Open(CREATE) with filename too long, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set nli [set_maxname $bfh]
set res [compound {Putfh $bfh;
	Open $seqid 3 0 "$cid $owner-h" {1 0 {{mode 0644}}} {0 "$nli"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# i: Open(CREATE/UNCHECKED) w/name exists and is a dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Open(CREATE/UNCHECKED) w/name exists & is a dir, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-i" \
	{1 0 {{mode 0644}}} {0 "$env(DIR0777)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# j: Open(CREATE/UNCHECK) w/name exists & is a fifo, expect INVAL
set expcode "INVAL"
set ASSERTION "Open(CREATE/UNCHECKED) w/name exists & is fifo, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-j" \
	{1 0 {{mode 0644}}} {0 "$env(FIFOFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# k: Open(CREATE/GUARDED) w/name exists & is a file, expect EXIST
set expcode "EXIST"
set ASSERTION "Open(CREATE/GUARDED) w/name exists & is a file, expect $expcode"
set tag "$TNAME{k}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-k" \
	{1 1 {{mode 0644}}} {0 "$env(RWFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS



# l: Open(CREATE/EXCLUSIVE) w/name exists & is a file, expect EXIST
set expcode "EXIST"
set ASSERTION "Open(CREATE/EXCLUSIVE) w/name exists & is file, expect $expcode"
set tag "$TNAME{l}"
putmsg stdout 0 "$tag: $ASSERTION"
set createverf "0011[pid]"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-l" \
	{1 2 $createverf} {0 "$env(ROFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# s: Open(NOCREATE) with name is a symlink, expect SYMLINK
set expcode "SYMLINK"
set ASSERTION "Open(NOCREATE) w/name is a symlink, expect $expcode"
set tag "$TNAME{s}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $seqid 3 0 "$cid $owner-s" \
	{0 0 {{mode 0644}}} {0 "$env(SYMLFILE)"}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
