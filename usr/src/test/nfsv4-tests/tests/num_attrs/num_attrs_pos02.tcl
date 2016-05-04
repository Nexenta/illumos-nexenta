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
# NFSv4 Numbered Attributes test.
#
# a:Test get attr 2 fh_expire_type returns FH4_PERSISTENT, expect OK
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
# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a:Test get attr 2 fh_expire_type returns FH4_PERSISTENT, expect OK

set expcode "OK"
set fh4_persistent 0
set attr {fh_expire_type}
set ASSERTION "get attr FATTR4_FH_EXPIRE_TYPE returns FH4_PERSISTENT, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

set attrval [ extract_attr [lindex [lindex $res 3] 2] "fh_expire_type" ]
 
if { ![string equal $cont "false"] } {
	if {[string compare "$attrval" "$fh4_persistent" ] == 0} {
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 0 "\t Test FAIL: fh_expire_type didn't return FH4_PERSISTENT"
	}
}

puts ""

Disconnect 
exit $PASS 
