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
# NFSv4 numbered attributes:
#
# a: Test set/get attr FATTR4_SIZE of file object, expect OK	
# b: Test set/get attr FATTR4_MODE of file object, expect OK
# c: Test set/get attr FATTR4_TIME_ACCESS_SET of last access to file object,
#    expect OK
# d: Test set/get attr FATTR4_TIME_MODIFY_SET of a file object, expect OK
# e: Test set/get attr FATTR4_SIZE of directory object, expect OK
#

set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"

# Start testing
# ----------------------------------------------------------
# a: Test set/get attr FATTR4_SIZE of file object, expect OK 

set ASSERTION "Test set/get attr FATTR4_SIZE of file object, expect OK"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

# Open file in creat mode to obtain stateid
global NULL env OPEN4_RESULT_CONFIRM

# set string id (this is unique for each exec to avoid problems
#       with the seqid).
set id_string \
	"[clock clicks] [expr int([expr [expr rand()] * 100000000])]]"

# negotiate clientid
set seqid 1
set clientid [getclientid $id_string]
if {$clientid < 0} {
	putmsg stderr 0 "getclientid failed."
	return $NULL
}

# try open with create on <pathdir>
set filename "newfile.[pid]"
set opentype    1
set createmode  0
set mode        664
set claim       0
incr seqid
set size        0
set res [compound {Putfh $bfh;
        Open $seqid 3 0 {$clientid $id_string} \
        {$opentype $createmode {{mode $mode} {size $size}}} \
        {$claim $filename}; Getfh}]
if {$status != "OK"} { 
	set cont "false"
        putmsg stderr 1 "\t    res=($res)."
	putmsg stdout 0 "\t Test UNRESOLVED: Open op failed unexpectedly, status=($status)"
} else {

#store all open info
set stateid [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4]
set nfh [lindex [lindex $res 2] 2]

# check open_confirm
if {[expr $rflags & $OPEN4_RESULT_CONFIRM] != 0} {
	incr seqid
	set res [compound {Putfh $nfh; Open_confirm $stateid $seqid}]
	putmsg stdout 1 $res
	if {$status != "OK"} {
		putmsg stderr 0 \
		"Can not open confirm $filename under $pathdir"
		return $NULL
	}
	set stateid [lindex [lindex $res 1] 2]
}


# Var for attributes for all tests below   
set attrs {size mode owner time_access time_modify}

#Get the filehandle of the new file 
set res2 [compound { Putfh $bfh; Lookup $filename; Getfh; Getattr $attrs }]
set cont [ckres "Getattr" $status $expcode $res2 $FAIL]

if { ![string equal $cont "false"] } {
set fh [lindex [lindex $res2 2] 2]

set origtime_modify [ extract_attr [lindex [lindex $res2 3] 2] "time_modify" ]

set chgsize 444
set chgmode 444
set nta "[clock seconds] 0"
set tmod 0

# Generate a compound request to change the attributes
set res3 [compound { Putfh $nfh;
	Setattr $stateid {{size {$chgsize}} {mode {$chgmode}}
	{time_access_set {$nta}} {time_modify_set {$tmod}} };
	Getattr $attrs;
}]
prn_attrs [lindex [lindex $res3 2] 2]
ckres "Setattr" $status $expcode $res3 $PASS

}

#finally close the file
incr seqid
set res [compound {Putfh $bfh; Close $seqid $stateid}]
putmsg stdout 1 " "
putmsg stdout 1 "Making Close call with seqid=$seqid, stateid=$stateid"

}



# ----------------------------------------------------------
# b: Test set/get attr FATTR4_MODE of file object, expect OK

set ASSERTION "Test set/get attr FATTR4_MODE of file object, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"

if { ![string equal $cont "false"] } {

set newmode [ extract_attr [lindex [lindex $res3 2] 2] "mode" ]
if {[string compare $chgmode $newmode] == 0} {
        putmsg stdout 0 "\t Test PASS"
} else {
        putmsg stderr 0 "\t Test FAIL: mode $chgmode did not get set"
}

} else {
	putmsg stderr 0 "\t Test UNRESOLVED: Open create failed unexpectedly in test case a" 
}

# -----------------------------------------------------------------
# c: Test set/get attr FATTR4_TIME_ACCESS of file object, expect OK

set ASSERTION "Test set/get attr FATTR4_TIME_ACCESS of file object, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"

if { ![string equal $cont "false"] } {

set newtime_access [ extract_attr [lindex [lindex $res3 2] 2] "time_access" ]
if {[string compare $nta $newtime_access] == 0} {
        putmsg stdout 0 "\t Test PASS"
} else {
        putmsg stderr 0 "\t Test FAIL: time_access did not get set"
}

} else {
	putmsg stderr 0 "\t Test UNRESOLVED: Open create failed unexpectedly in test case a"
}

# -----------------------------------------------------------------
# d: Test set/get attr FATTR4_TIME_MODIFY of file object, expect OK

set ASSERTION "Test set/get attr FATTR4_TIME_MODIFY of file object, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"

if { ![string equal $cont "false"] } {

set newtime_modify [ extract_attr [lindex [lindex $res3 2] 2] "time_modify" ]
if { $newtime_modify != $origtime_modify } {
        putmsg stdout 0 "\t Test PASS"
} else {
        putmsg stderr 0 "\t Test FAIL: time_modify did not get set"
}

} else {
	putmsg stderr 0 "\t Test UNRESOLVED: Open create failed unexpectedly in test case a" 
}

set res [compound {Putfh $bfh; Remove $filename}]
if {$status != "OK"} {
    putmsg stderr 0 "\tERROR, compound{} return status=$status"
}

Disconnect 
exit $PASS 
