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
# NFSv4 READ operation test - negative tests
#	verify SERVER errors returned with invalid read.

# include all test enironment
source READ.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Try to read a file without <cfh> - expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to read a file without <cfh>, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Read {0 0} 0 1024}]
ckres "Read" $status $expcode $res $PASS


# b: Try to read a file without READ permission - expect ACCESS
set expcode "ACCESS"
set ASSERTION "Try to read a file without READ permission, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(FNOPERM); Read {0 0} 0 1024}]
ckres "Read" $status $expcode $res $PASS


# c: Try to read a directory - expect ISDIR
set expcode "ISDIR"
set ASSERTION "Try to read a directory <cfh>=dir, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Read {0 0} 0 1024}]
ckres "Read" $status $expcode $res $PASS


# d: Try to read a none-regular file - expect INVAL
set expcode "INVAL"
set ASSERTION "Try to read a none-regular file, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(BLKFILE); Read {0 0} 0 1024}]
ckres "Read" $status $expcode $res $PASS


# e: Try to read a symlink - expect INVAL
set expcode "INVAL"
set ASSERTION "Try to read a symlink, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLFILE); Read {0 0} 0 1024}]
ckres "Read" $status $expcode $res $PASS


# s: try to Read a file while it is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Read a file while it is removed, expect $expcode"
#set tag "$TNAME{s}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set tmpF "Read_tmpF.[pid]"
#set tfh [creatv4_file [file join $BASEDIR $tmpF]]
#if { $tfh == $NULL } {
#        putmsg stderr 0 "\t UNINITIATED: unable to create tmp file."
#        putmsg stderr 1 "  "
#        exit $UNRESOLVED
#}
#check_op "Putfh $bfh; Remove $tmpF" "OK" "UNINITIATED"
# XXX Putfh $tfh would STALE, need a separate thread to remove the file
#set res [compound {Putfh $tfh; Read {0 0} 0 2047; Getfh}]
#ckres "Read" $status $expcode $res $PASS
#puts "\t TEST UNTESTED: XXX need a separate thread to remove the file\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
