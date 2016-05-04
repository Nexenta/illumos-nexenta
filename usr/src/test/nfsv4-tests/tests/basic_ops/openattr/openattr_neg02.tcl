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
# NFSv4 OPENATTR operation test - negative tests
#	verify SERVER errors returned under error conditions

# include all test enironment
source OPENATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Try to create dir under attrdir - expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Try to create dir under attrdir, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set newdir "ATTR-newdir"
set res [compound {Putfh $bfh; Lookup $env(ATTRFILE);
	Openattr F; Getfh; Create $newdir {{mode 0777}} d}]
if {[ckres "Openattr/Create" $status $expcode $res $FAIL] == "true"} {
    # verify the newdir is not created
    set ofh [lindex [lindex $res 3] 2]
    set res2 [compound {Putfh $ofh; Lookup $newdir}]
    if {$status != "NOENT"} {	
	putmsg stderr 0 "\t Test FAIL: directory($newdir) created under attrdir"
	putmsg stderr 1 "\t	res=($res)"
    } else {
	logres PASS
    }
}	


# b: Try to rename attr to the none attrdir - expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Try to rename attr to the none attrdir, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set newname "ATTR-newname"
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr F; Getfh;
	Savefh; Putfh $bfh; Rename $env(ATTRDIR_AT1) $newname}]
if {[ckres "Openattr/Rename" $status $expcode $res $FAIL] == "true"} {
    # verify the original name is still there
    set ofh [lindex [lindex $res 3] 2]
    set res2 [compound {Putfh $ofh; Lookup $env(ATTRDIR_AT1)}]
    if {$status == "NOENT"} {	
	putmsg stderr 0 "\t Test FAIL: attrfile was renamed under attrdir"
	putmsg stderr 1 "\t	res=($res)"
    } else {
	logres PASS
    }
}	



# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
