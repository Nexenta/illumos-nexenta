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
# a: Test get attr FATTR4_LINK_SUPPORT of hardlinks of a filesystem,
#    expect OK	
# b: Test get attr FATTR4_SYMLINK_SUPPORT of a filesystem, expect OK
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
# -----------------------------------------------------------------
# a: Test get attr FATTR4_LINK_SUPPORT of hardlinks of a filesystem,
# expect OK

# Generate a compound request that
# obtains the attributes for the path.

set ASSERTION "Test get attr FATTR4_LINK_SUPPORT of hardlinks of a filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

# Get the expected value for link support on server filesystem
set errfile [file join $::env(TMPDIR) ck_fattr.err]
set expval [ exec ck_fattr $MNTPTR link 2> $errfile]
if {[file size $errfile] > 0} {
	if {[catch {open $errfile r} fileid] != 0} {
		putmsg stdout 0 "[read $fileid]"
		close $fileid
	}
}
catch {file delete $errfile} dummy

set attr1 {link_support}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr1 }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
set fh [lindex [lindex $res 2] 2]
set attrval [ extract_attr [lindex [lindex $res 3] 2] "link_support" ]

if { ![string equal $cont "false"] } {
	if {[string compare $attrval $expval] == 0} {
		prn_attrs [lindex [lindex $res 3] 2]
		putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stdout 0 "\t Test FAIL: hardlink_support attr returned, $attrval"
	}
}
puts ""

#--------------------------------------------------------------------
# b: Test get attr FATTR4_SYMLINK_SUPPORT of a filesystem, expect OK

# Generate a compound request that
# obtains the attributes for the path.

set ASSERTION "Test get attr FATTR4_SYMLINK_SUPPORT of a filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

# Get the expected value for link support on server filesystem
set errfile [file join $::env(TMPDIR) ck_fattr.err]
set expval [ exec ck_fattr $MNTPTR symlink 2> $errfile]
if {[file size $errfile] > 0} {
	if {[catch {open $errfile r} fileid] != 0} {
		putmsg stdout 0 "[read $fileid]"
		close $fileid
	}
}
catch {file delete $errfile} dummy

set attr2 {symlink_support}
set res2 [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr2 }]
set cont [ckres "Getattr" $status $expcode $res2 $FAIL]

if { ![string equal $cont "false"] } {
set fh [lindex [lindex $res2 2] 2]
set attrval [ extract_attr [lindex [lindex $res2 3] 2] "symlink_support" ]
	if {[string compare $attrval $expval] == 0} {
		prn_attrs [lindex [lindex $res2 3] 2]
        	putmsg stdout 0 "\t Test PASS"
	} else {
        	putmsg stdout 0 "\t Test FAIL: symlink_support attr returned $attrval"
	}
}

Disconnect 
exit $PASS 
