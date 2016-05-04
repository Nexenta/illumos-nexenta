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
# NFSv4 CREATE operation test - negative tests
#	Test attributes with Create op.

# include all test enironment
source CREATE.env

# connect to the test server
Connect


# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Create a dir w/unsupported attr, expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Create a dir w/unsupported attr, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
# Check 'hidden' is not in supported_attr
set nsattr "hidden"
set res [compound {Putfh $bfh; Getattr supported_attrs}]
if {[lsearch -exact [lindex [lindex [lindex $res 1] 2] 1] $nsattr] >= 0} {
    putmsg stdout 0 "\t Test NOTINUSE: attr($nsattr) is in supported_attrs list"
} else {
    set ndir "ndir_a.[pid]"
    set res [compound {Putfh $bfh;
	Create "$ndir" {{mode 0751} {$nsattr "false"}} d}]
    set cont [ckres "Create" $status $expcode $res $FAIL]
    if {! [string equal $cont "false"]} {
	# Verify ndir is not created
	set res [compound {Putfh $bfh; Lookup $ndir}]
	if {$status != "NOENT"} {
            putmsg stderr 0 "\t Test FAIL: ndir=($ndir) created unexpectedly"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	} else {
	   logres PASS
	}
    }
}


# b: Create a fifo file w/a readonly attr, expect INVAL
set expcode "INVAL"
set ASSERTION "Create a fifo file w/readoly attribute, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set nfifo "nfifo_b.[pid]"
set res [compound {Putfh $bfh; Create $nfifo {{type "dir"}} f; Getfh}]
set cont [ckres "Create" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    # Verify $ndir is not created
    set res [compound {Putfh $bfh; Lookup $ndir}]
    if { $status != "NOENT" } {
	putmsg stderr 0 "\t Test FAIL: fifo($nfifo) is created w/CREATE failed"
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
