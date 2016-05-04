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
# a: Test get attr FATTR4_HIDDEN return false for UFS; return true for WIN32,
#    expect OK 
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
#a: Test get attr FATTR4_HIDDEN return false for UFS; return true for WIN32, expect OK

set ASSERTION "Test get attr FATTR4_HIDDEN return false for UFS; return true for WIN32, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Get a list of the supported attributes
set attr {supported_attrs}

# Generate a compound request that
# obtains the attributes for the path.
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

set fh [lindex [lindex $res 2] 2]
# Create supported_attr list
set alist [lindex [lindex $res 3] 2]
foreach attrval $alist {
        set val [lindex $attrval 1]
        set list [split $val]
        putmsg stdout 1 "val on alist is $val"
        putmsg stdout 1 "split list is $list"
}

# Setup testfile for attribute purposes
set attr {hidden}

#Get the filehandle of the test file 
set res [compound {
	Putfh $bfh;
	Lookup $env(TEXTFILE);
	Getfh;
	Getattr $attr
}]
set cont2 [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont2 "false"] } {

	# Verify attr not in supported_attr list
	if { [ lsearch -exact $list $attr ] < 0 } {
        	putmsg stdout 0 "\t Test PASS: $attr not in supported attr list"
	} else {
        	putmsg stdout 0 "\t Test FAIL: unexpected $attr in supported attr list"
	}

}

}

puts ""

Disconnect 
exit $PASS
