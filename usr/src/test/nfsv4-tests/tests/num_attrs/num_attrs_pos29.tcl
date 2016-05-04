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
# a: Test get attr FATTR4_TIME_ACCESS to get a time of a file, expect OK
# b: Test get attr FATTR4_TIME_DELTA of a file, expect OK
# c: Test get attr FATTR4_TIME_METADATA of a file, expect OK
# d: Test get attr FATTR4_TIME_MODIFY of a file, expect OK
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

set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a:Test get attr FATTR4_TIME_ACCESS of a file, expect OK

set ASSERTION "Test get attr FATTR4_TIME_ACCESS of a file, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Get expected last time access of a file  
file stat $MNTPTR${delm}$env(TEXTFILE) stat1
set expval [expr $stat1(atime)]

# Setup testfile for attribute purposes
set attr {time_access}

#Get the filehandle of the test file 
set res [compound {
	Putfh $bfh;
	Lookup $env(TEXTFILE);
	Getfh;
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]
set timeaccess [lindex $attrval 0]

if {[string equal $timeaccess $expval]} { 
	prn_attrs [lindex [lindex $res 3] 2]
	putmsg stdout 0 "\t Test PASS" 
} else {
	prn_attrs [lindex [lindex $res 3] 2]
	putmsg stderr 0 "\t Test FAIL"
}

}

# ---------------------------------------------------------------
# b:Test get attr FATTR4_TIME_DELTA of a file, expect OK

set ASSERTION "Test get attr FATTR4_TIME_DELTA of a file, expect OK"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {time_delta}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set fh_attr [ extract_attr [lindex [lindex $res 3] 2] $attr ]
ckres "Getattr" $status $expcode $res $PASS

# ---------------------------------------------------------------
# c:Test get attr FATTR4_TIME_METADATA of a file, expect OK

set ASSERTION "Test get attr FATTR4_TIME_METADATA of a file, expect OK"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"

# Get expected last time access of a file
file stat $MNTPTR${delm}$env(TEXTFILE) stat1
set expval [expr $stat1(ctime)]

# Setup testfile for attribute purposes
set attr {time_metadata}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]
set metadata [lindex $attrval 0]

if {[string equal $metadata $expval]} {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stdout 0 "\t Test PASS"
} else {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stderr 0 "\t Test FAIL"
}
}


# ---------------------------------------------------------------
# d:Test get attr FATTR4_TIME_MODIFY of a file, expect OK

set ASSERTION "Test get attr FATTR4_TIME_MODIFY of a file, expect OK"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"

# Get expected last time access of a file
file stat $MNTPTR${delm}$env(TEXTFILE) stat1
set expval [expr $stat1(mtime)]

# Setup testfile for attribute purposes
set attr {time_modify}

#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $env(TEXTFILE);
        Getfh;
        Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]
set modify_time [lindex $attrval 0]

if {[string equal $modify_time $expval]} {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stdout 0 "\t Test PASS"
} else {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stderr 0 "\t Test FAIL"
}
}


Disconnect 
exit $PASS
