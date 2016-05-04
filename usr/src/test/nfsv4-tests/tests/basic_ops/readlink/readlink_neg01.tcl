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
# NFSv4 READLINK operation test - negative tests

# include all test enironment
source READLINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Readlink without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to link with no Putrootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Readlink $env(SYMLFILE)}]
ckres "Readlink" $status $expcode $res $PASS


# c: Readlink w/CFH=file, expect INVAL
set expcode "INVAL"
set ASSERTION "Readlink w/CFH=file, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(EXECFILE)";
	Readlink; Getfh}]
ckres "Readlink" $status $expcode $res $PASS


# d: Readlink w/CFH=dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Readlink w/CFH=dir, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DIR0777)";
	Readlink; Getfh}]
ckres "Readlink" $status $expcode $res $PASS


# e: Readlink w/CFH=charfile, expect INVAL
set expcode "INVAL"
set ASSERTION "Readlink w/CFH=charfile, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(CHARFILE)";
	Readlink; Getfh}]
ckres "Readlink" $status $expcode $res $PASS


# f: Readlink w/CFH=attrdir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Readlink w/CFH=attrdir, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(ATTRDIR)"; 
	Openattr f; Getattr type; Readlink}]
ckres "Readlink" $status $expcode $res $PASS


# i: Readlink w/symlink pointed by CFH removed, expect STALE
set expcode "STALE"
set ASSERTION "Readlink w/symlink pointed by CFH removed, expect $expcode"
set tag "$TNAME{i}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set nl3 "NewSymLi.[pid]"
#set res [compound {Putfh $bfh;
#	Create $nl3 {{mode 0666}} l "$env(FIFOFILE)";Getfh}]
#set cont [ckres "Create" $status "OK" $res $FAIL]
#if {! [string equal $cont "false"]} {
#    set sfh [lindex [lindex $res 2] 2]
#    set res [compound {Putfh $bfh; Remove "$nl3"; 
#		Putfh $sfh; Readlink; Getfh}]
#    ckres "Readlink" $status $expcode $res $PASS
#}
#puts "\t Test UNTESTED: XXX need hook to remove <CFH> in server.\n"


# m: Readlink with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Readlink with WrongSec, expect $expcode"
set tag "$TNAME{m}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need SEC changed between <cfh> and Readlink.\n"


# n: try to Readlink of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Readlink an expired FH, expect $expcode"
set tag "$TNAME{n}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need migration support.\n"


# o: try to Readlink of bad FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Readlink with a bad FH, expect $expcode"
set tag "$TNAME{o}"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hooks in server to set CFH bad.\n"


# p: try to Readlink to a system does not support symlink, expect NOTSUPP
set expcode "NOTSUPP"
set ASSERTION "Readlink to a system does not support symlink, expect $expcode"
set tag "$TNAME{p}"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 0 "\t Test NOTINUSE: Invalid assertion for Solaris."
putmsg stdout 1 "\t\t Solaris server supports symlink."


# x: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
#	NFS4ERR_IO
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp link files
#set res [compound {Putfh $bfh; Remove $nl3}]
#if { "$status" != "OK" } {
#        putmsg stderr 0 "\t WARNING: cleanup to remove created links failed"
#        putmsg stderr 0 "\t          status=$status; please cleanup manually."
#	putmsg stderr 1 "\t   res=($res)"
#	putmsg stderr 1 "  "
#	exit $WARNING
#}

# disconnect and exit
Disconnect
exit $PASS
