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
# - testing successful creation of other file types, such SOCK and FIFO

# include all test enironment
source CREATE.env

# connect to the test server
Connect


# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: create a new sock file, expect OK
set expcode "OK"
set nsock "newsock.[pid]"
set ASSERTION "Create a new sock file, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nsock {{mode 0666}} s;
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# verify filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a sock
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "sock" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (sock)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# b: create a new fifo file, expect OK
set expcode "OK"
set nfifo "newfifo.[pid]"
set ASSERTION "Create a new fifo file, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $nfifo {{mode 0666}} f; 
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Now verify - filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a fifo
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "fifo" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (fifo)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created dir
set res [compound {Putfh $bfh; Remove $nsock; Remove $nfifo; }]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
}

# disconnect and exit
Disconnect
exit $PASS
