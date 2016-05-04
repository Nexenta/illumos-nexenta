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
# NFSv4 SECINFO operation test - negative tests
#	Verify server returns correct errors with negative requests.

# include all test enironment
source SECINFO.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Secinfo without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Secinfo without Putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Secinfo $env(DIR0777)}]
ckres "Secinfo" $status $expcode $res $PASS


# b: Secinfo an obj under dir_noperm, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Secinfo an obj under dir_noperm, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
compound {Putfh $bfh; Lookup $env(DNOPERM); Secinfo $env(RWFILE)}
ckres "Secinfo" $status $expcode $res $PASS


# c: Secinfo with a Bad-FH, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Secinfo with a Bad-FH, expect $expcode"
#putmsg stdout 0 "$TNAME{c}: $ASSERTION"
#set res [compound {Secinfo $env(DIR0777)}]
#ckres "Secinfo" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX Need server hook to set Bad-FH for this test.\n"


# d: Secinfo '.', expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Secinfo '.', expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Secinfo "."; Getfh}]
ckres "Secinfo" $status $expcode $res $PASS


# f: Secinfo with zero length component, expect INVAL
set expcode "INVAL"
set ASSERTION "Secinfo with zero length component, expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putfh $bfh; Secinfo ""; Getfh}]
ckres "Secinfo" $status $expcode $res $PASS


# g: Secinfo w/name includes path delimiter, expect INVAL|NOENT
set expcode "INVAL|NOENT"
set ASSERTION "Secinfo w/name include path delimiter, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set res [compound {Putfh $bfh; Secinfo "XX${DELM}xx"}]
ckres "Secinfo" $status $expcode $res $PASS


# m: try to Secinfo while dir is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Secinfo while dir is removed, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX Need different thread to remove <cfh> in server.\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
