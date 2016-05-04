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
# NFSv4 server state recovery test - negative tests
#	- network partition

# include all test enironment
source LOCKsid.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Get server lease time
set leasetm $LEASE_TIME

# First, basic setup
putmsg stdout 0 \
  "\n  ** Frist basic setup for $TNAME, if fails, program will exit ..."

# Start testing
# --------------------------------------------------------------
# a: Setclientid/Setclient_confirm, expect OK
set expcode "OK"
set ASSERTION "Setclientid/Setclient_confirm, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set hid "[pid]-[expr int([expr [expr rand()] * 100000000])]"
set cid [getclientid $hid]
if {$cid == -1} {
	putmsg stderr 0 "Test FAIL: unable to get clientid"
	exit $FAIL
} else {
	logres PASS
}


# b: Open a test file w/good clientid, expect OK
set expcode "OK"
set ASSERTION "Open a test file w/good clientid, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set oseqid 1
set TFILE "$TNAME.[pid]-b"
set open_owner $TFILE
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid $open_owner" {1 0 {{mode 0644}}} {0 $TFILE};
	Putfh $bfh; Lookup $TFILE; Getfh}]
if { [ckres "Open" $status $expcode $res $PASS] == "true" } {
	set osid [lindex [lindex $res 1] 2]
	set nfh [lindex [lindex $res 4] 2]
	incr oseqid
} else {
	putmsg stderr 1 "\t\t Res=($res)"
	putmsg stderr 0 \
		"\t ... the following assertions (c,d,e) will not be run."
	exit $FAIL
}

putmsg stdout 0 \
  "  ** Now wait for lease($leasetm) to expire, then do the following (c,d,e):"
exec sleep [expr $leasetm + 12]

# c: Now try to READ the test file w/osid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Now try to READ the test file w/osid, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Read "$osid" 0 64}]
ckres "Read" $status $expcode $res $PASS


# d: Try to CLOSE the test file w/expired-osid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Try to CLOSE the test file w/expired-osid, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $nfh; Close $oseqid $osid}]
ckres "Close" $status $expcode $res $PASS

  
# e: OPEN the file again w/same cid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "OPEN the file again w/same cid, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid $open_owner" {0 0 {{mode 0644}}} {0 $TFILE}}]
ckres "Open2" $status $expcode $res $PASS

  
  
# --------------------------------------------------------------
# Now cleanup, and removed created tmp file
set res [compound {Putfh $bfh; Remove $TFILE}]
if {($status != "OK") && ($status != "NOENT")} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
