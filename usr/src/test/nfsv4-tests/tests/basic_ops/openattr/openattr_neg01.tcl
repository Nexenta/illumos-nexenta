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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 OPENATTR operation test - negative tests
#	verify SERVER errors returned under error conditions

# include all test enironment
source OPENATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Try to openattr without <cfh> - expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Try to openattr without <cfh>, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Openattr T}]
ckres "Openattr" $status $expcode $res $PASS


# b: Openattr to create to a no permission dir - expect ACCESS
set expcode "ACCESS"
set ASSERTION "Openattr to create to a no permission dir, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM); Openattr T}]
ckres "Openattr" $status $expcode $res $PASS


# c: Openattr to create (true) to a readonly file - expect ACCESS
set expcode "ACCESS"
set ASSERTION "Openattr to create(T) to a readonly file, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
} else {
    set res [compound {Putfh $bfh; Lookup $env(ROFILE); Openattr T}]
    ckres "Openattr" $status $expcode $res $PASS
}


# d: Openattr with <cfh> is a none-regular file - expect NOTSUPP
set expcode "NOTSUPP"
set ASSERTION "Openattr w/<cfh> is a none-regular file (blk), expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(BLKFILE); Openattr T}]
ckres "Openattr" $status $expcode $res $PASS


# e: Openattr none create with a FIFO file - expect NOTSUPP
set expcode "NOTSUPP"
set ASSERTION "Openattr none create with a FIFO file, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(FIFOFILE); Openattr F}]
ckres "Openattr" $status $expcode $res $PASS


# k: Openattr none create with no named_attr dir setup - expect NOENT
set expcode "NOENT"
set ASSERTION "Openattr none create w/no named_attr dir setup, expect $expcode"
set tag "$TNAME{k}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
} else {
    set res [compound {Putfh $bfh; Lookup $env(DIR0777); 
	Lookup $env(RWFILE); Openattr F}]
    ckres "Openattr" $status $expcode $res $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
