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
# a: Remove without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to do remove with no Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Remove $env(DIR0777)}]
ckres "Remove" $status $expcode $res $PASS


# b: Try to Remove an entry under dir_noperm, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Remove an entry under dir_noperm, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DNOPERM)"; Remove rwfile}]
ckres "Remove" $status $expcode $res $PASS


# c: Try to Remove an entry with empty name, expect INVAL
set expcode "INVAL"
set ASSERTION "Remove an entry w/empty name, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Remove ""; Getfh}]
ckres "Remove" $status $expcode $res $PASS


# d: Try to Remove an entry with target=".", expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Remove an entry w/target=\".\", expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Remove "."; Getfh}]
ckres "Remove" $status $expcode $res $PASS


# e: Try to Remove an entry with target="..", expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Remove an entry w/target=\"..\", expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Remove ".."; Getfh}]
ckres "Remove" $status $expcode $res $PASS


# f: Try to Remove w/target name includes path delimiter, expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Remove an entry w/target=\"xx${DELM}xx\", expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putfh $bfh; Remove "dir${DELM}file"; Getfh}]
ckres "Remove" $status $expcode $res $PASS


# i: Try to Remove an none-existing entry, expect NOENT
set expcode "NOENT"
set ASSERTION "Remove an none-existing entry, expect $expcode"
putmsg stdout 0 "$TNAME{i}: $ASSERTION"
set res [compound {Putfh $bfh; Remove "No-such.thing"; Getfh}]
ckres "Remove" $status $expcode $res $PASS


# j: Try to Remove an entry with too long name, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Remove an entry w/target name too long, expect $expcode"
putmsg stdout 0 "$TNAME{j}: $ASSERTION"
set tname [set_maxname $bfh]
if {$tname != $NULL} {
    set res [compound {Putfh $bfh; Remove $tname; Getfh}]
    ckres "Remove" $status $expcode $res $PASS
} else {
    putmsg stderr 0 "\t UNINITIATED: unable to set maxname"
    putmsg stderr 1 "\t   tname=($tname)"
    putmsg stderr 1 "  "
}


# k: Remove when CFH removed, expect STALE
set expcode "STALE"
set ASSERTION "Remove when CFH removed, expect $expcode"
#putmsg stdout 0 "$TNAME{k}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to remove <CFH> from server.\n"


# m: Remove with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Remove with WrongSec, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server change SEC w/KRB5.\n"


# n: try to Remove of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Remove an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{n}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# o: try to Remove of bad FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Remove with a bad FH, expect $expcode"
#putmsg stdout 0 "$TNAME{o}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hooks in server to set CFH bad.\n"


# x: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
#	NFS4ERR_IO
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
