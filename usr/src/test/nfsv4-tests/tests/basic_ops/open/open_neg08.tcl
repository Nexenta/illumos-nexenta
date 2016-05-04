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
# NFSv4 OPEN operation test - negative tests
#	Verify server returns correct errors with not-support attributes

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set oseqid 1
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open(create/UNCHECK) w/readonly attr , expect INVAL
set expcode "INVAL"
set ASSERTION "Open(create/UNCHECK) w/readonly attribute , expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set tmpFa "$tag"
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid ${owner}-a" \
	{1 0 {{time_modify_set "1034718056 0"} {type reg}}} {0 $tmpFa}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# b: Open(create/GUARDED) w/readonly attr , expect INVAL
set expcode "INVAL"
set ASSERTION "Open(create/GUARDED) w/readonly attribute , expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set tmpFb "$tag"
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid ${owner}-b" \
	{1 1 {{named_attr "false"} {mode 0666}}} {0 $tmpFb}; Getfh}]
ckres "Open" $status $expcode $res $PASS


# m: Open(create/UNCHECKED) w/not-supported attr , expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Open(create/UNCHECKED) w/unsupported attr, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
# Check 'system' is not in supported_attr
set nsattr "system"
set res [compound {Putfh $bfh; Getattr supported_attrs}]
if {[lsearch -exact [lindex [lindex [lindex $res 1] 2] 1] $nsattr] >= 0} {
    putmsg stdout 0 "\t Test NOTINUSE: attr($nsattr) is in supported_attrs list"
} else {
    set tmpFm "$tag"
    set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid ${owner}-m" \
	{1 0 {{$nsattr "false"} {mode 0666}}} {0 $tmpFm}; Getfh}]
    set cont [ckres "Open" $status $expcode $res $FAIL]
    if {! [string equal $cont "false"]} {
	# Verify $tmpFm is not created
	set res [compound {Putfh $bfh; Lookup $tmpFm}]
	if {$status != "NOENT"} {
            putmsg stderr 0 "\t Test FAIL: ndir=($tmpFm) created unexpectedly"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	} else {
	   logres PASS
	}
    }
}


# n: Open(create/GUARDED) w/not-supported attr , expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Open(create/GUARDED) w/unsupported attr, expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
# Check 'hidden' is not in supported_attr
set nsattr "hidden"
set res [compound {Putfh $bfh; Getattr supported_attrs}]
if {[lsearch -exact [lindex [lindex [lindex $res 1] 2] 1] $nsattr] >= 0} {
    putmsg stdout 0 "\t Test NOTINUSE: attr($nsattr) is in supported_attrs list"
} else {
    set tmpFn "$tag"
    set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid ${owner}-m" \
	{1 0 {{$nsattr "false"} {mode 0666}}} {0 $tmpFn}; Getfh}]
    set cont [ckres "Open" $status $expcode $res $FAIL]
    if {! [string equal $cont "false"]} {
	# Verify $tmpFn is not created
	set res [compound {Putfh $bfh; Lookup $tmpFn}]
	if {$status != "NOENT"} {
            putmsg stderr 0 "\t Test FAIL: ndir=($tmpFn) created unexpectedly"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	} else {
	   logres PASS
	}
    }
}
# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
