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
# NFSv4 LINK operation test - negative tests

# include all test enironment
source LINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Link without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to link with no Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Link newl}]
ckres "Link" $status $expcode $res $PASS


# b: Link without SaveFH, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to link with no SaveFH, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Link newl}]
ckres "Link" $status $expcode $res $PASS


# c: try to link w/name exist already, expect EXIST
set expcode "EXIST"
set ASSERTION "Try to link with name existed already, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(TEXTFILE)"; Savefh;
	Putfh $bfh; Link "$env(TEXTFILE)"}]
ckres "Link" $status $expcode $res $PASS


# d: try to link to a dir, expect ISDIR
set expcode "ISDIR"
set ASSERTION "Try to link to a directory, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Getattr type; Savefh;
	Putfh $bfh; Lookup $env(DIR0777); Link newld}]
ckres "Link" $status $expcode $res $PASS


# e: Link with CURRENT_FH is a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Try to link with CURRENT_FH is a file, expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Savefh; Link newle}]
ckres "Link" $status $expcode $res $PASS



# h: Link with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Link with WrongSec, expect $expcode"
#putmsg stdout 0 "$TNAME{h}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hooks to change SEC of FH in server.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to Link of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Link an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server hook for FH expired.\n"


# t: try to link unlink'ble file, expect ACCESS
# {Putrootfh OK} {Lookup OK} {Link ACCES}
set expcode "ACCESS"
set ASSERTION "try to link unlink'ble file, expect $expcode"
#putmsg stdout 0 "$TNAME{t}: $ASSERTION"
#puts "\t Test UNTESTED: XXX what is unlink'ble (/usr/bin/ls??) .\n"


# u: try to link into noperm_dir, expect ACCESS
set expcode "ACCESS"
set ASSERTION "try to link into noperm_dir, expect $expcode"
putmsg stdout 0 "$TNAME{u}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(TEXTFILE)"; Savefh;
	Putfh $bfh; Lookup $env(DNOPERM);  Link newl1u}]
ckres "Link" $status $expcode $res $PASS



# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
