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
# Close testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

# connect to the test server
Connect

# XXX add catch here later
set tag $TNAME.setup
set dfh [get_fh $BASEDIRS]

proc setparms {} {
	uplevel 1 {set stateid ""}
	uplevel 1 {set seqid ""}
	uplevel 1 {set rflags ""}
	uplevel 1 {set res ""}
	uplevel 1 {set st ""}
}


# Start testing
# --------------------------------------------------------------

# a: normal file
set tag $TNAME{a}
set expct "OK"
set ASSERTION "normal file, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set res ""
	set st [closetst $fh $stateid $seqid res]
	ckres "Close" $st $expct $res $PASS
	if {[removev4 $TESTFILE] == $NULL} {
		putmsg stdout 0 "Can not remove $TESTFILE"
	}
}

# b: close retransmitted same seqid
set tag $TNAME{b}
set expct "OK"
set ASSERTION "close retransmitted same seqid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED retransmitted not realistic"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set res ""
	set st [closetst $fh $stateid $seqid res]
	set st [closetst $fh $stateid $seqid res]
	ckres "Close" $st $expct $res $PASS
	if {[removev4 $TESTFILE] == $NULL} {
		putmsg stdout 0 "Can not remove $TESTFILE"
	}
}


# f: seqid set to max value
set tag $TNAME{f}
set expct "OK"
set ASSERTION "seqid set to max value, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
# max unsigned 32 bit value - 1
set seqid 4294967294
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set res ""
	set st [closetst $fh $stateid $seqid res]
	ckres "Close" $st $expct $res $PASS
	if {[removev4 $TESTFILE] == $NULL} {
		putmsg stdout 0 "Can not remove $TESTFILE"
	}
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
