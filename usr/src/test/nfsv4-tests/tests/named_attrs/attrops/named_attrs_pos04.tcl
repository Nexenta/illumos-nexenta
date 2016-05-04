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
# NFSv4 named attributes:
#
# a: Test Getattr returns a fh type NF4NAMEDATTR of file in attrdir directory,
#    expect OK
# b: Test Getattr returns a fh type NF4ATTRDIR for attrdir, expect OK
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
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Start testing
# ------------------------------------------------------------------------
# a: Test Getattr returns a fh type NF4NAMEDATTR of file attrdir directory, expect OK

set ASSERTION "Test Getattr returns a fh type NF4NAMEDATTR for file w/named attrs, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Check for NF4NAMEDATTR filehandle type
set attr {type}

# Do the lookup on the attrdir file
set res [compound { Putfh $bfh; Lookup $env(ATTRDIR); Openattr f; Lookup $env(ATTRDIR_AT1); Getattr $attr}] 
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

set attrcomp [ extract_attr [lindex [lindex $res 4] 2] "type" ]
# Verify filehandle type expected
set expval "namedattr"
#Get the filehandle of the test file

if { [string equal $expval $attrcomp] } {
	putmsg stdout 1 "res=<$res>"
	putmsg stdout 0 "\t Test PASS"
} else {
	prn_attrs [lindex [lindex $res 4] 2]
	putmsg stderr 0 "\t Test FAIL: bad expected filehandle type, $expval"
}

}

# ----------------------------------------------------------------------
# b: Test Getattr returns a fh type NF4ATTRDIR for attrdir, expect OK

set ASSERTION "Test Getattr returns a fh type NF4ATTRDIR for attrdir, expect OK"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Check for NF4NAMEDATTR filehandle type
set attr {type}

# Do the lookup on the attrdir file
set res [compound { Putfh $bfh; Lookup $env(ATTRDIR); Openattr f; Getattr $attr}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

# Verify filehandle type expected
set attrcomp [ extract_attr [lindex [lindex $res 3] 2] "type" ]
set expval "attrdir"

if { [string equal $expval $attrcomp] } {
	putmsg stdout 1 "res=<$res>"
	putmsg stdout 0 "\t Test PASS"
} else {
	prn_attrs [lindex [lindex $res 3] 2]
        putmsg stderr 0 "\t Test FAIL: bad expected filehandle type, $expval"
}

}


Disconnect 
exit 0
