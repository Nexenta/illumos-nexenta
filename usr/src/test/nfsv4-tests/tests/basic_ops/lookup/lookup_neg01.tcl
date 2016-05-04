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
# NFSv4 LOOKUP operation test - negative tests

# include all test enironment
source LOOKUP.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Lookup without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Lookup without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Lookup $env(TEXTFILE)}]
ckres "Lookup" $status $expcode $res $PASS


# b: Lookup an obj under dir_noperm, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Lookup an obj under dir_noperm, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM); 
	Lookup $env(RWFILE); Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# c: Lookup an obj under symlink dir, expect SYMLINK
set expcode "SYMLINK"
set ASSERTION "Lookup an obj under symlink dir, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(SYMLDIR)"; 
	Lookup rwfile; Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# d: Lookup '.', expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Lookup '.', expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "."; Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# e: Lookup '..', expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Lookup '..', expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DIR0777)";
	Lookup ".."; Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# g: Lookup with path delimiter in name, expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Lookup with path delimiter in name, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "XX${DELM}xx"; Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# h: Lookup with zero length component, expect INVAL
set expcode "INVAL"
set ASSERTION "Lookup with zero length component, expect $expcode"
putmsg stdout 0 "$TNAME{h}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup ""; Getfh}]
ckres "Lookup" $status $expcode $res $PASS


# m: try to Lookup while dir is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Lookup while dir is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; 
#	Getfh; Create "Nfifo" {{mode 0666}} f}]
#set tfh [lindex [lindex $res 2] 2]
#check_op "Putfh $tfh; Remove Nfifo; Lookupp; Remove $tmpd" "OK" "UNINITIATED"
#set res [compound {Putfh $tfh; Lookup "Nfifo"; Getfh}]
#ckres "Lookup" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need a better way to remove files (in server?)\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
