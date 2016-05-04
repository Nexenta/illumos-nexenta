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
# {a}:Test get attr FATTR4_CHOWN_RESTRICTED of a filesystem object, expect OK
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
# a:Test get attr FATTR4_CHOWN_RESTRICTED of a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set ASSERTION "Test get attr FATTR4_CHOWN_RESTRICTED of a filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

set expval $env(CHOWN_RESTRICTED)

set attr {chown_restricted}

# Generate a compound request that
# obtains the attributes for the path.
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] "chown_restricted" ]

if { ![string equal $cont "false"] } {

# Verify attr value response from server
if {[string equal $expval $attrval]} {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stdout 0 "\t Test PASS"
} else {
	putmsg stderr 1 "\t chown_restricted is not supported"
        putmsg stderr 0 "\t Test FAIL: $expval and $attrval attr values not equa
l"
}

}

Disconnect 
exit $PASS 
