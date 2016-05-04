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
# NFSv4 LOCK, LOCKT, LOCKU operation test - negative tests
#	Verify server returns correct errors with negative requests.

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set hid "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set seqid 1

# Create a temp test file and get it's filehandle
set TFILE "$TNAME.[pid]"
set size 888
set open_owner "[pid][clock seconds]"
set nfh [basic_open $bfh $TFILE 1 "$cid $open_owner" \
	osid oseqid status $seqid 0 666 $size 3]
if {$nfh == -1} {
	putmsg stdout 0 "$TNAME: test setup - basic_open"
	putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($TFILE)"
	putmsg stderr 0 "\t\t basic_open failed, status=($status)."
	exit $UNRESOLVED
}


# Start testing
# --------------------------------------------------------------
# a: Lock w/length=0, expect INVAL
set expcode "INVAL"
set ASSERTION "Lock w/length=0, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
incr oseqid
set lseqid 1
set res [compound {Putfh $nfh; 
	Lock 2 F 0 0 T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS


# b: Lock w/offset+length over max, expect INVAL
set expcode "INVAL"
set ASSERTION "Lock with offset+length over max, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 5
incr oseqid
set halfmax 9300000000000000000
set res [compound {Putfh $nfh; 
	Lock 2 F $halfmax $halfmax T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS


# e: Lockt w/length=0, expect INVAL
set expcode "INVAL"
set ASSERTION "Lockt w/length=0, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Lockt 2 $cid "lowner.[pid]-b" 1 0}]
ckres "Lockt" $status $expcode $res $PASS


# f: Lockt w/offset+length over max, expect INVAL
set expcode "INVAL"
set ASSERTION "Lockt w/offset+length over max, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set halfmax 9300000000000000000
set res [compound {Putfh $nfh;
	Lockt 2 $cid "lowner.[pid]-b" $halfmax $halfmax }]
ckres "Lockt" $status $expcode $res $PASS


putmsg stdout 0 \
  "\n  ** Now downgrade the ($TFILE)) to access=W for following cases;"
putmsg stdout 0 \
  "     If fails, assertions(i,j) will not be run."
# h: Open_downgrade the file to WRONLY, expect OK
set expcode "OK"
set ASSERTION "Open_downgrade the file to WRONLY, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
incr oseqid
set tag "$TNAME-Open_downgrade"
set res [compound {Putfh $nfh; Open_downgrade $osid $oseqid 2 0}]
if {$status != "OK"} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: Open_downgrade failed status=$status."
	putmsg stderr 1 "\t   Res=$res"
} else {
	logres "PASS"

	# get new stateid from Open_downgrade
	set osid [lindex [lindex $res 1] 2]

	# i: Try to set a READ Lock, expect OPENMODE
	set expcode "OPENMODE"
	set ASSERTION "Try to set a READ Lock, expect $expcode"
	set tag "$TNAME{i}"
	putmsg stdout 0 "$tag: $ASSERTION"
	incr oseqid
	incr lseqid
	set res [compound {Putfh $nfh; 
		Lock 1 F 1024 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
	ckres "Lock(RD)" $status $expcode $res $PASS

	# j: Try to set a READW Lock, expect OPENMODE
	set expcode "OPENMODE"
	set ASSERTION "Try to set a READW Lock, expect $expcode"
	set tag "$TNAME{j}"
	putmsg stdout 0 "$tag: $ASSERTION"
	incr oseqid
	incr lseqid
	set res [compound {Putfh $nfh; 
		Lock 3 F 512 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
	ckres "Lock(RDW)" $status $expcode $res $PASS
}


putmsg stdout 0 \
"\n  ** Now Open ($env(ROFILE)) w/out Confirm for the following assertions(n):"

# m: OPEN a file without confirm for next Lock test, expect OK
set expcode "OK"
set ASSERTION "OPEN a file without confirm, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set oseqid 100
set tag "$TNAME{m}"
set open_owner2 "$tag-oowner"
set res [compound {Putfh $bfh; Open $oseqid 1 0 "$cid $open_owner2" \
	{0 0 {{mode 0644}}} {0 $env(ROFILE)}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: unable to Open $env(ROFILE)"
	putmsg stderr 0 "\t\t  Assertions(n) will not run"
	putmsg stderr 1 "\t Res=($res)."
} else {
	logres "PASS"
	set osid [lindex [lindex $res 1] 2]
	set nfh [lindex [lindex $res 2] 2]

	# n: Try to lock the file, expect BAD_STATEID
	set expcode "BAD_STATEID"
	set ASSERTION "Lock on un-conformed file, expect $expcode"
	set tag "$TNAME{n}"
	putmsg stdout 0 "$tag: $ASSERTION"
	# make sure rflags requires a confirm
	set rflags [lindex [lindex $res 1] 4] 
	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	    incr oseqid
	    set res [compound {Putfh $nfh; 
		Lock 1 F 10 20 T $osid 2 "$oseqid $cid $open_owner"}]
	    ckres "Lock" $status $expcode $res $PASS
	} else {
	    putmsg stderr 0 \ "\t Test NOTINUSE: no OPEN_CONFIRM is required."
	}
}


# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set tag "$TNAME-cleanup"
set res [compound {Putfh $bfh; Remove $TFILE}]
if {($status != "OK") && ($status != "NOENT")} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
