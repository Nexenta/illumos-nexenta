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
# {a}: Test get attr FATTR4_SUPPORTED_ATTRS attributes, expect OK"
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

# Start testing
# ---------------------------------------------------------------
# a: Test get attr FATTR4_SUPPORTED_ATTRS attributes, expect OK"

set ASSERTION "Test get attr FATTR4_SUPPORTED_ATTRS attributes, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

set attrs {supported_attrs}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attrs }]
set fh [lindex [lindex $res 2] 2]
prn_attrs [lindex [lindex $res 3] 2]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

# Create supported_attr list
set alist [lindex [lindex $res 3] 2]
foreach attrval $alist {
        set val [lindex $attrval 1]
        set list [split $val]
        putmsg stdout 1 "val on alist is $val"
        putmsg stdout 1 "split list is $list"
}

# Setup mandatory attributes list
set mand_attrs {supported_attrs type fh_expire_type change size link_support \
	symlink_support named_attr fsid unique_handles lease_time \
	rdattr_error filehandle} 

# Verify mandatory attrs are in supported_attr list
set foundmatch 0
set mandnum [llength $mand_attrs]
set errlist ""
foreach attrname $mand_attrs {
        if { [ lsearch -exact $list $attrname ] < 0 } {
                set errlist "$errlist $attrname"
        } else {
                incr foundmatch
        }
}
if { "$errlist" != "" } {
        putmsg stderr 0 "\t Test FAIL: Attributes ($errlist) not found in supported_list"
	break
} else {
        if { $foundmatch == $mandnum } {
              	putmsg stdout 0 "\t Test PASS"
        } else {
		putmsg stderr 0 "\t Test FAIL: all mandatory attributes not in list."
		break
	}
}

}

puts ""

Disconnect 
exit 0 
