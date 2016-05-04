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
# a: Test OPENATTR access of attr directory, expect OK
# b: Test LOOKUPP of attribute directory, expect OK
# c: Test READDIR of attribute directory, expect OK
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

# Create a new file for testing purposes
set filename "newfile.[pid]"
set tfile "[creatv4_file "$BASEDIR${delm}$filename" 777]"
if { [string equal $tfile ""] } {
	set ASSERTION "Test setup, expect OK"
	putmsg stdout 0 "$TNAME{all}: $ASSERTION"
	putmsg stdout 0 "\tTest FAIL: failed to create file $BASEDIR${delm}$filename on server"
	exit $UNINITIATED
}

# Start testing
# ----------------------------------------------------------
# a: Test OPENATTR access of attr directory, expect OK

set ASSERTION "Test OPENATTR access of attr directory, expect OK"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

set res [compound {Putfh $bfh; Lookup $filename; Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
set createdir "T"
# Create the named attr of newfile  
set res2 [compound { Putfh $bfh; Lookup $filename; Getfh; Openattr $createdir }]
set fh [lindex [lindex $res2 2] 2]
ckres "Openattr" $status $expcode $res2 $PASS

}

# ----------------------------------------------------------
# b: Test LOOKUPP of attribute directory, expect OK

set ASSERTION "Test LOOKUPP of attribute directory, expect OK"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

set res [compound {Putfh $bfh; Lookup $filename; Getfh}]
set cont [ckres "Lookup" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
set createdir "T"
# Create the named attr of newfile
set res2 [compound { Putfh $bfh; Lookup $filename; Openattr $createdir; Lookupp; Getfh }]
set cont [ckres "Lookupp" $status $expcode $res2 $FAIL]
# verify filehandle from LOOKUPP is the correct one
set nfh [lindex [lindex $res2 4] 2]
set cont [verf_fh [lindex [lindex $res2 4] 2] $cont $PASS]

}

# ----------------------------------------------------------------
# c: Test READDIR of attribute directory, expect OK

set ASSERTION "Test READDIR of attribute directory, expect OK"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"

set cookie 0

set res2 [compound { 
	Putfh $bfh
	Lookup $filename
	Openattr $createdir
	Getfh
	Readdir $cookie 0 1024 1024 { size type time_modify}
	Getfh } ]
set cont [ckres "Readdir" $status $expcode $res2 $FAIL]

# verify FH is not changed after successful Readdir after Openattr 
set fh1 [lindex [lindex $res 3] 2]
set fh2 [lindex [lindex $res 5] 2]
fh_equal $fh1 $fh2 $cont $PASS

# --------------------------------------------------------------
# Cleanup the temp file:
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
