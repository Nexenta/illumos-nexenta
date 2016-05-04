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
# 	Test with OPEN_RECLAIM option

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# set/confirm the clientid
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set oseqid 1
set oowner "$TNAME-[pid]"

# Start testing
# --------------------------------------------------------------
# a: Open(reclaim) with <cfh> is from just opened file, expect NO_GRACE
set expcode "NO_GRACE"
set ASSERTION "Open(reclaim) w/<cfh> is from just opened file, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set fh1 [basic_open $bfh $env(RWFILE) 0 "$cid $oowner-001" osid oseqid status]
if {$fh1 == -1} {
        putmsg stderr 0 \
		"\t Test UNRESOLVED: basic_open failed, status=($status)"
} else {
	set res [compound {Putfh $fh1; Open $oseqid 3 0 "$cid $oowner-002" \
		    {0 0 {{mode 0666}}} {1 0}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}


# e: Open(reclaim) with <cfh> is a dir, expect ISDIR|NO_GRACE
set expcode "ISDIR|NO_GRACE"
set ASSERTION "Open(reclaim) w/<cfh> is dir, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Open $oseqid 3 0 "$cid $oowner-010" \
		    {0 0 {{mode 0666}}} {1 0}; Getfh}]
putmsg stderr 1 "\tRes=($res)"
ckres "Open" $status $expcode $res $PASS


# h: Open(reclaim) w/<cfh> not from open , expect NO_GRACE
set expcode "NO_GRACE"
set ASSERTION "Open(reclaim) w/<cfh> not from open, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE);
	    Open 10 1 0 "$cid $oowner-100" {0 0 {{mode 0666}}} {1 0}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# j: Open(reclaim) with named_attr file, expect NO_GRACE
set expcode "NO_GRACE"
set ASSERTION "Open(reclaim) named_attr file, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); 
	    Openattr f; Lookup $env(ATTRDIR_AT1); Getattr type;
	    Open 10 1 0 "$cid $oowner-105" {0 0 {{mode 0666}}} {1 0}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
