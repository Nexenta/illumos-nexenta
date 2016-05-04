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
# NFSv4 LINK operation test - negative tests
# 	test server to return MLINK error when links to a file
#	is more than numlinks.
# NOTE: this test takes long time to run, ~1 hour to complete
# 	due to the time in setup/cleanup maxlinks.

# include all test enironment
source LINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set ffh [get_fh "$BASEDIRS $env(TEXTFILE)"]


# Start testing
# --------------------------------------------------------------
# a: try Link when obj has maxlinks, expect MLINK
#    This test may take a while to run as it will try to maxlink an object
set expcode "MLINK"
set ASSERTION "try Link when obj has maxlinks, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
# create a tmp dir for links 
set tmpd "tmp.[pid]"
set res [compound {Putfh $bfh; Create $tmpd {{mode 0711}} d; Getfh}]
set tdfh [lindex [lindex $res 2] 2]
set maxl [set_maxlink $ffh $tdfh]
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link "mlinkh"}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS
set cont [cleanup_links $maxl $tdfh $cont]


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
