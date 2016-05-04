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
# NFSv4 LOOKUPP operation test - negative tests

# include all test enironment
source LOOKUPP.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0

# local proc trying to send the bad request and to check error returned
proc ckerrs { tn dir exp mesg rc } {
    global TNAME
    global DEBUG
    putmsg stdout 0 "$TNAME{$tn}: Lookupp $mesg, expect $exp"
    set res [compound {Putrootfh; foreach c $dir {Lookup $c}; Lookupp}]
    ckres "Lookupp" $status $exp $res $rc
}

# Start testing
# --------------------------------------------------------------
# a: lookupp from a file-fh - expect NOTDIR
set tfile $env(TEXTFILE)
ckerrs "a" "$BASEDIRS $tfile" "NOTDIR" "from a file-fh" $PASS


# b: lookupp from a symlink-fh - expect NOTDIR
set symd $env(SYMLDIR)
ckerrs "b" "$BASEDIRS $symd" "NOTDIR" "from symlink-dir" $PASS


# c: lookupp from an none-reg-fh - expect NOTDIR
ckerrs "c" "$BASEDIRS $env(ZIPFILE)" "NOTDIR" "from none-reg-fh" $PASS


# d: lookupp from a noperm dir-fh - expect NOTDIR
set dnoperm $env(DNOPERM)
ckerrs "d" "$BASEDIRS $dnoperm" "ACCESS" "from noperm dir-fh" $PASS


# f: lookupp at top of root-tree, expect NOENT
set expcode NOENT
set ASSERTION "Lookupp at the top of root-tree, expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set res [compound {Putrootfh; Lookupp}]
ckres "Lookupp" $status $expcode $res $PASS


# g: lookupp without putrootfh, expect NOFILEHANDLE
set expcode NOFILEHANDLE
set ASSERTION "Lookupp without putrootfh, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set res [compound {Lookupp}]
ckres "Lookupp" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
