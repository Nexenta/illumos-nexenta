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
# NFSv4 SETATTR operation test - positive tests
#	verify setattr with valid stateid and owner

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# First create a temp file and get its open_sid and filehandle
set TFILE "$TNAME.[pid]"
set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $owner]
if {$cid == -1} {
        putmsg stderr 0 "$TNAME: setup - getclientid"
        putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
        exit $UNRESOLVED
}

set fsize 8192
set nfh [basic_open $bfh $TFILE 1 "$cid $owner" open_sid oseqid status \
        1 0 664 $fsize]
if {$nfh == -1} {
        putmsg stderr 0 "$TNAME: setup basic_open"
        putmsg stderr 0 "\t Test UNRESOLVED: status=($status)"
        exit $UNRESOLVED
}

# Start testing
# --------------------------------------------------------------
# a: Setattr size to truncate the file, expect OK
set expcode "OK"
set ASSERTION "Setattr size to truncate the file, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set nsize 511
set res [compound {Putfh $nfh; Getattr time_modify;
	Setattr $open_sid {{size $nsize}}; Getattr {size time_modify}}]
if {[ckres "Setattr" $status $expcode $res $FAIL] == "true"} {
    set rsize [extract_attr [lindex [lindex $res 3] 2] "size"]
    if {"$rsize" != "$nsize"} {
	putmsg stderr 0 "\t Test FAIL: Incorrect filesize after truncation"
	putmsg stderr 0 "\t            expected=($nsize), got=($rsize)"
	putmsg stderr 1 "\t  res=($res)"
    } else {
	# verify time_modify attribute is updated after SETATTR
        set oldtime [extract_attr [lindex [lindex $res 1] 2] "time_modify"]
        set newtime [extract_attr [lindex [lindex $res 3] 2] "time_modify"]
	if {"$oldtime" == "$newtime"} {
	    putmsg stderr 0 "\t Test FAIL: same time_modify after truncation"
	    putmsg stderr 0 "\t            expected=($newtime), got=($oldtime)"
	    putmsg stderr 1 "\t  res=($res)"
	} else {
	    logres "PASS"
	}
    }
}

# e: Setattr owner to original owner of the file, expect OK
set expcode "OK"
set ASSERTION "Setattr owner to original owner of the file, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Getattr owner}]
set fowner [extract_attr [lindex [lindex $res 1] 2] "owner"]
set res [compound {Putfh $nfh; Setattr $open_sid {{owner $fowner}}; 
	Getattr {owner filehandle}}]
if {[ckres "Setattr" $status $expcode $res $FAIL] == "true"} {
    set rowner [extract_attr [lindex [lindex $res 2] 2] "owner"]
    set rfh [extract_attr [lindex [lindex $res 2] 2] "filehandle"]
    if {"$rowner" != "$fowner"} {
	putmsg stderr 0 "\t Test FAIL: Incorrect new-owner after SETATTR"
	putmsg stderr 0 "\t            expected=($fowner), got=($rowner)"
	putmsg stderr 1 "\t  res=($res)"
    } else {
	if {"$nfh" != "$rfh"} {
	    putmsg stderr 0 "\t Test FAIL: Incorrect FH after SETATTR"
	    putmsg stderr 0 "\t            expected=($nfh), got=($rfh)"
	    putmsg stderr 1 "\t  res=($res)"
	} else {
	    logres "PASS"
	}
    }
}

# f: Setattr group to original owner_group of the file, expect OK
set expcode "OK"
set ASSERTION "Setattr group to original file owner_group, expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Getattr owner_group}]
set fgroup [extract_attr [lindex [lindex $res 1] 2] "owner_group"]
set res [compound {Putfh $nfh; Setattr $open_sid {{owner_group $fgroup}}; 
	Getattr {owner_group filehandle}}]
if {[ckres "Setattr" $status $expcode $res $FAIL] == "true"} {
    set rgroup [extract_attr [lindex [lindex $res 2] 2] "owner_group"]
    set rfh [extract_attr [lindex [lindex $res 2] 2] "filehandle"]
    if {"$rgroup" != "$fgroup"} {
	putmsg stderr 0 "\t Test FAIL: Incorrect new-group after SETATTR"
	putmsg stderr 0 "\t            expected=($fgroup), got=($rgroup)"
	putmsg stderr 1 "\t  res=($res)"
    } else {
	if {"$nfh" != "$rfh"} {
	    putmsg stderr 0 "\t Test FAIL: Incorrect FH after SETATTR"
	    putmsg stderr 0 "\t            expected=($nfh), got=($rfh)"
	    putmsg stderr 1 "\t  res=($res)"
	} else {
	    logres "PASS"
	}
    }
}

# --------------------------------------------------------------
# Final cleanup
# remove the created tmp file
set res [compound {Putfh $bfh; Remove $TFILE}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
