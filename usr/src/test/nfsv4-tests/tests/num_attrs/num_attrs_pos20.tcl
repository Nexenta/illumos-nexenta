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
# Test NFSv4: 
# {a}: Test get attr FATTR4_MAXFILESIZE per filesystem, expect OK
# {b}: Test get attr FATTR4_MAXLINK for a file, expect OK
# {c}: Test get attr FATTR4_MAXLINK for a directory, expect OK
# {d}: Test get attr FATTR4_MAXNAME for a file, expect OK
# {e}: Test get attr FATTR4_MAXREAD of a file, expect OK
# {f}: Test get attr FATTR4_MAXWRITE of a file, expect OK
#

# Get the TESTROOT directory; set to '.' if not defined
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
# -----------------------------------------------------------------
# a: Test get attr FATTR4_MAXFILESIZE per filesystem, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{a}"
set ASSERTION "Test get attr FATTR4_MAXFILESIZE per filesystem, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

set attr {maxfilesize}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] "$attr" ]
prn_attrs [lindex [lindex $res 3] 2] 
ckres "Getattr" $status $expcode $res $PASS

# -----------------------------------------------------------------
# b: Test get attr FATTR4_MAXLINK for a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{b}"
set ASSERTION "Test get attr FATTR4_MAXLINK for a file object, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get expected server value
set expval [ exec getconf LINK_MAX $MNTPTR${delm}$env(TEXTFILE) ]
if { "$expval" == "undefined" } { 
	# If getconf returns "undefined", it's infinite in this filesystem.
	# However NFSv4 defines "maxlink" as an 32bit value; so we expect
	# the max value of 32bit
	set expval 4294967295
}
set attr {maxlink}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } { 
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "$attr" ]

	# Verify attr value response from server
	if {[string equal $expval $attrval]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 0 "\t Test FAIL: attr values not equal"
		putmsg stderr 0 "\t\texpval=<$expval>, attrval=<$attrval>"
		putmsg stderr 1 "\tRes: $res"
	}
}

# -----------------------------------------------------------------
# c: Test get attr FATTR4_MAXLINK for a dir object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{c}"
set ASSERTION "Test get attr FATTR4_MAXLINK for a dir object, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get expected value of maximum link support from the server
set expval [ exec getconf LINK_MAX $MNTPTR${delm}$env(DIR0777) ]
if { "$expval" == "undefined" } { 
	# If getconf returns "undefined", it's infinite in this filesystem.
	# However NFSv4 defines "maxlink" as an 32bit value; so we expect
	# the max value of 32bit
	set expval 4294967295
}

set attr {maxlink}
set res [compound { Putfh $bfh; Lookup $env(DIR0777); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "$attr" ]

	# Verify attr value response from server
	if {[string equal $expval $attrval]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 0 "\t Test FAIL: attr values not equal"
		putmsg stderr 0 "\t\texpval=<$expval>, attrval=<$attrval>"
		putmsg stderr 1 "\tRes: $res"
	}
}


# -----------------------------------------------------------------
# d: Test get attr FATTR4_MAXNAME size for a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{d}"
set ASSERTION "Test get attr FATTR4_MAXNAME for a file object, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get the expected value of maximum name size from server
set expval [ exec getconf NAME_MAX $MNTPTR${delm}$env(DIR0777) ]

set attr {maxname}

set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } { 
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "maxname" ]

	# Verify attr value response from server
	if {[string equal $expval $attrval]} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stderr 0 "\t Test FAIL: attr values not equal"
		putmsg stderr 0 "\t\texpval=<$expval>, attrval=<$attrval>"
		putmsg stderr 1 "\tRes: $res"
	}
}

# -----------------------------------------------------------------
# e: Test get attr FATTR4_MAXREAD size of a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{e}"
set ASSERTION "Test get attr FATTR4_MAXREAD of a file object, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get the expected value for MAXREAD support on server filesystem
set errfile [file join $::env(TMPDIR) ck_fattr.err]
set expval [ exec ck_fattr $MNTPTR rsize 2> $errfile]
if {[file size $errfile] > 0} {
	if {[catch {open $errfile r} fileid] != 0} {
		putmsg stdout 0 "[read $fileid]"
		close $fileid
	}
}
catch {file delete $errfile} dummy

set attr {maxread}

set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "$attr" ]

	if {[string compare $attrval $expval] == 0} {
        	prn_attrs [lindex [lindex $res 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
            putmsg stderr 0 "\t Test FAIL: maxread_support returned $attrval"
	    putmsg stderr 0 "\t expval is $expval"
	    putmsg stderr 1 "\tRes: $res"
	}
}

# -----------------------------------------------------------------
# f: Test get attr FATTR4_MAXWRITE size of a file object, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set tag "$TNAME{f}"
set ASSERTION "Test get attr FATTR4_MAXWRITE of a file object, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

# Get the expected value for MAXWRITE support on server filesystem
set errfile [file join $::env(TMPDIR) ck_fattr.err]
set expval [ exec ck_fattr $MNTPTR wsize 2> $errfile]
if {[file size $errfile] > 0} {
	if {[catch {open $errfile r} fileid] != 0} {
		putmsg stdout 0 "[read $fileid]"
		close $fileid
	}
}
catch {file delete $errfile} dummy

set attr {maxwrite}
set filename "newfile.[pid]"
set tfile "[creatv4_file "$BASEDIR/$filename" 777]"
set res [compound { Putfh $bfh; Lookup $filename; Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {  
	set attrval [ extract_attr [lindex [lindex $res 3] 2] "$attr" ]

	if {[string compare $attrval $expval] == 0} {
            prn_attrs [lindex [lindex $res 3] 2]
            putmsg stdout 0 "\t Test PASS"
	} else {
            putmsg stderr 0 "\t Test FAIL: maxread_support returned $attrval"
	    putmsg stderr 0 "\t expval is $expval"
	    putmsg stderr 1 "\tRes: $res"
	}
}

# cleanup
set res [compound { Putfh $bfh; Remove $filename}]

Disconnect 
exit $PASS 
