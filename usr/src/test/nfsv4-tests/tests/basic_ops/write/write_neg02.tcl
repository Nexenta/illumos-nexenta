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
# a: Write a file w/an bad stateid (not from Open) - 
#	expect BAD_STATEID|STALE_STATEID
#
set expcode "BAD_STATEID|STALE_STATEID"
set ASSERTION "Write w/bad stateid (not from Open), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set stateid {12345 67890}
set res [compound {Putfh $bfh; Lookup $env(RWFILE); 
	Write $stateid 0 u a "Write test neg02 \{a\}"}]
ckres "Write" $status $expcode $res $PASS

# Open a file for a valid stateid, then check for errors:
set TRes 0
set tfile "$TNAME.[pid]"
set owner "[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $owner]
if {$cid == -1} {
    set TRes 1
} else {
    set otype 1
    set nfh [basic_open $bfh $tfile $otype "$cid $owner" open_sid oseqid status]
    if {$nfh == -1} {
	set TRes 2
    }
}

# Now do negative WRITE testing:
if {$TRes == 0} {
    incr oseqid
    putmsg stderr 1  "  open_sid from OPEN = ($open_sid)"
    # b: Write a file with an invalid stateid (seqid+1) - expect BAD_STATEID
    #
    set expcode "BAD_STATEID"
    set ASSERTION "Write w/invalid stateid (seqid+1), expect $expcode"
    set tag "$TNAME{b}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set bseqid [expr [lindex $open_sid 0] + 1]
    set bopen_sid "$bseqid [lindex $open_sid 1]"
    putmsg stderr 1 "  new open_sid with trashed seqid: bopen_sid=($bopen_sid)"
    set rres [compound {Putfh $nfh; 
	Write "$bopen_sid" 1 d a "Write test neg02 \{b\}"}]
    ckres "Write" $status $expcode $rres $PASS

    # c: Write a file with an invalid stateid (trash-other) - 
    #	expect BAD_STATEID|STALE_STATEID
    #
    set expcode "BAD_STATEID|STALE_STATEID"
    set ASSERTION "Write w/invalid stateid (trash-other), expect $expcode"
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
    set rres [compound {Putfh $nfh; 
	Write "$copen_sid" 1 d a "Write test neg02 \{c\}"}]
    ckres "Write" $status $expcode $rres $PASS

    # d: Write a locked file with an open_stateid - expect OK
    #
    set expcode "OK"
    set ASSERTION "Write a locked file w/open stateid, expect $expcode"
    set tag "$TNAME{d}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set lseqid 1
    set res [compound {Putfh $nfh; 
	    Lock 2 F 2 10 T $open_sid $lseqid {$oseqid $cid $owner}}]
    incr oseqid
    if {$status != "OK"} {
	set TRes 3
    }
    set rres [compound {Putfh $nfh;  
	    Write "$open_sid" 0 f a "Write test neg02 \{d\}"}]
    ckres "Write" $status $expcode $rres $PASS
    if {$TRes != 3} {
	# Unlock the lock for the Close next
        set lock_sid [lindex [lindex $res 1] 2]
        incr lseqid
        set rres [compound {Putfh $nfh;  Locku 2 $lseqid $lock_sid 2 10}]
    }

    # e: Write w/open_stateid from a wrong file - expect BAD_STATEID
    #
    set expcode "BAD_STATEID"
    set ASSERTION "Write w/open_stateid from wrong file, expect $expcode"
    set tag "$TNAME{e}"
    putmsg stdout 0 "$tag: $ASSERTION"
    set tfh [basic_open $bfh $env(RWFILE) 0 "$cid $owner" osid2 oseqid2 \
    				status "$oseqid"]
    if {$tfh == -1} {
	putmsg stderr 0 "\t Test FAIL: basic_open2 failed on $env(RWFILE)"
    } else {
	incr oseqid2
	set rres [compound {Putfh $nfh; 
		Write "$osid2" 0 d a "Write test neg02 \{e\}"}]
	ckres "Write" $status $expcode $rres $PASS
    }

} elseif {$TRes == 1} {
    putmsg stdout 0 "$TNAME: test setup"
    putmsg stderr 0 "\t Test UNRESOLVED: Open failed"
    putmsg stdout 0 "\t   tests are not run.\n"
} elseif {$TRes == 2} {
    putmsg stdout 0 "$TNAME: test setup"
    putmsg stderr 0 "\t Test UNRESOLVED: Open_confirm failed"
    putmsg stdout 0 "\t   tests are not run.\n"
} elseif {$TRes == 3} {
    putmsg stdout 0 "$TNAME: test setup"
    putmsg stderr 0 "\t Test UNRESOLVED: Lock failed"
    putmsg stdout 0 "\t   tests are not run.\n"
}

# finally close the file:
set res [compound {Putfh $nfh; Close $oseqid2 $open_sid}]
  putmsg stdout 2 "\nClose $oseqid $open_sid ... "
  putmsg stdout 2 "Res: $res"

# f: Write w/open_stateid from a closed file - expect BAD_STATEID|OLD_STATEID
#
set expcode "BAD_STATEID|OLD_STATEID"
set ASSERTION "Writew/open_stateid from closed file, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; 
	Write "$open_sid" 0 f a "Write test neg02 \{f\}"}]
ckres "Write" $status $expcode $rres $PASS


# --------------------------------------------------------------
# Cleanup the temp file:
set res [compound {Putfh $bfh; Remove $tfile}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove $tfile failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
