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
# UFS(UNIX Filesystem) 
# a: Test set attr FATTR4_FS_LOCATIONS in NFSv4 UFS, expect FAIL
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
set expcode "ATTRNOTSUPP"

# Get testfile pathname
set filename "newfile.[pid]"
set tfile "[creatv4_file "$BASEDIR/$filename" 777]"

# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a:Test set attr FATTR4_FS_LOCATIONS in NFSv4 UFS, expect $expcode" 

set ASSERTION "Test set attr FATTR4_FS_LOCATIONS, expect $expcode"
putmsg stdout 0 "$TNAME{a}:$ASSERTION"

set sid {0 0}

# Get a list of the supported attributes
set attr {fs_locations}
set attrval {"$SERVER:$MNTPTR"}
#set res [compound { Putfh $bfh
#	Lookup $filename
#	Getfh
#	Setattr $sid {{fs_locations {$attrval}}} }]
#ckres "Setattr" $status $expcode $res $PASS 

puts ""

set res [compound {Putfh $bfh; Remove $filename}]
#if {$status != "OK"} {
#    puts "ERROR, compound{} return status=$status"
#    exit 1
#}
putmsg stderr 0 "\tTest UNTESTED"


Disconnect 
exit $PASS
