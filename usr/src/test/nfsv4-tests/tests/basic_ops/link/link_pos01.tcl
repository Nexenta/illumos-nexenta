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
# NFSv4 LINK operation test - positive tests

# include all test enironment
source LINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: basic Link to a file, expect OK
set expcode "OK"
set ASSERTION "Basic Link to a file, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set lnk1 "NewLink.[pid]"
set res [compound {Putfh $bfh; Lookup $env(TEXTFILE); Savefh;
	Putfh $bfh; Link $lnk1; Getfh}]
set cont [ckres "Link" $status $expcode $res $FAIL]
# Now verify CFH continue to be the target directory
  set nfh [lindex [lindex $res 5] 2]
  if { [fh_equal $bfh $nfh $cont $FAIL] } {
	logres PASS
  } else {
	putmsg stderr 0 "\t Test FAIL: new FH was not changed."
	putmsg stderr 1 "\t   nfh=($nfh)"
	putmsg stderr 1 "\t   bfh=($bfh)"
	putmsg stderr 1 "  "
  }


# b: Check property changes for the link file, expect OK
set expcode "OK"
set ASSERTION "Check property changes for the link file, expect $expcode"
set fifo "OrigFifo.[pid]"
set lnk2 "NewLink2.[pid]"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Create $fifo {{mode 0644}} f; Savefh;
	Putfh $bfh; Link $lnk2; Getfh}]
set cont [ckres "Link" $status $expcode $res $FAIL]
# Now verify the property change in fifo is reflected in link file
  if {! [string equal $cont "false"]} {
	set res [compound {Putfh $bfh; Lookup $fifo; 
		Setattr {0 0} {{mode 666}}; Putfh $bfh; Lookup $lnk2; 
		Getattr mode}]
	set mode [lindex [lindex [lindex [lindex $res 5] 2] 0] 1]
	if {$mode != "666" } {
	    putmsg stderr 0 "\t Test FAIL: new mode=($mode) is unexpected."
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	} else {
	    logres PASS
	}
  }


# c: Verify numlinks increased one after the Link, expect OK
set expcode "OK"
set ASSERTION "Verify numlinks increased one after the Link, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set lnk3 "NewLink3.[pid]"
set res [compound {Putfh $bfh; Lookup $env(ROFILE); Getattr numlinks; Savefh;
	Putfh $bfh; Link $lnk3; Lookup $env(ROFILE); Getattr numlinks}]
set cont [ckres "Link" $status $expcode $res $FAIL]
# Now verify the link count on the file is one greater
  if {! [string equal $cont "false"]} {
	set cnt1 [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
	set cnt2 [lindex [lindex [lindex [lindex $res 7] 2] 0] 1]
	if {[incr cnt1] != $cnt2 } {
	    putmsg stderr 0 "\t Test FAIL: new link count is incorrect."
	    putmsg stderr 1 "\t   cnt1=($cnt1)"
	    putmsg stderr 1 "\t   cnt2=($cnt2)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	} else {
	    logres PASS
	}
  }


# --------------------------------------------------------------
# Final cleanup:
#   remove the created temp link files
set res [compound {Putfh $bfh; Remove $lnk1; Remove $fifo; 
	Remove $lnk2; Remove $lnk3}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created links failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
