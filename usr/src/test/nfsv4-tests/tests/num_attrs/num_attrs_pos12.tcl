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
# Test NFSv4 numbered attributes: 
#
# {a}:Test get attr FATTR4_CASE_PRESERVING of a filesystem object, expect OK
#

# Get the TESTROOT directory; set to '.' if not defined
set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Start testing 
# ------------------------------------------------------------------
# a:Test get attr FATTR4_CASE_PRESERVING of a file object, expect OK

set ASSERTION "Test get attr FATTR4_CASE_PRESERVING of a filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Generate a compound request that
# obtains the attributes for the path.
set attr {case_preserving}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] "case_preserving" ]
prn_attrs [lindex [lindex $res 3] 2] 

if { ![string equal $cont "false"] } {
	if {[string compare $attrval "true"] == 0} {
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 0 "\t Test FAIL: case_preserving is not supported"
	}
}

Disconnect 
exit $PASS 
