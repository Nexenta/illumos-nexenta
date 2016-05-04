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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 PUTPUBFH operation test - positive tests

# include all test enironment
source PUTPUBFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# For the PUTPUBFH positive tests, the SERVER must export a 
# PUBLIC filesystem.  So verify it here.
set res [compound {Putpubfh; Getfh}]
if { "$status" != "OK" } {
	putmsg stderr 0 "$TNAME: Test NOTINUSE"
	putmsg stderr 0 "\t SERVER=\[$SERVER\] does not seem to have public FS"
	putmsg stderr 1 "\t   res=($res)"
	exit $NOTINUSE
}

# Start testing
# --------------------------------------------------------------
# a: basic putpubfh - make sure gets a cfh, expect OK
set expcode "OK"
set ASSERTION "Putpubfh to set cfh, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putpubfh; Getfh; Readdir 0 0 1024 1240 type}]
set cont [ckres "Putpubfh" $status $expcode $res $FAIL]
# verify filehandle from PUTROOTFH should be good
set fh1 [lindex [lindex $res 1] 2]
set fh2 [get_fh [path2comp $env(PUBTDIR) $DELM]]
fh_equal $fh1 $fh2 $cont $PASS


# b: use putpubfh to go back to public root, expect OK
set expcode "OK"
set ASSERTION "Putpubfh to go back to public root, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
	Putpubfh; Lookup $env(DIR0777); Getfh}]
set cont [ckres "Putpubfh" $status $expcode $res $FAIL]
if {[string equal $cont "false"]} {
    # verify filehandle from PUTROOTFH are not the same as from PUTPUBFH
    set fh1 [lindex [lindex $res 2] 2]
    set fh2 [lindex [lindex $res 5] 2]
    set cont [fh_equal $fh1 $fh2 $cont $FAIL]
    if {[string equal $cont "false"]} {
	logres PASS
    } else {
	logres FAIL
	putmsg stderr 0 "\t    pub-fh is same as basedir-fh"
    }
} else {
	logres PASS
}


# c: putpubfh as cfh to later go back
set expcode "OK"
set ASSERTION "Putpubfh as cfh to later go back, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set tpath "[path2comp $env(LONGDIR) $DELM]"
set res [compound {Putpubfh; Getfh}]
set cont [ckres "Putpubfh" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    set fh1 [lindex [lindex $res 1] 2]
    set res [compound {Putpubfh; foreach c $tpath {Lookup $c}; 
		Putfh $fh1; Getfh}]
    set fh2 [lindex [lindex $res end] 2]
    fh_equal $fh1 $fh2 $cont $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
