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
# 	- network partition

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


# b: Open and READ a test file w/good clientid, expect OK
set expcode "OK"
set ASSERTION "Open and READ a test file w/good clientid, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set oseqid 1
set TFILE "$TNAME.[pid]-b"
set fs 8192
set open_owner $TFILE
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 "$cid $open_owner" \
		{1 0 {{mode 0664} {size 0}}} {0 $TFILE}; Getfh}]
if { $status == "OK" } {
	set osid [lindex [lindex $res 1] 2]
	set nfh [lindex [lindex $res 2] 2]
	set rflags [lindex [lindex $res 1] 4]
	putmsg stderr 1 "osid=($osid), rflags=($rflags), nfh=($nfh)"
	global OPEN4_RESULT_CONFIRM
	# do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
		incr oseqid
		set res [compound {Putfh $nfh; Open_confirm $osid $oseqid}]
		if {$status != "OK"} {
			putmsg stderr 0 \
			 "\t Test FAIL: Open_confirm failed, status=($status)"
			putmsg stderr 0 "\t\t program exiting, and ..."
			putmsg stderr 0 \
			 "\t\t   the following assertions (c,d,e) will not run."
			putmsg stderr 1 "\t    Res=($res)"
			exit $FAIL
		}
		set osid [lindex [lindex $res 1] 2]
	}
	set res [compound {Putfh $nfh; Setattr $osid {{size $fs}}; 
		Read "$osid" 1024 2}]
	ckres "Read" $status $expcode $res $PASS
	incr oseqid
} else {
	putmsg stderr 0 "\t Test FAIL: Open failed, status=($status)"
	putmsg stderr 0 "\t\t program exiting, and ..."
	putmsg stderr 0 "\t\t   the following assertions (c,d,e) will not run."
	putmsg stderr 1 "\t    Res=($res)"
	exit $FAIL
}

putmsg stdout 0 \
  "  ** Now wait for lease($leasetm) to expire, then do the following (c,d,e):"
exec sleep [expr $leasetm + 12]

# c: Now try to WRITE the test file w/osid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Now try to WRITE the test file w/osid, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set data [string repeat "C" 128]
set res [compound {Putfh $nfh; Write "$osid" 512 f a $data}]
ckres "Write" $status $expcode $res $PASS


# d: Try to LOCK the test file w/cid+osid, expect EXPIRED|BAD_STATEID
set expcode "EXPIRED|BAD_STATEID"
set ASSERTION "Try to LOCK the test file w/cid+osid, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set lseqid 1
set res [compound {Putfh $nfh; 
	Lock 1 F 0 10 T $osid $lseqid "$oseqid $cid $open_owner"}]
ckres "Lock" $status $expcode $res $PASS

  
# e: Try LOCKT the test file w/cid, expect STALE_CLIENTID
set expcode "STALE_CLIENTID"
set ASSERTION "Try LOCKT the test file w/cid, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
#set lseqid 1
#set res [compound {Putfh $nfh; Lockt 2 $cid "lock_owner" 0 22}]
#ckres "Lockt" $status $expcode $res $PASS
putmsg stdout 0 "\t Test UNSUPPORTED: invalid in Solaris"
putmsg stdout 1 "\t   This assertion is based on the variability of"
putmsg stdout 1 "\t   interpretation for the server implementation."
  

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
