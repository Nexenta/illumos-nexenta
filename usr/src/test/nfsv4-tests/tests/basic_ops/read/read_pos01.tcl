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
#	verify reading of a textfile with different offset/count

# include all test enironment
source READ.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Get the size of the $TEXTFILE file
set res [compound {Putfh $bfh; Lookup $env(TEXTFILE); Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]


# Start testing
# --------------------------------------------------------------
# a: Read a regular file using count > filesize - expect OK
set expcode "OK"
set ASSERTION "Read a regular file using count > filesize, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set count [expr $fsize + 100]
ckread $bfh "$env(TEXTFILE)" 0 $count $expcode $fsize "true"


# b: Read a regular file using offset > filesize - expect OK
set expcode "OK"
set ASSERTION "Read a regular file using offset > filesize, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set offset [expr $fsize + 100]
ckread $bfh "$env(TEXTFILE)" $offset 256 $expcode 0 "true"


# c: Read a regular file using count=0 - expect OK
set expcode "OK"
set ASSERTION "Read a regular file using count=0, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 0
ckread $bfh "$env(TEXTFILE)" 0 $count $expcode $count "false"


# d: Read an empty file using offset/count > 0 - expect OK
set expcode "OK"
set ASSERTION "Read an empty file using offset/count > 0, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
ckread $bfh "$env(ROEMPTY)" 0 256 $expcode 0 "true"


# e: Read a regular file using offset=count=1/4(fsize) - expect OK
set expcode "OK"
set ASSERTION "Read a regular file w/offset=count=1/3(fsize), expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set count [expr $fsize / 3]
ckread $bfh "$env(TEXTFILE)" $count $count $expcode $count "false"


# f: Read a regular file till eof - expect OK
set expcode "OK"
set ASSERTION "Read a regular file till EOF, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set count [expr $fsize * 2]
ckread $bfh "$env(TEXTFILE)" 0 $count $expcode $fsize "true"


# i: Read a regular file with max count (-1) - expect OK
set expcode "OK"
set ASSERTION "Read a regular file with max count (-1), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
set count -1
ckread $bfh "$env(TEXTFILE)" 0 $count $expcode $fsize "true"


# j: Read a regular file with max offset (-1) - expect OK
set expcode "OK"
set ASSERTION "Read a regular file with max offset (-1), expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
set off -1
ckread $bfh "$env(TEXTFILE)" $off 16 $expcode 0 "true"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
