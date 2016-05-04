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
# NFSv4 Numbered Attributes:
# a: Test get attr FATTR4_FILEHANDLE of file object, expect OK	
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
set cookie 0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a: Test get attr FATTR4_FILEHANDLE of file object, expect OK 

set ASSERTION "Test get attr FATTR4_FILEHANDLE of file object, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Setup attribute to be tested
set attr {filehandle}

#Get the filehandle of the path 
set res [compound {
	Putfh $bfh
	Lookup $env(TEXTFILE)
	Getfh;
}]
ckres "Getfh" $status $expcode $res $FAIL
set fh [lindex [lindex $res 2] 2]

puts "fh is $fh"

#Get the filehandle attribute
set res [compound {
        Putfh $bfh
        Getfh;
	Lookup $env(TEXTFILE)
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

puts "Attributes After Readdir and Getattr: "
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] "filehandle" ]

if { ![string equal $cont "false"] } {
	if { ![string equal $fh $fh_attr ] } { 
		putmsg stderr 0 "\t Test FAIL: filehandle is invalid"
	} else {
		if { ![ string equal $fh_attr "" ] } {
			prn_attrs [lindex [lindex $res 3] 2]
			putmsg stdout 0 "\t Test PASS"
		} else {
			putmsg stderr 0 "\t Test FAIL: empty filehandle attr returned"
		}
	}
}

Disconnect

exit 0
