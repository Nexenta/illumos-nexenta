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
# a: Read a file w/an invalid stateid (not from Open) - 
#	expect BAD_STATEID|STALE_STATEID
#
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Read a file w/invalid stateid (not from Open), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {12345 67890}
set res [compound {Putfh $bfh; Lookup $env(TEXTFILE); Read $stateid 0 1024}]
ckres "Read" $status $expcode $res $PASS

# Open a file for a valid stateid, then check for errors:
set TRes 0
set owner "[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $owner]
if {$cid == -1} {
    set TRes 1
} else {
    set otype 0
    set nfh [basic_open $bfh $env(ROFILE) $otype "$cid $owner" \
	open_sid oseqid status 1 0 600 0 1]
    if {$nfh == -1} {
	set TRes 2
    }
}

# Now do negative READ testing:
if {$TRes == 0} {
    incr oseqid
    putmsg stderr 1  "  open_sid from OPEN = ($open_sid)"
    # b: Read a file with an invalid stateid (seqid+1) - expect BAD_STATEID
    #
    set expcode "BAD_STATEID"
    set ASSERTION "Read a file w/invalid stateid (seqid+1), expect $expcode"
    set tag "$TNAME{b}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set bseqid [expr [lindex $open_sid 0] + 1]
    set bopen_sid "$bseqid [lindex $open_sid 1]"
    putmsg stderr 1 "  new open_sid with trashed seqid: bopen_sid=($bopen_sid)"
    set rres [compound {Putfh $nfh; Read "$bopen_sid" 0 512}]
    ckres "Read" $status $expcode $rres $PASS

    # c: Read a file w/invalid stateid (trash-other) - 
    #	expect BAD_STATEID|STALE_STATEID
    #
    set expcode "BAD_STATEID|STALE_STATEID"
    set ASSERTION "Read a file w/invalid stateid (trash-other), expect $expcode"
    set tag "$TNAME{c}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set newS ""
    set oldS [lindex $open_sid 1]
    set l [string length $oldS]
    for {set i 0} {$i < $l} {incr i} {
    	append newS [string index $oldS end-$i]
    }
    set copen_sid "[lindex $open_sid 0] $newS"
    putmsg stderr 1 "  new open_sid with trashed other: copen_sid=($copen_sid)"
    set rres [compound {Putfh $nfh; Read "$copen_sid" 1 257}]
    ckres "Read" $status $expcode $rres $PASS

    # d: Read w/open_stateid from a wrong file - expect BAD_STATEID
    #
    set expcode "BAD_STATEID"
    set ASSERTION "Read w/open_stateid from wrong file, expect $expcode"
    set tag "$TNAME{d}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set tfh [basic_open $bfh $env(RWFILE) 0 "$cid $owner-d" osid2 oseqid2 \
	status $oseqid 0 600 0 1]
    if {$tfh == -1} {
        putmsg stderr 0 "\t Test FAIL: basic_open2 failed on $env(RWFILE)"
        putmsg stderr 0 "\t   status=($status)"
    } else {
	incr oseqid2
        set rres [compound {Putfh $nfh; Read "$osid2" 2 88}]
        ckres "Read" $status $expcode $rres $PASS
    }


  # then close the file:
  set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
    putmsg stdout 2 "\nClose $oseqid $open_sid ... "
    putmsg stdout 2 "Res: $res"

    # m: Read a file after file closed - expect BAD_STATEID|OLD_STATEID
    #
    set expcode "BAD_STATEID|OLD_STATEID"
    set ASSERTION "Read a file after file is closed, expect $expcode"
    set tag "$TNAME{m}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set rres [compound {Putfh $nfh; Read "$open_sid" 16 255}]
    ckres "Read" $status $expcode $rres $PASS


} elseif {$TRes == 1} {
    putmsg stderr 0 "\t Test UNINITIATED: getclientid() failed"
    putmsg stdout 0 "\t   tests are not run.\n"
} elseif {$TRes == 2} {
    putmsg stderr 0 "\t Test UNINITIATED: basic_open() failed"
    putmsg stdout 0 "\t   tests are not run.\n"
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
