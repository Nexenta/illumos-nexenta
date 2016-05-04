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
# NFSv4 SETATTR operation test - negative tests
#	verify SERVER errors returned with invalid Setattr op.

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Setattr without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Setattr without Putrootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Setattr {0 0} {{mode 0777}}}]
ckres "Setattr" $status $expcode $res $PASS

# c: Setattr ctime on an obj w/no permission, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Setattr ctime on an obj w/no permission, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM);
	Setattr {0 0} {{time_modify_set 0}}}]
ckres "Setattr" $status $expcode $res $PASS

# i: Setattr hidden on Solaris, expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Setattr hidden on Solaris, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    set res [compound {Putfh $bfh; Lookup $env(RWFILE);
	Setattr {0 0} {{hidden false}}}]
    ckres "Setattr" $status $expcode $res $PASS
} else {
	putmsg stdout 0 "\t Test UNTESTED: <hidden> attr may be  supported"
}

# j: Setattr system on Solaris, expect ATTRNOTSUPP
set expcode "ATTRNOTSUPP"
set ASSERTION "Setattr system on Solaris, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    set res [compound {Putfh $bfh; Lookup $env(RWFILE);
	Setattr {0 0} {{system false}}}]
    ckres "Setattr" $status $expcode $res $PASS
} else {
	putmsg stdout 0 "\t Test UNTESTED: <system> attr may be  supported"
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
