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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 WRITE operation test - negative tests
#	verify SERVER errors returned with invalid write.

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# It is assumed the special test filesystem, such public, rofs, nospc
# are setup correct in server for testing.
#
# Start testing
# --------------------------------------------------------------
# a: Try to write on the public-rootfh - expect ISDIR
#
set expcode "ISDIR"
set ASSERTION "Try to write on the public-rootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh [path2comp $env(PUBTDIR) $DELM]]
set stateid {0 0}
set res [compound {Putfh $tfh; Write $stateid 0 u a "Write test neg03 \{a\}"}]
ckres "Write" $status $expcode $res $PASS


# b: Try to write a file in ROFS - expect ROFS
#
set expcode "ROFS"
set ASSERTION "Try to write a file in ROFS, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh [path2comp $env(ROFSDIR) $DELM]]
set stateid {0 0}
set res [compound {Putfh $tfh; Lookup $env(RWFILE);
	Write $stateid 0 u a "Write test neg03 \{b\}"}]
ckres "Write" $status $expcode $res $PASS


# c: Try to write a file in NOSPC - expect NOSPC
#
set expcode "NOSPC"
set ASSERTION "Try to write a file in NOSPC, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh "[path2comp $env(NSPCDIR) $DELM] $env(RWFILE)"]
set res [compound {Putfh $tfh; Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
set stateid {0 0}
set data [string repeat "Neg3-C........ " 1024]
set res [compound {Putfh $tfh;
	Write $stateid $fsize f a $data; Commit 0 0}]
ckres "Write" $status $expcode $res $PASS


# d: Try to write a file over QUOTA limit - expect DQUOT
set expcode "DQUOT"
set ASSERTION "Try to write a file over DQUOT, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set qpath [path2comp $env(QUOTADIR) $DELM]
set res [compound {Putrootfh; foreach c $qpath {Lookup $c}; 
	Getfh; Lookup "quotas"}]
# add check of quota setup for Solaris:
if {($env(SRVOS) == "Solaris") && ($status == "NOENT")} {
	putmsg stdout 0 "\t Test NOTINUSE: QUOTA is not setup in server."
} else {
	set qfh [lindex [lindex $res end-1] 2]
	set tf "file_$env(TUSER2).2"
	set stateid {0 0}
	set data [string repeat "D" 1025]
	if {[is_cipso $env(SERVER)]} {
		set res [exec zlogin $env(ZONENAME) \
			"su $env(TUSER2) -c \"qfh=$qfh; tf=$tf; \
				data=$data; export qfh tf data; \
				/nfsh /$TNAME\""]
		set status [lindex $res 0]
	} else {
		set res [compound {Putfh $qfh; Lookup $tf;
			Write $stateid 1 f a $data}]
	}
	ckres "Write" $status $expcode $res $PASS
}

# The following tests need clientid to Open the files
putmsg stdout 0 " ** Now try to get the clientid to open the test files;"
putmsg stdout 0 "    If fails, the following assertions {m,n,x} will not run."
set hid "[pid][clock seconds]"
set cid [getclientid $hid]
if {$cid == -1} {
        putmsg stdout 0 "$TNAME: test setup - getclientid"
        putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
        putmsg stderr 0 "\t   program exit."
        exit $UNRESOLVED
}

# m: Try to Write when file is opened READ only - expect OPENMODE
#
set expcode "OPENMODE"
set ASSERTION "Try to Write when file is opened READ only, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set oowner "[pid][expr [clock seconds] / 2]"
set nfh [basic_open $bfh $env(RWFILE) 0 "$cid $oowner" \
	osid oseqid status 1 0 666 0 1]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: OPEN(rd) failed, status=$status."
} else {
	# Now try to write to this file:
	set data [string repeat "M" 511]
	set res [compound {Putfh $nfh; Write $osid 0 f a $data}]
	ckres "Write" $status $expcode $res $PASS
	incr oseqid
	set res [compound {Putfh $nfh; Close $oseqid $osid}]
	putmsg stderr 1 "Close res=$res"
}


# n: Try to Write when file is downgraded to READ only - expect OPENMODE
#
set expcode "OPENMODE"
set ASSERTION "Try to Write when file is downgraded READ only, expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
set oowner "[pid][expr [clock seconds] + 4]"
set nfh [basic_open $bfh $env(RWFILE) 0 "$cid $oowner" \
	osid oseqid status 1 0 666 0 3]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: OPEN(rw) failed, status=$status."
} else {
	# Now try to write to this file:
	incr oseqid
	set res [compound {Putfh $nfh; Open_downgrade $osid $oseqid 1 0}]
	if {$status != "OK"} {
	    putmsg stderr 0 \
		"\t Test UNRESOLVED: Open_downgrade failed status=$status."
	    putmsg stderr 1 "\t   Res=$res"
	} else {
	    set osid [lindex [lindex $res 1] 2]
	    set data [string repeat "M" 511]
	    set res [compound {Putfh $nfh; Write $osid 0 f a $data}]
	    ckres "Write" $status $expcode $res $PASS
	    incr oseqid
	    set res [compound {Putfh $nfh; Close $oseqid $osid}]
	    putmsg stderr 1 "Close res=$res"
	}
}

# x: Write a file when lease expired - expect EXPIRED|STALE_STATEID
#
set expcode "EXPIRED|STALE_STATEID"
set ASSERTION "Write a file when lease expired, expect $expcode"
set tag "$TNAME{x}"
putmsg stdout 0 "$tag: $ASSERTION"
set leasetm $LEASE_TIME

# open a file to get the stateid
set owner "$TNAME.[pid]-a"
set cid_owner "$cid $owner"
set newF "$TNAME.[pid]"
set nfh [basic_open $bfh $newF 1 $cid_owner osid oseqid status]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=$status."
} else {
	putmsg stdout 1 "  wait for lease time to expire, then write"
	after [expr ($leasetm + 18) * 1000]
	set data [string repeat "a" 513]
	set res [compound {Putfh $nfh; Write $osid 0 f a $data; Getfh}]
	ckres "Write" $status $expcode $res $PASS
}


# --------------------------------------------------------------
# Cleanup the temp file:
set res [compound {Putfh $bfh; Remove $newF}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove $newF failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res)"
        putmsg stderr 1 "  "
        exit $WARNING
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
