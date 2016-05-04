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
# NFSv4 WRITE operation test - negative tests
#	verify SERVER errors returned with invalid write.

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Try to write a file without <cfh> - expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to write a file without <cfh>, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Write {0 0} 0 f a "Just a test"}]
ckres "Write" $status $expcode $res $PASS


# b: Try to write a file without WRITE permission - expect ACCESS
set expcode "ACCESS"
set ASSERTION "Try to write a file without WRITE permission, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); 
	Write {0 0} 1 u a "Write_neg01\{b\}"}]
ckres "Write" $status $expcode $res $PASS


# c: Try to write a directory - expect ISDIR
set expcode "ISDIR"
set ASSERTION "Try to write a directory <cfh>=dir, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Write {0 0} 2 d a "Write_neg01\{c\}"}]
ckres "Write" $status $expcode $res $PASS


# d: Try to write a none-regular file - expect INVAL
set expcode "INVAL"
set ASSERTION "Try to write a none-regular file, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(BLKFILE); 
	Write {0 0} 3 f a "Write_neg01\{d\}"}]
ckres "Write" $status $expcode $res $PASS


# e: Try to write a symlink - expect INVAL
set expcode "INVAL"
set ASSERTION "Try to write a symlink, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLFILE);
	Write {0 0} 4 f a "Write_neg01\{d\}"}]
ckres "Write" $status $expcode $res $PASS


# i: write to a file w/big offset (-1) - expect FBIG
set expcode "FBIG"
set ASSERTION "write to a file w/big offset (-1), expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup $env(RWFILE);
#	Write {0 0} -1 u a "Write_neg01\{i\}-EFBIG"}]
#ckres "Write" $status $expcode $res $PASS
putmsg stdout 0 "\t TEST UNTESTED: XXX commented out due to following bug:"
putmsg stdout 0 "\t	4665413 - nfsd coredumped"


# j: write to a file w/offset=2^63-2 for 2 bytes  - expect FBIG
set expcode "FBIG"
set ASSERTION "write w/offset=2^63-2 for 2 bytes, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Lookup $env(RWFILE);
#	Write {0 0} 9223372036854775806 u a "xx"}]
#ckres "Write" $status $expcode $res $PASS
putmsg stdout 0 "\t TEST UNTESTED: XXX commented out due to following bug:"
putmsg stdout 0 "\t	4665413 - nfsd coredumped"


# s: try to Write a file while it is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Write a file while it is removed, expect $expcode"
set tag "$TNAME{s}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set tmpF "Write_tmpF.[pid]"
#set tfh [creatv4_file [file join $BASEDIR $tmpF]]
#if { $tfh == $NULL } {
#        putmsg stderr 0 "\t UNINITIATED: unable to create tmp file."
#        putmsg stderr 1 "  "
#        exit $UNINITIATED
#}
#check_op "Putfh $bfh; Remove $tmpF" "OK" "UNINITIATED"
# XXX Putfh $tfh would STALE, need a separate thread to remove the file
#set res [compound {Putfh $tfh; Write {0 0} 1 f a "Write_neg01\{s\}" ; Getfh}]
#ckres "Write" $status $expcode $res $PASS
#puts "\t TEST UNTESTED: XXX need a separate thread to remove the file\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
