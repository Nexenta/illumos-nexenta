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
# NFSv4 OPEN operation test - positive tests
#   Basic fucntion of OPEN op

# include all test enironment
source OPEN.env
source OPEN_proc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open an existing RW file (access=3,deny=0,createmode=0), expect OK
set expcode "OK"
set ASSERTION \
	"Open existing RW file (access=3,deny=0,create=0), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 1
set TFILE $env(RWFILE)
set res [compound {Putfh $bfh; 
	Open $seqid 3 0 "$cid $owner-00111" {0 0 {{mode 0644}}} {0 $TFILE};
	Getfh; Putfh $bfh; Lookup $TFILE; Getfh}]
set cont [ckres "Open" $status $expcode $res $FAIL]
if {$cont == "true"} {
	# verify the FH of OPEN is same as LOOKUP
	set fh1 [lindex [lindex $res 2] 2]
	set fh2 [lindex [lindex $res 5] 2]
	if {[fh_equal $fh1 $fh2 $cont $PASS] != "true"} {
		putmsg stderr 0 "  ** WARNING: assertion <a> did not PASS;"
		putmsg stderr 0 \
		"\tassertion <a1> may not run correctly as <a1> depends on <a>"
	}

	# a1: Replay the same Open request, expect OK
	set expcode "OK"
	set ASSERTION "Replay the same Open request, expect $expcode"
	set tag "$TNAME{a1}"
	putmsg stdout 0 "$tag: $ASSERTION"
	set res [compound {Putfh $bfh; 
		Open $seqid 3 0 "$cid $owner-00111" \
			{0 0 {{mode 0644}}} {0 $TFILE}; Getfh}]
	if {[ckres "Open" $status $expcode $res $FAIL] == "true"} {
		# verify the FH of OPEN is good to close)
		set stateid [lindex [lindex $res 1] 2]
		set rflags [lindex [lindex $res 1] 4]
		incr seqid
		if {[ckclose $fh1 $rflags $seqid $stateid] == "true"} {
			logres "PASS"
		}
	}
}


# b: Open w/<cfh> is NAMEATTR (access=1,deny=0,createmode=0), expect OK
set expcode "OK"
set ASSERTION \
    "Open RO file w/cfh=NAMEATTR (access=1,deny=0,create=0), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set oseqid 10
set TFILE $env(ATTRDIR_AT1)
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr T; Getfh;
	Open $oseqid 1 0 "$cid $owner-00222" {0 0 {{mode 0644}}} {0 $TFILE}
	Getfh}]
if {[ckres "Open" $status $expcode $res $FAIL] == "true"} {
	# verify the FH of OPEN is good (to close) and is same as LOOKUP
	set stateid [lindex [lindex $res 4] 2]
	set rflags [lindex [lindex $res 4] 4]
	set fh1 [lindex [lindex $res 5] 2]
	set nafh [lindex [lindex $res 3] 2]
	set res [compound {Putfh $nafh; Lookup $TFILE; Getfh}]
	set fh2 [lindex [lindex $res 2] 2]
	incr oseqid
	set cont [ckclose $fh1 $rflags $oseqid $stateid]
	if {"$cont" == "true"} {
		fh_equal $fh1 $fh2 $cont $PASS
	}
}


# f: Open a file w/out Confirm, and Open another file w/same owner.
#    Then try to confirm second  OPEN, expect OK
set expcode "OK"
set A "OPEN a file w/out Confirm, OPEN another file w/same owner; \n"
set ASSERTION "$A \t then try to confirm 2nd OPEN, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set seqid 10
set TFILE $env(RWFILE)
set res [compound {Putfh $bfh; 
    Open $seqid 3 0 "$cid $owner" {0 0 {{mode 0644}}} {0 $env(RWFILE)}; Getfh}]
if {$status != "OK"} {
    putmsg stderr 0 "\t Test UNRESOLVED: failed on 1st Open $env(RWFILE)"
    putmsg stderr 0 "\t\t expected status=($expcode), got=($status)"
    putmsg stderr 1 "\t Res=($res)."
} else {
    set oseqid 100
    set res [compound {Putfh $bfh; 
	Open $oseqid 1 0 "$cid $owner" {0 0 {{mode 0644}}} {0 $env(TEXTFILE)};
	Getfh}]
    if {$status != "OK"} {
        putmsg stderr 0 "\t Test UNRESOLVED: failed on 2nd Open $env(TEXTFILE)"
        putmsg stderr 0 "\t\t expected status=($expcode), got=($status)"
        putmsg stderr 1 "\t Res=($res)."
    } else {
	set osid [lindex [lindex $res 1] 2]
	set rflags [lindex [lindex $res 1] 4] 
	set nfh [lindex [lindex $res 2] 2]
	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	    incr oseqid
    	    set res [compound {Putfh $nfh; Open_confirm $osid $oseqid}]
    	    ckres "Open_conform" $status $expcode $res $PASS
	    if {$status == "OK"} {
    	    	set osid [lindex [lindex $res 1] 2]
	    }
	} else {
            putmsg stderr 0 "\t Test NOTINUSE: 2nd OPEN did not ask for confirm"
            putmsg stderr 1 "\t Res=($res)."
	}
	# Close the file to make file in clear state:
	incr oseqid
	set res [compound {Putfh $nfh; Close $oseqid $osid}]
	putmsg stderr 1 "\t CLOSE res=($res)."
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
