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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
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
# a: OPENATTR w/create on a regular file - expect OK
set expcode "OK"
set ASSERTION "OPENATTR w/create on a regular file, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Openattr T; Getattr type}]
if {[ckres "Openattr" $status $expcode $res $FAIL] == "true"} {
    # verify the type of new <cfh> is attrdir
    set attr [extract_attr [lindex [lindex $res 3] 2] "type"]
    if {$attr != "attrdir"} {
	putmsg stderr 0 \
	    "\t Test FAIL: Openattr(T) got type=($attr), expected=(attrdir)"
	putmsg stderr 1 "\t res=($res)"
    } else {
	logres PASS
    }
}


# b: OPENATTR w/create on a symlinked directory
#	Solaris server doesn't support this.
#
set ASSERTION "OPENATTR w/create on a symlinked directory, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Openattr T; Getattr type}]
if { "$env(SRVOS)" == "Solaris" } {
    set expcode "NOTSUPP"
    ckres "Openattr" $status $expcode $res $PASS
} else {
    set expcode "OK"
    if {[ckres "Openattr" $status $expcode $res $FAIL] == "true"} {
	# verify the type of new <cfh> is attrdir
	set attr [extract_attr [lindex [lindex $res 3] 2] "type"]
	if {$attr != "attrdir"} {
	    putmsg stderr 0 \
		"\t Test FAIL: Openattr(T) got type=($attr), expected=(attrdir)"
	    putmsg stderr 1 "\t res=($res)"
	} else {
	    logres PASS
	}
    }
}


# c: OPENATTR none-create on a file w/attrdir exists - expect OK
set expcode "OK"
set ASSERTION "OPENATTR none-create on a file w/attrdir exists, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE); Openattr F; 
	Getattr type; Lookup $env(ATTRFILE_AT1); Getattr type}]
if {[ckres "Openattr" $status $expcode $res $FAIL] == "true"} {
    # verify the type of new <cfh> is attrdir
    set attrd [extract_attr [lindex [lindex $res 3] 2] "type"]
    set attrf [extract_attr [lindex [lindex $res 5] 2] "type"]
    if {$attrd != "attrdir"} {
	putmsg stderr 0 \
	    "\t Test FAIL: Openattr(F) got type=($attr), expected=(attrdir)"
	putmsg stderr 1 "\t res=($res)"
    } else {
        if {$attrf != "namedattr"} {
		putmsg stderr 0 \
		    "\t Test FAIL: unexpected attr type in attrdir"
		putmsg stderr 0 "got=($attr), expected=(namedattr)"
		putmsg stderr 1 "\t res=($res)"
	} else {
	    logres PASS
	}
    }
}


# d: OPENATTR(T) on a noperm_dir wattrdir readable - expect ACCESS
set expcode "ACCESS"
set ASSERTION "OPENATTR(T) on a noperm_dir w/attrdir readable, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATDIR_NP); 
	Openattr T; Getattr type; Lookup $env(ATTRDIR_AT1); Getattr type}]
ckres "Openattr" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
