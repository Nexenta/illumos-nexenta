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
# NFSv4 READ/WRITE operation test - positive boundary tests
#	verify reading/writing of a file around the boundary

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# First create a tmp file for testing
set hid "[pid][clock seconds]"
set cid [getclientid $hid]
if {$cid == -1} {
        putmsg stdout 0 "$TNAME: test setup - getclientid"
        putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
        exit $UNRESOLVED
}
# Open to create the temp file:
set TFILE "$TNAME.[pid]"
set owner "owner-$TFILE"
set otype 1
set cid_owner "$cid $owner"
set nfh [basic_open $bfh $TFILE $otype $cid_owner open_sid oseqid status]
if {$nfh == -1} {
        putmsg stdout 0 "$TNAME: test setup - basic_open"
        putmsg stderr 0 \
		"\t Test UNRESOLVED: create $TFILE failed, status=$status"
	exit $UNRESOLVED
}

set 2G 2147483648


# Start testing
# --------------------------------------------------------------
# a: Write up to 2G boundary (offset=2g-4K, data=4K) - expect OK
set expcode "OK"
set ASSERTION "Write up to 2G boundary (off=2g-4K, data=4K), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 4096
set off [expr $2G - $count]
set data [string repeat "A" $count]
set res [compound {Putfh $nfh; Write $open_sid $off f a $data; Getattr size}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test FAIL: failed to write at $off for 4K."
	putmsg stderr 1 "\t\t Res: $res"
} else {
    set fsize [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
    if {$fsize != $2G} {
	putmsg stderr 0 "\t Test FAIL: incorrect file size after Write"
	putmsg stderr 0 "\t\t expected=(2G); got=($fsize)"
	putmsg stderr 1 "\t\t Res: $res"
    } else {
	logres PASS
    }
}


# b: Read up to 2G boundary (offset=2g-4K, count=4K) - expect OK
set expcode "OK"
set ASSERTION "Read up to 2G boundary (off=2g-4K, count=4K), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Read $open_sid $off $count; Getattr size}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test FAIL: failed to read at $off for $count."
	putmsg stderr 1 "\t\t Res: $res"
} else {
    set rsize [lindex [lindex [lindex [lindex $res 1] 2] 1] 1]
    if {$rsize != $count} {
	putmsg stderr 0 "\t Test FAIL: incorrect read len"
	putmsg stderr 0 "\t\t expected=($count); got=($rsize)"
	putmsg stderr 1 "\t\t Res: $res"
    } else {
	logres PASS
    }
}


# c: Write over 2G boundary (offset=2g-4K, data=8K) - expect OK
set expcode "OK"
set ASSERTION "Write over 2G boundary (off=2g-4K, data=8K), expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 4096
set off [expr $2G - $count]
set data [string repeat "B" [expr $count * 2]]
set res [compound {Putfh $nfh; Write $open_sid $off f a $data; Getattr size}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test FAIL: failed to write at $off for 4K."
	putmsg stderr 1 "\t\t Res: $res"
} else {
    set fsize [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
    if {[expr $fsize - $count] != $2G} {
	putmsg stderr 0 "\t Test FAIL: incorrect file size after Write"
	putmsg stderr 0 "\t\t expected=(2G+4K); got=($fsize)"
	putmsg stderr 1 "\t\t Res: $res"
    } else {
	logres PASS
    }
}


# d: Read over 2G boundary (offset=2g-4K, count=8K) - expect OK
set expcode "OK"
set ASSERTION "Read over 2G boundary (off=2g-4K, count=8K), expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 8192
set res [compound {Putfh $nfh; Read $open_sid $off $count; Getattr size}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test FAIL: failed to read at $off for $count."
	putmsg stderr 1 "\t\t Res: $res"
} else {
    set rsize [lindex [lindex [lindex [lindex $res 1] 2] 1] 1]
    if {$rsize != $count} {
	putmsg stderr 0 "\t Test FAIL: incorrect read len"
	putmsg stderr 0 "\t\t expected=($count); got=($rsize)"
	putmsg stderr 1 "\t\t Res: $res"
    } else {
	logres PASS
    }
}


# --------------------------------------------------------------
# Cleanup the temp file:
incr oseqid
set res [compound {Putfh $nfh; Close $oseqid $open_sid; 
	Putfh $bfh; Remove $TFILE}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove $TFILE failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
