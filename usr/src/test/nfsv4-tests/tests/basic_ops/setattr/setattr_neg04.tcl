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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 SETATTR operation test - negative tests
# 	Test NOSPC/DQUOT, need special FSs support

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set owner "owner-Sattr"

# Start testing
# --------------------------------------------------------------
# a: Setattr size when FS has no more quota, expect DQUOT
set expcode "DQUOT"
set ASSERTION "Setattr while FS has no more quota, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set qpath [path2comp $env(QUOTADIR) $DELM]
set res [compound {Putrootfh; foreach c $qpath {Lookup $c}; 
	Getfh; Lookup "quotas"}]
# add check of quota setup for Solaris:
if {($env(SRVOS) == "Solaris") && ($status == "NOENT")} {
	putmsg stdout 0 "\t Test NOTINUSE: QUOTA is not setup in server."
} else {
	set qfh [lindex [lindex $res end-1] 2]
	set tf "file_$env(TUSER2).1"
	# set size to 16 (as whole number of diskblocks)
	set fsize [expr 1024 * 16]
	if {[is_cipso $env(SERVER)]} {
		set ret [exec zlogin $env(ZONENAME) \
			"su $env(TUSER2) -c \"qfh=$qfh; tf=$tf; owner=$owner; \
				fsize=$fsize; export qfh tf owner fsize; \
				 /nfsh /$TNAME\""]
		puts $ret

		# get clientid for assertion{b} below 
		set cid [getclientid $owner]
                if {$cid == -1} {
                        putmsg stdout 0 "$TNAME: test setup - getclientid"
                        putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
                        exit $UNRESOLVED
                }
	} else {
		set cid [getclientid $owner]
		if {$cid == -1} {
			putmsg stdout 0 "$TNAME: test setup - getclientid"
			putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
			exit $UNRESOLVED
		}
		set cid_owner "$cid $owner"
		set nfh [basic_open $qfh $tf 0 $cid_owner open_sid oseqid status]
		if {$nfh == -1} {
			putmsg stderr 0 \
		   		"\t Test UNRESOLVED: basic_open failed, status=$status"
		} else {
			set res [compound {Putfh $nfh; Setattr $open_sid {{size $fsize}}}]
			ckres "Setattr" $status $expcode $res $PASS
			incr oseqid
			compound {Putfh $nfh; Close $oseqid $open_sid}
		}
	}
}


# b: Setattr bigger size when FS has no more disk space, expect NOSPC
set expcode "NOSPC"
set ASSERTION "Setattr bigger size on a file in NoSPC_FS, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
# Open the tmp file
set bfh [get_fh "[path2comp $env(NSPCDIR) $DELM]"]
set cid_owner "$cid $owner-b"
set tf "$env(RWFILE)"
set nfh [basic_open $bfh $tf 0 $cid_owner open_sid oseqid status]
if {$nfh == -1} {
	putmsg stderr 0 "\t Test UNRESOLVED: basic_open failed, status=$status"
} else {
	# set size to 16 (as whole number of diskblocks)
	set fsize [expr 1024 * 16]
    	set res [compound {Putfh $nfh; Setattr $open_sid {{size $fsize}}}]
	ckres "Setattr" $status $expcode $res $PASS
	incr oseqid
	compound {Putfh $nfh; Close $oseqid $open_sid}
}


# c: Setattr time_access_set when FS is READONLY, expect ROFS
set expcode "ROFS"
set ASSERTION "Setattr time_access_set w/target FS READONLY, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh "[path2comp $env(ROFSDIR) $DELM] $env(RWFILE)"]
if {$tfh == ""} {
	putmsg stdout 0 "\t Test UNTESTED: ROFS is not setup."
} else {
	set stateid {0 0}
	set ntime "[clock seconds] 0"
	set res [compound {Putfh $tfh; 
		Setattr $stateid {{time_access_set {$ntime}}}; 
		Getattr time_access}]
	ckres "Setattr" $status $expcode $res $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
