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
# NFSv4 GETATTR operation test - negative tests
#	verify SERVER errors returned with invalid Getattr.

# include all test enironment
source GETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set tmpS "$TNAME.[pid]"

# list of testing objects
set FO "$env(RWFILE) $env(DIR0777) $env(SYMLFILE) $env(CHARFILE) $env(FIFOFILE)"

# Start testing
# --------------------------------------------------------------
# a: Getattr{time_access_set WO-attr}, expect INVAL
set expcode "INVAL"
set i 1
set tattr "time_access_set"
foreach testobj $FO {
    set tag "$TNAME{a$i}"
    set ASSERTION \
	"Getattr{$tattr WO-attr} of <$testobj>, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    putmsg stdout 1 "Putfh $bfh; Lookup $testobj; Getattr $tattr"
    set res [compound {Putfh $bfh; Lookup $testobj; Getattr $tattr}]
    ckres "Getattr" $status $expcode $res $PASS
}

# b: Getattr{time_modify_set WO-attr}, expect INVAL
set expcode "INVAL"
set i 1
set tattr "time_modify_set"
foreach testobj $FO {
    set tag "$TNAME{b$i}"
    set ASSERTION \
	"Getattr{$tattr WO-attr} of <$testobj>, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    putmsg stdout 1 "Putfh $bfh; Lookup $testobj; Getattr $tattr"
    set res [compound {Putfh $bfh; Lookup $testobj; Getattr $tattr}]
    ckres "Getattr" $status $expcode $res $PASS
}

# c: Getattr{time_modify_set WO-attr} on sock file, expect INVAL
set expcode "INVAL"
set tag "$TNAME{c}"
set tattr "time_modify_set"
set ASSERTION "Getattr{$tattr WO-attr} of sock file, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $tmpS {{mode 0644}} s; Getattr $tattr}]
ckres "Getattr" $status $expcode $res $PASS

# d: Getattr{time_access_set WO-attr} on ATTRDIR, expect INVAL
set expcode "INVAL"
set tag "$TNAME{d}"
set tattr "time_access_set"
set ASSERTION "Getattr{$tattr WO-attr} of ATTRDIR, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr F;
	Getattr type; Getattr $tattr}]
ckres "Getattr" $status $expcode $res $PASS

# e: Getattr{time_modify_set WO-attr} of NAMEDATTR, expect INVAL
set expcode "INVAL"
set tag "$TNAME{e}"
set tattr "time_modify_set"
set ASSERTION "Getattr{$tattr WO-attr} of NAMEDATTR, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr F;
	Lookup $env(ATTRFILE_AT1); Getattr type; Getattr $tattr}]
ckres "Getattr" $status $expcode $res $PASS


# --------------------------------------------------------------
# cleanup remove the created file
set res [compound {Putfh $bfh; Remove $tmpS}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}
# disconnect and exit

Disconnect
exit $PASS
