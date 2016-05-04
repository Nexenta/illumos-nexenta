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
# a: Test create attribute data in attrdir, expect OK
#

set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]

source WRITE_proc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set tag $TNAME{setup}
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Start testing
# ----------------------------------------------------------
# a: Test create attribute data in attrdir, expect OK

set ASSERTION "Test create attribute data in attrdir, expect OK"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"

# Create a new file for testing purposes
set filename "newfile.[pid]"
set tfile "[creatv4_file "$BASEDIR${delm}$filename" 777]"
set res [compound {Putfh $bfh; Lookup $filename; Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]

if {[string equal $cont "true"] == 1} {
	# Create the named attr of newfile  
	set createdir "T"
	set res2 [compound {Putfh $bfh; Lookup $filename; \
		Openattr $createdir; Getfh }]
	set nfh [lindex [lindex $res2 3] 2]
	set cont [ckres "Openattr" $status $expcode $res2 $FAIL]

	if {[string equal $cont "true"] == 1} {
		set count 8192
		ckwrite $nfh "attrfile" 0 $count $expcode $count $PASS
	}
}

# --------------------------------------------------------------
# Cleanup the temp file:
set tag $TNAME{cleanup}
set res [compound {Putfh $bfh; Remove $filename}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove $filename failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

Disconnect 
exit 0
