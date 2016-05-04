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
# NFSv4 CREATE operation test - positive tests
# - testing successful creation of symlinks.

# include all test enironment
source CREATE.env

# connect to the test server
Connect


# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: create a new link to file, expect OK
set expcode "OK"
set LFILE $env(ROFILE)
set nlnkf "newlnkf.[pid]"
set ASSERTION "Create a new link to a file, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nlnkf {{mode 0555}} l $LFILE;
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# verify filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a lnk
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "lnk" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (lnk)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# b: create a new link to dir, expect OK
set expcode "OK"
set DFILE $env(LONGDIR)
set nlnkd "newlnkd.[pid]"
set ASSERTION "Create a new link to longdir, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nlnkd {{mode 0751}} l $DFILE;
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Now verify - filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a lnk
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "lnk" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (lnk)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# c: create a new link to the link, expect OK
set expcode "OK"
set nlnkl "newlnkl.[pid]"
set ASSERTION "Create a new link to the link, expect $expcode"
set tag $TNAME{c}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nlnkl {{mode 0777}} l $nlnkd;
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Now verify - filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a lnk
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "lnk" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (lnk)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# d: create a new link to none-exist object, expect OK
set expcode "OK"
set nlnk2 "newlnkl2.[pid]"
set ASSERTION "Create a new link to none-exist object, expect $expcode"
set tag $TNAME{d}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nlnk2 {{mode 777}} l "no-such-obj";
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Now verify - filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a lnk
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "lnk" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (lnk)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}

# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created dir
set res [compound {Putfh $bfh; Remove $nlnkf;
	 Remove $nlnkd; Remove $nlnkl; Remove $nlnk2}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}


# disconnect and exit
Disconnect
exit $PASS
