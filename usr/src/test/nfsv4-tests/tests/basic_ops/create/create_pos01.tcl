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
# NFSv4 CREATE operation test - positive tests
# - testing successful creation of directories.

# include all test enironment
source CREATE.env

# connect to the test server
Connect


# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: create a new dir, expect OK
set expcode "OK"
set ndir "newtd.[pid]"
set ASSERTION "Create a new dir under BASEDIR, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $ndir {{mode 0755}} d;
	Getfh; Getattr type}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# verify filehandle from CREATE should be good
set cont [verf_fh [lindex [lindex $res 2] 2] $cont $FAIL]
if {! [string equal $cont "false"]} {
    # check new type must be a dir
    set ntype [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    if { "$ntype" != "dir" } {
        putmsg stderr 0 "\t Test FAIL: got unexpected type ($ntype)."
	putmsg stderr 0 "\t              expected type is (dir)."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# b: create new dirs in several levels, expect OK
set expcode "OK"
set ASSERTION "Create new dirs in several levels, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set fh [get_fh "$BASEDIRS $ndir"]
foreach nd {nd2 nd3 nd4 nd5} {
	set res [compound {Putfh $fh; Create $nd {{mode 0775}} d; Getfh}]
	set cont [ckres "Create" $status $expcode $res $FAIL]
	if {! [string equal $cont "false"]} {
		set fh [lindex [lindex $res 2] 2]
	} else {
		break
	}
}
# verify filehandle from last CREATE should be same as new lookup
if {! [string equal $cont "false"]} {
    set nfh [get_fh "$BASEDIRS $ndir nd2 nd3 nd4 nd5"]
    fh_equal $fh $nfh $cont $PASS
}


# c: create new link under a new dir, expect OK
set expcode "OK"
set ndr2 "ndr2-[pid]"
set nln2 "ndr2-[pid]"
set ASSERTION "Create a new link under a new dir, expect $expcode"
set tag $TNAME{c}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create "$ndr2" {{mode 0755}} d; 
	  Getfh; Create "$nln2" {{mode 0644}} l "."; Getfh}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Verify CFH changed
if {! [string equal $cont "false"]} {
    set dfh [lindex [lindex $res 2] 2]
    set sfh [lindex [lindex $res 4] 2]
    if { [fh_equal $dfh $sfh $cont $FAIL] } {
        putmsg stderr 0 "\t Test FAIL: CFH wasn't changed after Create."
	putmsg stderr 1 "\t   dfh=($dfh)"
	putmsg stderr 1 "\t   sfh=($sfh)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# d: create a new dir with space in name, expect OK
set expcode "OK"
set sdir "special [pid] name"
set ASSERTION "Create a new dir with space in name, expect $expcode"
set tag $TNAME{d}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Getfh; Create "$sdir" {{mode 0711}} d; Getfh}]
set cont [ckres "Create" $status $expcode $res $FAIL]
# Verify CFH changed
if {! [string equal $cont "false"]} {
    set dfh [lindex [lindex $res 1] 2]
    set sfh [lindex [lindex $res 3] 2]
    if { [fh_equal $dfh $sfh $cont $FAIL] } {
        putmsg stderr 0 "\t Test FAIL: CFH wasn't changed after Create."
	putmsg stderr 1 "\t   dfh=($dfh)"
	putmsg stderr 1 "\t   sfh=($sfh)"
	putmsg stderr 1 "  "
    } else {
	logres PASS
    }
}


# e: create a new dir with special attrs, expect OK
set expcode "OK"
set atdir "mkdir_attr.[pid]"
set ASSERTION "Verify new dir created attributes, expect $expcode"
set tag $TNAME{e}
putmsg stdout 0 "$tag: $ASSERTION"
set time_mod "[expr [clock seconds] - 218] 0"
set mode 567
set cklist "mode time_modify"
set res [compound {Putfh $bfh;
	Create "$atdir" {{mode $mode} {time_modify_set {$time_mod}}} d; 
	Getattr {$cklist}; Getfh}]
set cont [ckres "Create" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    # Verify attributes set correctly
    set cattr [lindex [lindex [lindex $res 1] 2] 3]
    if {([lsearch -exact $cattr "mode"] < 0) && \
	([lsearch -exact $cattr "time_modify"] < 0)} {
        putmsg stderr 0 "\t Test FAIL: Create didn't return the set attrs."
	putmsg stderr 1 "\t   cattr=($cattr)"
	putmsg stderr 2 "\t   res=($res)"
	putmsg stderr 1 "  "
    } else {
	# Verify attributes set correctly
	set slist [lindex [lindex $res 2] 2]
	foreach a $cklist {
	    set nval [extract_attr $slist $a]
	    if {("$a" == "mode") && ($nval != $mode)} {
        	putmsg stderr 0 "\t Test FAIL: attrs($a) not set correctly."
		putmsg stderr 1 "\t   slist=($slist)"
		putmsg stderr 1 "  "
		break
	    } else {
		if {("$a" == "time_modify") && ("$nval" != "$time_mod")} {
        	    putmsg stderr 0 "\t Test FAIL: attrs($a) not set correctly."
		    putmsg stderr 1 "\t   slist=($slist)"
		    putmsg stderr 1 "  "
		    break
		}
	    }
	}
	logres PASS
    }
}


# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created dir
set res [compound {Putfh $nfh; Lookupp; Remove nd5; 
	Lookupp; Remove nd4; Lookupp; Remove nd3; Lookupp; Remove nd2;
	Lookupp; Remove $ndir;
	Lookup $ndr2; Remove $nln2; Putfh $bfh; Remove $ndr2;
	Putfh $bfh; Remove $sdir; Putfh $bfh; Remove $atdir}]
if { ("$status" != "OK") && ("$status" != "NOENT") } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}


# disconnect and exit
Disconnect
exit $PASS
