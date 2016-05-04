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
# NFSv4 OPEN operation test - positive tests
#   Basic fucntion of OPEN op

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
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open(CREATE/GUARDED) new file (size=888), expect OK
set expcode "OK"
set ASSERTION "Open(CREATE/UNCHECK) new file (size=888), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 1
set size 888
set TFILE "$TNAME.[pid]-a"
set nfh [basic_open $bfh $TFILE 1 "$cid $owner-a" osid oseqid status \
	$seqid 0 666 $size]
if {$nfh == -1} {
    putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=($status)"
} else {
    # verify new filehandle is good (to close) and size is 888
    set oseqid [expr $oseqid + 1]
    set res [compound {Putfh $nfh; Close $oseqid $osid; Getattr size}]
    if {[ckres "Close" $status $expcode $res $FAIL] == "true"} {
	set nsize [extract_attr [lindex [lindex $res 2] 2] size]
	if {$nsize != $size} {
	    putmsg stderr 0 "\t Test FAIL: size created incorrect"
	    putmsg stderr 0 "\t\t expected=($size), got=($nsize)."
	    putmsg stderr 1 "\t\t Res: $res"
	} else {
	    logres PASS
	}
    }
}



# b: Open(CREATE/UNCHECK) existing file (size=0) to truncate, expect OK
set expcode "OK"
set ASSERTION \
    "Open(CREATE/UNCHECK) old file (size=0) to truncate, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 10
set size 0
set nfh [basic_open $bfh $TFILE 1 "$cid $owner-b" osid oseqid status \
	$seqid 0 666 $size]
if {$nfh == -1} {
    putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=($status)"
} else {
    # verify new filehandle is good (to close) and size is 0
    set oseqid [expr $oseqid + 1]
    set res [compound {Putfh $nfh; Close $oseqid $osid; Getattr size}]
    if {[ckres "Close" $status $expcode $res $FAIL] == "true"} {
	set nsize [extract_attr [lindex [lindex $res 2] 2] size]
	if {$nsize != $size} {
	    putmsg stderr 0 "\t Test FAIL: size created incorrect"
	    putmsg stderr 0 "\t\t expected=($size), got=($nsize)."
	    putmsg stderr 1 "\t\t Res: $res"
	} else {
	    logres PASS
	}
    }
}


# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set res [compound {Putfh $bfh; Remove $TFILE}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
