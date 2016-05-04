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
# NFSv4 OPENATTR operation test - positive tests

# include all test enironment
source OPENATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Readdir with <cfh> from OPENATTR(f) - expect OK
set expcode "OK"
set ASSERTION "Readdir with <cfh> from OPENATTR(f), expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr F;
	Readdir 0 0 1024 1024 type}]
if {[ckres "Openattr/Readdir" $status $expcode $res $FAIL] == "true"} {
    # verify attribute returned in READDIR is namedattr
    set rdres [lindex [lindex $res 3] 3]
    set notmatch 0
    foreach de $rdres {
	set aval [extract_attr [lindex $de 2] "type"]
	if {$aval != "namedattr"} {
	    incr notmatch
	    putmsg stderr 0 \
	    "\t Test FAIL: direntry($de) got type=($aval), expected=(namedattr)"
	    putmsg stderr 1 "\t res=($res)"
	}
    }
    if {$notmatch == 0} {
    	logres PASS
    }
}


# b: Try to create a new attr file under OPENATTR(f) - expect OK
set expcode "OK"
set ASSERTION "Try to create a new attr file under OPENATTR(f), expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "owner-attr"
set cid [getclientid $owner]
set oseqid 1
set otype 1
set tmpF "ATTR.tmp.[pid]"
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr F; Getfh;
	Open $oseqid 3 0 {$cid $owner} {$otype 0 {{size 0}}} {0 $tmpF}; 
	Getfh; Getattr type}]
if {[ckres "Openattr/Open" $status $expcode $res $FAIL] == "true"} {
    set open_sid [lindex [lindex $res 4] 2]
    set ofh [lindex [lindex $res 3] 2]
    set ffh [lindex [lindex $res 5] 2]
    set nat [extract_attr [lindex [lindex $res 6] 2] "type"]
    # verify attribute of newly created file is namedattr
    if {$nat != "namedattr"} {
	putmsg stderr 0 \
	"\t Test FAIL: new file($tmpF) got type=($nat), expected=(namedattr)"
	putmsg stderr 1 "\t res=($res)"
    } else {
	    logres PASS
    }
    # finally cleanup
    incr oseqid
    compound {Putfh $ffh; Close $oseqid $open_sid; Putfh $ofh; Remove $tmpF}
}


# f: Lookupp of OPENATTR(f), verify filehandle - expect OK
set expcode "OK"
set ASSERTION "Lookupp of OPENATTR(f), verify filehandle, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Getfh; 
	Openattr F; Lookupp; Getfh}]
set cont [ckres "Openattr/Lookupp" $status $expcode $res $FAIL]
# verify filehandle are same as the file
set afh [lindex [lindex $res 2] 2]
set ofh [lindex [lindex $res 5] 2]
fh_equal $afh $ofh $cont $PASS


# g: Lookupp of OPENATTR(f), verify type - expect OK
set expcode "OK"
set ASSERTION "Lookupp of OPENATTR(f), verify type, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); 
	Openattr F; Lookupp; Getattr type}]
if {[ckres "Openattr/Lookupp" $status $expcode $res $FAIL] == "true"} {
    # verify type should match ATTRDIR
    set aval [extract_attr [lindex [lindex $res 4] 2] "type"]
    if {$aval != "dir"} {
	    putmsg stderr 0 \
	    "\t Test FAIL: after .., got type=($aval), expected=(dir)"
	    putmsg stderr 1 "\t res=($res)"
    } else {
	    logres PASS
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
