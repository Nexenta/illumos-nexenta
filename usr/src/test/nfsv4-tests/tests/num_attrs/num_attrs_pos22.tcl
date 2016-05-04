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
# a: Test get attr FATTR4_NO_TRUNC in NFSv4 on UFS, expect OK 
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
# a:Test get attr FATTR4_NO_TRUNC in NFSv4 on UFS, expect OK 

set ASSERTION "Test get attr FATTR4_NO_TRUNC in NFSv4 on UFS, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Get expected server value
set expval $env(NO_TRUNC) 

# Setup attr for testing purposes
set attr {no_trunc}

#Get the filehandle of the test file 
set res2 [compound {
	Putfh $bfh;
	Lookup $env(TEXTFILE);
	Getfh;
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res2 $FAIL]

if { ![string equal $cont "false"] } {

set fh [lindex [lindex $res2 2] 2]
set attrval [ extract_attr [lindex [lindex $res2 3] 2] $attr ]

if { [string compare $attrval $expval] == 0} {
	prn_attrs [lindex [lindex $res2 3] 2]
	putmsg stdout 0 "\t Test PASS"
} else {
	prn_attrs [lindex [lindex $res2 3] 2]
	putmsg stderr 0 "\t Test FAIL"
}

}

puts ""

Disconnect 
exit $PASS
