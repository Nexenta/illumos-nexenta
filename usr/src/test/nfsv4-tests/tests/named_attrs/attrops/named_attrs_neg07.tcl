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
# NFSv4 OPEN with named attributes, negative tests

# include all test enironment
# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

# include common code and init environment
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# now set/confirm the clientid
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stderr 0 "Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set oseqid 1
set oowner $TNAME-oowner


# Start testing
# --------------------------------------------------------------
# a: Open(CREATE/Exclusiv) w/<cfh> is named_attr, expect INVAL
set expcode "INVAL"
set ASSERTION "Open(CREATE/Exclusiv) w/<cfh> is named_attr, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr f; Getfh}]
if { [ckres "Openattr" $status "OK" $res $FAIL] == "true" } {
    # get the named_attr filehandle, and tried to OPEN create/exclusive
    set nfh [lindex [lindex $res 3] 2]
    set createverf "$cid-a"
    set fname $TNAME-a.[pid]
    set res [compound {Putfh $nfh; 
	Open $oseqid 3 0 "$cid $oowner-a" \
		    {1 2 {$createverf}} {0 $fname}; Getfh}]
    if { [ckres "Open" $status $expcode $res $FAIL] == "true" } {
	# make sure file is not created due to error
	set res [compound {Putfh $nfh; Lookup $fname}]
	if {$status != "NOENT"} {
                putmsg stderr 0 \
                        "\t Test FAIL: OPEN failed, but ($fname) created?"
                putmsg stderr 1 "\t   res=($res)"
	} else {
		logres PASS
	}
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
