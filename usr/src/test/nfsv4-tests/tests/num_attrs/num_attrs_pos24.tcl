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
# a: Test get attr FATTR4_OWNER stringname of a file, expect OK 
# b: Test get/set attr FATTR4_OWNER_GROUP stringname of file, expect OK
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
set filename "newfile.[pid]"
set bfh [get_fh "$BASEDIRS"]
set tfile "[creatv4_file "$BASEDIR/$filename" 777]"

# Start testing
# ---------------------------------------------------------------
# a: Test get attr FATTR4_OWNER of a file object, expect OK

set ASSERTION "Test get attr FATTR4_OWNER of a file object, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {owner}
#Get the filehandle of the test file 
set res [compound {
	Putfh $bfh;
	Lookup $filename;
	Getfh;
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

# Get the Getattr value returned by op
set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]

# Extract the owner name string returned from Getattr
set newstr [ lindex $attrval 0 ]
putmsg stdout 1 "newstr is $newstr"
set strindex [string first @ $newstr]
if {$strindex == -1} {
	set getattr_str $newstr
} else {
	set getattr_str [string range $newstr 0 [expr $strindex-1]]
}
putmsg stdout 1 "strindex is $strindex"

# Get the TCL command unix version of the file owner
set attrs [file attributes $MNTPTR${delm}$filename]
set expval [lindex $attrs 3]

# Compare these strings
if {[string equal $expval $getattr_str]} {
	prn_attrs [lindex [lindex $res 3] 2]
	putmsg stdout 0 "\t Test PASS"
} else {
	putmsg stderr 0 "\t Test FAIL"
	putmsg stderr 0 "\t   Getattr val($getattr_str) != expval($expval)"
}

}

# ---------------------------------------------------------------
# b: Test get attr FATTR4_OWNER_GROUP of a file object, expect OK

set ASSERTION "Test get attr FATTR4_OWNER_GROUP of a file object, expect OK"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Setup testfile for attribute purposes
set attr {owner_group}
#Get the filehandle of the test file
set res [compound {
        Putfh $bfh;
        Lookup $filename;
        Getfh;
        Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

# Get the Getattr value returned by op
set attrval [ extract_attr [lindex [lindex $res 3] 2] $attr ]

# Extract the owner name string returned from Getattr
set newstr [ lindex $attrval 0 ]
putmsg stdout 1 "newstr is $newstr"
set strindex [string first @ $newstr]
if {$strindex == -1} {
	set getattr_str $newstr
} else {
	set getattr_str [string range $newstr 0 [expr $strindex-1]]
}
putmsg stdout 1 "strindex is $strindex"

# Get the TCL command unix version of the file owner_group
set attrs [file attributes $MNTPTR${delm}$filename]
set expval [lindex $attrs 1]

# Compare these strings
if {[string equal $getattr_str $expval]} {
        prn_attrs [lindex [lindex $res 3] 2]
        putmsg stdout 0 "\t Test PASS"
} else {
        putmsg stderr 0 "\t Test FAIL"
	putmsg stderr 0 "\t   Getattr val($getattr_str) != expval($expval)"
}

}

# Final cleanup
# --------------------------------------------------------------
# Final cleanup
# - remove the created dir
set res [compound {Putfh $bfh; Remove $filename;}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}


Disconnect 
exit $PASS
