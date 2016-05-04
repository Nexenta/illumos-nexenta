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
# NFSv4 WRITE operation test - positive tests
#	verify writing to a file without Open using different offset/count

# include all test enironment
source WRITE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Create a temp file (size 0) for writing
set newF "WRfile.[pid]"
set tffh [creatv4_file [file join $BASEDIR $newF] 0666 0]
if { $tffh == $NULL } {
	putmsg stdout 0 "$TNAME: test setup - createv4_file"
	putmsg stderr 0 "\t UNINITIATED: unable to create tmp file, $newF"
	putmsg stderr 1 "  "
	exit $UNINITIATED
}


# Start testing
# --------------------------------------------------------------
# a: Write 1023 bytes ascii without Open, offset=0 - expect OK
set expcode "OK"
set ASSERTION "Write 1023 bytes ascii without Open, offset=0, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 1023
set data [string repeat "a" $count]
set stateid {0 0}
set res [compound {Putfh $tffh; Write $stateid 0 f a $data; Getfh}]
set cont [ckres "Write" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    set wcnt [lindex [lindex [lindex $res 1] 2] 0]
    if {$wcnt != $count} {
	putmsg stderr 0 \
	    "\t Test FAIL: Write returned count=($wcnt), expected=($count)"
	putmsg stderr 1 "\t   res=($res)"
	set cont false
    }
}
# verify FH is not changed after successful Write op
    set nfh [lindex [lindex $res 2] 2]
    fh_equal $tffh $nfh $cont $PASS


# b: Write 0 byte ascii without Open, offset=1 - expect OK
set expcode "OK"
set ASSERTION "Write byte ascii without Open, offset=1, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set count 0
set stateid {0 0}
set res [compound {Putfh $tffh; Write $stateid 1 f a ""; Getfh}]
set cont [ckres "Write" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    set wcnt [lindex [lindex [lindex $res 1] 2] 0]
    if {$wcnt != $count} {
	putmsg stderr 0 \
	    "\t Test FAIL: Write returned count=($wcnt), expected=($count)"
	putmsg stderr 1 "\t   res=($res)"
	set cont false
    }
}
# verify FH is not changed after successful Write op
    set nfh [lindex [lindex $res 2] 2]
    fh_equal $tffh $nfh $cont $PASS



# c: Write 1025 bytes ascii without Open, offset=fsize - expect OK
set expcode "OK"
set ASSERTION "Write 1025B ascii without Open, offset=fsize, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
# get the size of the file
set res [compound {Putfh $tffh; Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
set count 1025
set data [string repeat "c" $count]
set stateid {0 0}
set res [compound {Putfh $tffh; Write $stateid $fsize u a $data; 
	Getfh; Commit $fsize $count; Getattr size}]
set cont [ckres "Write" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    set wcnt [lindex [lindex [lindex $res 1] 2] 0]
    if {$wcnt != $count} {
	putmsg stderr 0 \
	    "\t Test FAIL: Write returned count=($wcnt), expected=($count)"
	putmsg stderr 1 "\t   res=($res)"
	set cont false
    } else {
	set nfsz [lindex [lindex [lindex [lindex $res 4] 2] 0] 1]
	set expsz [expr $fsize + $count]
	if {$nfsz != $expsz} {
	    putmsg stderr 0 \
	    "\t Test FAIL: Write/Commit had fsize=($nfsz), expected=($expsz)"
	    putmsg stderr 1 "\t   res=($res)"
	    set cont false
	}
    }
}
# verify FH is not changed after successful Write op
    set nfh [lindex [lindex $res 2] 2]
    fh_equal $tffh $nfh $cont $PASS


# d: Write 1024 bytes ascii without Open, offset>fsize - expect OK
set expcode "OK"
set ASSERTION "Write 1024B ascii without Open, offset>fsize, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
# get the size of the file
set res [compound {Putfh $tffh; Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
set offset [expr $fsize + 2]
set count 1024
set data [string repeat "d" $count]
set stateid {0 0}
set res [compound {Putfh $tffh; Write $stateid $offset u a $data; 
	Getfh; Commit $fsize $count; Getattr size}]
set cont [ckres "Write" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
    set wcnt [lindex [lindex [lindex $res 1] 2] 0]
    if {$wcnt != $count} {
	putmsg stderr 0 \
	    "\t Test FAIL: Write returned count=($wcnt), expected=($count)"
	putmsg stderr 1 "\t   res=($res)"
	set cont false
    } else {
	set nfsz [lindex [lindex [lindex [lindex $res 4] 2] 0] 1]
	set expsz [expr $offset + $count]
	if {$nfsz != $expsz} {
	    putmsg stderr 0 \
	    "\t Test FAIL: Write/Commit had fsize=($nfsz), expected=($expsz)"
	    putmsg stderr 1 "\t   res=($res)"
	    set cont false
	}
    }
}
# verify FH is not changed after successful Write op
    set nfh [lindex [lindex $res 2] 2]
    fh_equal $tffh $nfh $cont $PASS


# e: Write skipping 3 bytes without Open, offset>fsize - expect OK
set expcode "OK"
set ASSERTION "Write skipping 3B without Open, offset>fsize, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
# get the size of the file
set res [compound {Putfh $tffh; Getattr size}]
set fsize [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
set off [expr $fsize + 1]
set off 16
set data "EEE"
set stateid {0 0} 
set res [compound {Putfh $tffh; Setattr $stateid {{size $off}};
	for {set i $off} {$i <= [expr $off + 188]} {set i [expr $i + 16]} \
		{Write $stateid $i f a $data}; 
		Read {0 0} [expr $off + 16] 3; Getfh}]
set cont [ckres "Write" $status $expcode $res $FAIL]
if {! [string equal $cont "false"]} {
	# verify data read back
	set ndata [lindex [lindex [lindex $res end-1] 2] 2]
	if {! [string equal $data $ndata]} {
	    putmsg stderr 0 \
	    	"\t Test FAIL: data read back does not match w/data written"
	    putmsg stderr 0 \
		"\t   server returned ndata=($ndata), expected=($data)"
	    putmsg stderr 1 "\t   res=($res)"
	    set cont false
	}
}
# verify FH is not changed after successful Write op
    set nfh [lindex [lindex $res end] 2]
    fh_equal $tffh $nfh $cont $PASS

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

# disconnect and exit
Disconnect
exit $PASS
