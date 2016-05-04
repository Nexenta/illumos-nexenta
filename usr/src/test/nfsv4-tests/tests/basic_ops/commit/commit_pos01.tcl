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
# NFSv4 COMMIT operation test - positive tests

# include all test enironment
source COMMIT.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic Commit entire file of unsync data, expect OK
set expcode "OK"
set ASSERTION "basic Commit entire file of unsync data, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set newFa "Com-a.[pid]"
set tfh [creatv4_file [file join $BASEDIR $newFa] 0666 1024]
# writ some data w/unsync flag:
set data [string repeat "a" 1024]
set res [compound {Putfh $tfh; Write {0 0} 1024 u a $data; 
	Write {0 0} 2048 u a $data; Commit 0 0; Getfh}]
set cont [ckres "Commit" $status $expcode $res $FAIL]
# Now verify filehandle after COMMIT remain the same
fh_equal $tfh [lindex [lindex $res 4] 2] $cont $PASS


# b: Commit only portion of unsync data, expect OK
set expcode "OK"
set ASSERTION "Commit only portion of unsync data, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set newFb "Com-b.[pid]"
set tfh [creatv4_file [file join $BASEDIR $newFb]]
# writ some data w/unsync flag:
set data [string repeat "b" 2047]
set res [compound {Putfh $tfh; Write {0 0} 0 u a $data; 
	Write {0 0} 2048 u a $data; Commit 10 1024; Getfh}]
set cont [ckres "Commit" $status $expcode $res $FAIL]
# Now verify filehandle after COMMIT remain the same
fh_equal $tfh [lindex [lindex $res 4] 2] $cont $PASS


# c: Commit of data_sync data, expect OK
set expcode "OK"
set ASSERTION "Commit of data_sync data, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set newFc "Com-c.[pid]"
set tfh [creatv4_file [file join $BASEDIR $newFc]]
# writ some data w/data_sync flag:
set data [string repeat "c" 4097]
set res [compound {Putfh $tfh; Write {0 0} 1 d a $data; 
	Commit 12 0; Getfh}]
set cont [ckres "Commit" $status $expcode $res $FAIL]
# Now verify filehandle after COMMIT remain the same
fh_equal $tfh [lindex [lindex $res 3] 2] $cont $PASS


# d: Try to do Commit twice of same data, expect OK
set expcode "OK"
set ASSERTION "Try to do Commit twice of same data, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set newFd "Com-d.[pid]"
set tfh [creatv4_file [file join $BASEDIR $newFd]]
# writ some data w/file_sync flag:
set data [string repeat "d" 8196]
set res [compound {Putfh $tfh; Write {0 0} 0 f a $data; 
	Commit 10 1024; Commit 1000 4096; Getfh}]
set cont [ckres "Commit" $status $expcode $res $FAIL]
# Now verify filehandle after COMMIT remain the same
fh_equal $tfh [lindex [lindex $res 4] 2] $cont $PASS


# --------------------------------------------------------------
# Cleanup the temp file:
set res [compound {Putfh $bfh; Remove $newFa; 
	Remove $newFb; Remove $newFc; Remove $newFd}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove tmp files failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
