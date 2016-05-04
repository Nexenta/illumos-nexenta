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
# NFSv4 READ operation test - positive tests
#	verify reading of a binary file with different offset/count

# include all test enironment
source READ.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Get the size of the $ZIPFILE file
set res [compound {Putfh $bfh; Lookup $env(ZIPFILE); Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]


# Start testing
# --------------------------------------------------------------
# a: Read a binary file < 1K (1023 byte) - expect OK
set expcode "OK"
set ASSERTION "Read a binary file < 1K (1023 byte), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 1023
set explen $fsize
set expeof "true"
if {$count < $fsize} {
	set explen $count
	set expeof false
}
ckread $bfh "$env(ZIPFILE)" 0 $count $expcode $explen $expeof


# b: Read a binary file > 1K (1025 byte) - expect OK
set expcode "OK"
set ASSERTION "Read a binary file > 1K (1025 byte), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 1025
set explen $fsize
set expeof "true"
if {$count < $fsize} {
	set explen $count
	set expeof false
}
ckread $bfh "$env(ZIPFILE)" 0 $count $expcode $explen $expeof


# c: Read a binary file till the end of the file, count>32k - expect OK
set expcode "OK"
set ASSERTION "Read a binary file till EOF, count>32k, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 32768
set explen -1
if {$count > $fsize} {
	set explen $fsize
}
ckread $bfh "$env(ZIPFILE)" 0 $count $expcode $explen "true"


# d: Read a text file 1B at a time till EOF - expect OK
set expcode "OK"
set ASSERTION "Read a binary file 1B at a time till EOF, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set offset [expr $fsize / 3]
set count 1
set explen -1
ckread $bfh "$env(TEXTFILE)" $offset $count $expcode $explen "true"


# m: Read a file using special stateid (w/out Open) - expect OK
set expcode "OK"
set ASSERTION "Read a file using special stateid (w/out Open), expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {0 0}
set res [compound {Putfh $bfh; Lookup $env(TEXTFILE); Read $stateid 0 1024}]
ckres "Read" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
