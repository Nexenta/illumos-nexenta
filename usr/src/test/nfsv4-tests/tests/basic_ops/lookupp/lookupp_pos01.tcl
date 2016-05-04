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
# NFSv4 LOOKUPP operation test - positive tests

# include all test enironment
source LOOKUPP.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: basic lookupp from a dir-fh, expect OK
set expcode "OK"
set ASSERTION "Lookupp from a dir under BASEDIR, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Lookupp; Getfh}]
set cont [ckres "Lookupp" $status $expcode $res $FAIL]
# verify filehandle from LOOKUPP is the correct one
set nfh [lindex [lindex $res 3] 2]
set cont [verf_fh [lindex [lindex $res 3] 2] $cont $FAIL]
fh_equal $nfh $bfh $cont $PASS


# b: lookupp to go up few levels, expect OK
set expcode "OK"
set ASSERTION "Lookupp to go up couple levels, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set ldfh [get_fh "$BASEDIRS [path2comp "$env(LONGDIR)" $DELM]"]
set res [compound {Putfh $ldfh; Lookupp; Lookupp; Lookupp; Getfh}]
set cont [ckres "Lookupp" $status $expcode $res $FAIL]
# verify filehandle from LOOKUPP should be good
verf_fh [lindex [lindex $res 4] 2] $cont $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
