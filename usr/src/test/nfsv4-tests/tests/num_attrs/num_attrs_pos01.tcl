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
# a: Test get attr FATTR4_TYPE of file object, expect OK
# b: Test get attr FATTR4_TYPE of directory object, expect OK
# c: Test  get attr FATTR4_TYPE of symlink object, expect OK
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
set expcode "OK"
# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]
set attr {type}

# Start testing
# ---------------------------------------------------------------
# a: Test get attr FATTR4_TYPE of file object, expect OK 

set ASSERTION "Test get attr FATTR4_TYPE of file object, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Get the expected file type on filesystem using TCL commands for UNIX 
set expval [file type "$MNTPTR${delm}$env(TEXTFILE)"] 

# Generate a compound request that
# obtains the attributes for the path.
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
set fh [lindex [lindex $res 2] 2]
set attrcomp [ extract_attr [lindex [lindex $res 3] 2] "type" ]

# Verify attr type value response from server
if { ![string equal $cont "false"] } {
	if {[string equal $expval "file"] && [string equal $attrcomp "reg"]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 1 "$BASEDIRS${delm}$env(TEXTFILE) is not a file"
        	putmsg stderr 0 "\t Test FAIL: wrong type attr"
	}
}
	
puts ""

#--------------------------------------------------------------------
# b: Test get attr FATTR4_TYPE of directory object, expect OK

set ASSERTION "get attr FATTR4_TYPE of directory object, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Get the expected file type on filesystem using TCL commands for UNIX 
set expval [file type "$MNTPTR${delm}$env(DIR0777)"] 

# Generate a compound request that
# obtains the attributes for the path.
set res [compound { Putfh $bfh; Lookup $env(DIR0777); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
set fh [lindex [lindex $res 2] 2]

set attrcomp [ extract_attr [lindex [lindex $res 3] 2] "type" ]

# Verify attr type value response from server
if { ![string equal $cont "false"] } {
	if {[string equal $expval "directory"] && [string equal $attrcomp "dir"]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 1 "\t $BASEDIRS${delm}$env(DIR0777) is not a dir"
        	putmsg stderr 0 "\t Test FAIL: wrong type attr"
	}
}

puts ""

#----------------------------------------------------------------
# c: Test  get attr FATTR4_TYPE of symlink object, expect OK

set ASSERTION "get attr FATTR4_TYPE of symlink object, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"

# Get the expected file type on filesystem using TCL commands for UNIX 
set expval [file type "$MNTPTR${delm}$env(SYMLFILE)"] 

# Generate a compound request that
# obtains the attributes for the path.
set res [compound { Putfh $bfh; Lookup $env(SYMLFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
set fh [lindex [lindex $res 2] 2]

set attrcomp [ extract_attr [lindex [lindex $res 3] 2] "type" ]

# Verify attr type value response from server
if { ![string equal $cont "false"] } {
	if {[string equal $expval "link"] && [string equal $attrcomp "lnk"]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 1 "\t $BASEDIRS${delm}$env(SYMLFILE) is not a symlink"
        	putmsg stderr 0 "\t Test FAIL: wrong type attr"
	}
}

puts ""

Disconnect 
exit $PASS 
