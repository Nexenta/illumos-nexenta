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
# {a}:Test get attr FATTR4_UNIQUE HANDLES of a file object, expect OK
# {b}:Test get attr FATTR4_UNIQUE HANDLES of a dir object, expect OK
#

# Get the TESTROOT directory; set to '.' if not defined
set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

#
# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag $TNAME{setup}
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Start testing 
# -----------------------------------------------------------------
# a:Test get attr FATTR4_UNIQUE_HANDLES of a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set ASSERTION \
	"Test get attr FATTR4_UNIQUE_HANDLES of a file object, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"

# Hard coded expected value to be returned from the server
set expval "false"

set attrs {unique_handles}
set res [compound { Putfh $bfh; Lookup $env(EXECFILE); Getfh; Getattr $attrs }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if {[string equal $cont "true"] == 1} {
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "unique_handles" ]
	if { [string compare $attrval $expval] == 0 } {
		prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
		putmsg stderr 1 "unique_handles = $attrval"
		putmsg stderr 1 "res=($res)"
		putmsg stderr 0 "\t Test FAIL"
	}
}


puts ""

Disconnect 
exit $PASS 
