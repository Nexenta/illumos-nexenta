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
# Open_confirm testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

# connect to the test server
Connect


# set clientid with server
set tag $TNAME.setup
set clientid ""
set res ""
set cverf ""
if {[setclient [clock clicks] "o.[pid]" clientid cverf res] == "OK"} {
        if {[setclientconf $clientid $cverf res] != "OK"} {
                putmsg stdout 0 "ERROR: cannot setclientid"
                return $UNINITIATED
        }
} else {
        return $UNINITIATED
}

# XXX add catch here later
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
set filename "$tag"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set st [openconf4 $fh $rflags stateid seqid res]
ckres "Open_confirm" $st $expct $res $PASS
closev4 $TESTFILE $fh $stateid $seqid


# b: normal file, open retransmitted
set tag $TNAME{b}
set expct "OK"
set ASSERTION "normal file, open retransmitted, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename "$tag"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
incr seqid 3
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set st [openconf4 $fh $rflags stateid seqid res]
ckres "Open_confirm" $st $expct $res $PASS
closev4 $TESTFILE $fh $stateid $seqid


# c: normal file, openconfirm retransmitted
set tag $TNAME{c}
set expct "OK"
set ASSERTION "normal file, openconfirm retransmitted, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename "$tag"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set ste2 $stateid
set st [openconf4 $fh $rflags ste2 seqid res]
incr seqid -1
set st [openconf4 $fh $rflags stateid seqid res]
ckres "Open_confirm" $st $expct $res $PASS
closev4 $TESTFILE $fh $stateid $seqid


# f: seqid set to max value
set tag $TNAME{f}
set expct "OK"
set ASSERTION "seqid set to max value, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename "$tag"
set TESTFILE [file join $BASEDIR $tag]
setparms
# max unsigned 32 bit value - 2
set seqid [string range "[expr pow(2,32) - 2]" 0 end-2]
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# max unsigned 32 bit value - 1
set seqid [string range "[expr pow(2,32) - 1]" 0 end-2]
set st [openconf4 $fh $rflags stateid seqid res]
ckres "Open_confirm" $st $expct $res $PASS
# seqid in server should be 0 now
set seqid 0
closev4 $TESTFILE $fh $stateid $seqid


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
