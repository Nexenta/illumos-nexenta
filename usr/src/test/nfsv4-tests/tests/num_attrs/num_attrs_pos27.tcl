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
# NFSv4 numbered attributes:
#
# a: Test get attr FATTR4_SPACE_AVAIL which should be small limit, expect OK
# b: Test get attr FATTR4_SPACE_FREE which should be small limit, expect OK
# c: Test get attr FATTR4_SPACE_TOTAL on the filesystem, expect OK
# d: Test get attr FATTR4_SPACE_USED on the filesystem, expect OK
#

set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set expcode "OK"
# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a:Test get attr FATTR4_SPACE_AVAIL which should be small limit, expect OK

set ASSERTION "Test get attr FATTR4_SPACE_AVAIL which should be small limit, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {space_avail}

#Get the filehandle of the test file 
set res [compound {
	Putfh $bfh;
	Lookup $env(TEXTFILE);
	Getfh;
	Getattr $attr
}]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]
ckres "Getattr" $status $expcode $res $PASS

# ---------------------------------------------------------------
# b:Test get attr FATTR4_SPACE_FREE which should be small limit, expect OK

set ASSERTION "Test get attr FATTR4_SPACE_FREE which should be small limit, exp
ect OK"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {space_free}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]
ckres "Getattr" $status $expcode $res $PASS

# ---------------------------------------------------------------
# c:Test get attr FATTR4_SPACE_TOTAL on the filesystem, expect OK

set ASSERTION "Test get attr FATTR4_SPACE_TOTAL on the filesystem, expect OK"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {space_total}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]
ckres "Getattr" $status $expcode $res $PASS

# ---------------------------------------------------------------
# d:Test get attr FATTR4_SPACE_USED on the filesystem, expect OK

set ASSERTION "Test get attr FATTR4_SPACE_USED on the filesystem, expect OK"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {space_used}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]
ckres "Getattr" $status $expcode $res $PASS

Disconnect 
exit $PASS
