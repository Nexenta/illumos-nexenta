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
# a: Test get attr FATTR4_NUMLINKS of a file object, expect OK 
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
# a: Test get attr FATTR4_NUMLINKS of a file object, expect OK

set ASSERTION "Test get attr FATTR4_NUMLINKS of a file object, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {numlinks}

#Get the filehandle of the test file 
set res [compound {
	Putfh $bfh;
	Lookup $env(TEXTFILE);
	Getfh;
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

# Get expected numlinks of file
file stat $MNTPTR${delm}$env(TEXTFILE) stat1
set expval [expr $stat1(nlink)]

set fh [lindex [lindex $res 2] 2]

# Get numlinks attribute value
set lnk_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]

if {[string compare $expval $lnk_attr] == 0} {
	prn_attrs [lindex [lindex $res 3] 2]
	putmsg stdout 0 "\t Test PASS" 	
} else {
	putmsg stderr 0 "\t expected numlinks = $expval returned"
	putmsg stderr 0 "\t Test FAIL: unexpected numlinks attr value returned" 
}

}

Disconnect 
exit $PASS
