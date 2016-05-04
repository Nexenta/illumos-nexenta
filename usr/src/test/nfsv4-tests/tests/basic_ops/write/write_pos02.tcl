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
# NFSv4 WRITE operation test - positive tests
#	verify writing to a file without Open using different offset/count

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Create a temp file (size 0) for writing
set newF "WRfile.[pid]"
set tffh [creatv4_file [file join $BASEDIR $newF]]
if { $tffh == $NULL } {
	putmsg stdout 0 "$TNAME: test setup - createv4_file"
	putmsg stderr 0 "\t UNINITIATED: unable to create tmp file, $newF"
	putmsg stderr 1 "  "
	exit $UNINITIATED
}
	

# Start testing
# --------------------------------------------------------------
# a: Write 0B data with Open, offset=0 - expect OK
set expcode "OK"
set ASSERTION "Write 0B data with Open, offset=0, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
ckwrite $bfh "$newF" 0 0 $expcode 0 $PASS


# b: Write 8K ascii with Open, offset=0 - expect OK
set expcode "OK"
set ASSERTION "Write 8K ascii with Open, offset=0, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 8192
ckwrite $bfh "WR02-b" 0 $count $expcode $count $PASS


# c: Write data 1B and skip 1B until 1K+2 - expect OK
set expcode "OK"
set ASSERTION "Write data 1B and skip 1B until 1K+2, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set offset 99
set count 1
set cont [ckwrite $bfh "WR02-c" $offset $count $expcode -1 $FAIL]
# check to file size, must be 1K+2, i.e. 1026
if {$cont == 0} {
	set res [compound {Putfh $bfh; Lookup "WR02-c"; Getattr size}]
	set nsize [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
	if {$nsize != 1026} {
	    putmsg stderr 0 "\t Test FAIL: incorrect new filesize"
	    putmsg stderr 0 "\t            expected=(1026), got=($nsize)."
	} else {
	    logres PASS
	}
}


# --------------------------------------------------------------
# Cleanup the temp file:
set res [compound {Putfh $bfh; Remove $newF; Remove "WR02-b"; Remove "WR02-c"}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove $newF failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
