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
# a: Test set/get attr FATTR4_CHANGE of changed file data, expect OK	
# b: Test set/get attr FATTR4_CHANGE of changed file attrs, expect OK
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
set expcode "OK"

# Start testing
# -------------------------------------------------------------------

# Create a new file for testing purposes
set filename "newfile.[pid]"
set bfh [get_fh "$BASEDIRS"]
set tfile "[creatv4_file "$BASEDIR/$filename"]"

set sid {0 0} 

# -------------------------------------------------------------------
# a: Test set/get attr FATTR4_CHANGE of changed file data, expect OK
#
# Setup testfile for attribute purposes
set attr {change}

set ASSERTION "Test set/get attr FATTR4_CHANGE of changed file data, $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

#Get the change attr of the new file 
set res [compound { Putfh $bfh; Lookup $filename; Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {

set chgattr1 [ extract_attr [lindex [lindex $res 3] 2] "change" ]
set addtofile "[write_ascii $tfile $sid "This is just a test"]" 

#Get the change attr of the after a write to the new file
set res2 [compound { Putfh $bfh; Lookup $filename; Getfh; Getattr $attr }]
set cont [ckres "Getattr" $status $expcode $res2 $FAIL]

if { ![string equal $cont "false"] } {

set chgattr2 [ extract_attr [lindex [lindex $res2 3] 2] "change" ]
if {[string compare $chgattr1 $chgattr2] == 0} {
	putmsg stderr 1 "\t chgattr1 is $chgattr1"
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "\t chgattr2 is $chgattr2"
	putmsg stderr 1 "\t   res2=($res2)"
	putmsg stdout 0 "\t Test FAIL"
} else {
	putmsg stdout 0 "\t Test PASS"
}

}

}

#--------------------------------------------------------------------
# b: Test set/get attr FATTR4_CHANGE of changed file attrs, expect OK

set ASSERTION "Test set/get attr FATTR4_CHANGE of file object, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"

set attrs {size mode owner time_access time_modify change}

set sid {0 0}
set chgmode 444
set nta "[clock seconds] 0"
set tmod 0

# Generate a compound request to change the attributes
set res3 [compound { Putfh $tfile;
	Setattr $sid { {mode {$chgmode}}
	{time_access_set {$nta}} {time_modify_set {$tmod}} };
	Getattr $attrs;
}]
set cont [ckres "Getattr" $status $expcode $res3 $FAIL]

if { ![string equal $cont "false"] } {

set chgattr3 [ extract_attr [lindex [lindex $res3 3] 2] "change" ]

if {[string compare $chgattr2 $chgattr3] == 0} {
	putmsg stderr 1 "\t chgattr2 is $chgattr1"
        putmsg stderr 1 "\t   res2=($res2)"
        putmsg stderr 1 "\t chgattr3 is $chgattr3"
        putmsg stderr 1 "\t   res3=($res3)"
        putmsg stdout 0 "\t Test FAIL"
} else {
        putmsg stdout 0 "\t Test PASS"
}

}
puts ""

set res [compound {Putfh $bfh; Remove $filename}]
if {$status != "OK"} {
    puts "ERROR, compound1{} return status=$status"
    exit 1
}

Disconnect 
exit 0
