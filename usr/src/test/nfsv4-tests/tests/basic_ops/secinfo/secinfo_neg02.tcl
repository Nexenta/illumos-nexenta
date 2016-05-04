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
# NFSv4 SECINFO operation test - more of negative tests

# include all test enironment
source SECINFO.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Secinfo with 'name' not exist, expect NOENT
set expcode "NOENT"
set ASSERTION "Secinfo with the 'name' not exist, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Secinfo "NOENT.[pid]"}]
ckres "Secinfo" $status $expcode $res $PASS


# b: Secinfo with 'name' not in namespace, expect NOENT
set expcode "NOENT"
set ASSERTION "Secinfo with the 'name' not in namespace, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putrootfh; Secinfo "usr"}]
ckres "Secinfo" $status $expcode $res $PASS


# d: Secinfo with CFH is a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Secinfo with CFH is a file, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(RWFILE)";
	Secinfo XXX; Getfh}]
ckres "Secinfo" $status $expcode $res $PASS


# e: Secinfo with CFH as a fifo, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Secinfo with CFH as a fifo, expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(FIFOFILE)";
	Secinfo notdir; Getfh}]
ckres "Secinfo" $status $expcode $res $PASS


# h: Secinfo with component name too long, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Secinfo with component name too long, expect $expcode"
putmsg stdout 0 "$TNAME{h}: $ASSERTION"
set nli [set_maxname $bfh]
set res [compound {Putfh $bfh; Secinfo $nli}]
ckres "Rename" $status $expcode $res $PASS


# m: try to Secinfo of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Secinfo an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to get FH expired.\n"


# x: Secinfo with WrongSec, expect WRONGSEC
# XXX Need more setup with w/Security
set expcode "WRONGSEC"
#set ASSERTION "Secinfo with wrongSec, expect $expcode"
#puts "\t Test UNTESTED: XXX should SECINFO generates WRONGSEC?\n"


# y: XXX need a way to simulate these server errors:
#	NFS4ERR_MOVED
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
