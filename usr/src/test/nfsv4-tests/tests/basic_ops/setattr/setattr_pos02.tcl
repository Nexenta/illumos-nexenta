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
# NFSv4 SETATTR operation test - positive tests
#	verify setattr to with different FSs.

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0

# Start testing
# --------------------------------------------------------------
# a: Setattr mode when FS has no more quota, expect OK
set expcode "OK"
set ASSERTION "Setattr mode while FS has no more quota, expect $expcode"
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
	set stateid {0 0}
	set tf "file_$env(TUSER2).2"
	set mode 751
	if {[is_cipso $env(SERVER)]} {
		set res [exec zlogin $env(ZONENAME) \
			"su $env(TUSER2) -c \"qfh=$qfh; tf=$tf; \
				mode=$mode; export qfh tf mode; /nfsh /$TNAME\""]
		set nmd [lindex [lindex [lindex [lindex $res 4] 2] 0] 1]
		set status [lindex $res 0]
	} else {
		set res [compound {Putfh $qfh; Lookup $tf;
			Setattr $stateid {{mode $mode}}; Getattr mode}]
		set nmd [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
	}

	if {[ckres "Setattr" $status $expcode $res $FAIL] == "true"} {
		if {"$nmd" != "$mode"} {
			putmsg stderr 0 "\t Test FAIL: unexpected value from GETATTR."
			putmsg stderr 1 "\t    res=($res)."
		} else {
			logres PASS
		}
	}
}


# b: Setattr time_access when FS has no more inode, expect OK
set expcode "OK"
set ASSERTION "Setattr time_access while FS has no more inode, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set tfh [get_fh "[path2comp $env(NSPCDIR) $DELM] $env(RWFILE)"]
set stateid {0 0}
set ntime "[clock seconds] 0"
set res [compound {Putfh $tfh; 
	Setattr $stateid {{time_access_set {$ntime}}}; Getattr time_access}]
if {[ckres "Setattr" $status $expcode $res $FAIL] == "true"} {
    set aval [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
    if {"$aval" != "$ntime"} {
	putmsg stderr 0 "\t Test FAIL: unexpected value from GETATTR."
	putmsg stderr 1 "\t    res=($res)."
    } else {
	logres PASS
    }
}


# e: Setattr less size when FS has no more disk space, expect OK
set expcode "OK"
set ASSERTION "Setattr less size w/FS has no more disk space, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
# Open the tmp file
set bfh [get_fh "[path2comp $env(NSPCDIR) $DELM]"]
set id "[pid]"
set clientid [getclientid $id]
set oseqid 1
set otype 0
set res [compound {Putfh $bfh; 
	Open $oseqid 3 0 {$clientid $id} {$otype 0 0} {0 $env(RWFILE)}; 
	Getfh; Getattr size}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Open op failed unexpectedly"
	putmsg stderr 1 "\t    res=($res)."
} else {
    set open_sid [lindex [lindex $res 1] 2]
    set rflags [lindex [lindex $res 1] 4] 
    set nfh [lindex [lindex $res 2] 2]
    set osize [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    incr oseqid
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
    }
    set nsize [expr $osize - 16]
    set res [compound {Putfh $nfh; 
	Setattr $open_sid {{size $nsize}}}]
    ckres "Setattr" $status $expcode $res $PASS
    # restore the original size
    incr oseqid
    set res [compound {Putfh $nfh; 
	Setattr $open_sid {{size $osize}}}]
    incr oseqid
    compound {Putfh $nfh; Close $oseqid $open_sid}
}


# --------------------------------------------------------------
# Final cleanup
# disconnect and exit
Disconnect
exit $PASS
