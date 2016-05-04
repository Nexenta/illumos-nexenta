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
# NFSv4 LOCK, LOCKT, LOCKU operations test - positive tests
#   File opened with deny bits, test LOCKT

# include test environment
source LOCKsid.env
source [file join ${TESTROOT} lcltools]

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set dfh [get_fh "$BASEDIRS"]

set clientid [getclientid $TNAME]
if {$clientid == -1} {
	putmsg stderr 0 "$TNAME: setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}


# Create a test file and get its osid
proc openfile {dfh filename clientid deny Afh Aostateid Aoseqid Alowner} {
	global PASS FAIL UNRESOLVED
	upvar 1 $Afh fh
	upvar 1 $Aostateid ostateid
	upvar 1 $Aoseqid oseqid
	upvar 1 $Alowner lowner
	# pass status if exists as global
	if {[info vars ::status] != ""} {
		upvar 1 status status
	}
	putmsg stderr 1 "openlock $dfh $filename"
	putmsg stderr 1 "\t$clientid $deny"
	putmsg stderr 1 "\t$Afh $Aostateid $Aoseqid $Alowner"
	set tag "$filename.setup"

	set fsize 8193
	set fh [basic_open $dfh $filename 1 "$clientid $filename.[pid]" \
		ostateid oseqid status 1 0 664 $fsize 3 $deny]
	if {$fh == -1} {
		putmsg stderr 0 "ERROR openlock: setup->basic_open ($filename)"
		putmsg stderr 0 "\tTest UNRESOLVED: status=($status)"
		putmsg stderr 0 "\tnext 4 assertions will not execute."
		return $UNRESOLVED
	}
	set oseqid [expr $oseqid + 1]
	set lowner "${filename}.lck[clock clicks]"
	set lseqid 1
	#lock first 1K

	return $PASS
}


proc tlock {type} {
	global tag ASSERTION fh clientid lowner status expcode res PASS FAIL

	putmsg stdout 0 "$tag: $ASSERTION"
        set res [compound {Putfh $fh; Lockt $type $clientid $lowner 1000 8193;
                Lockt $type $clientid $lowner 1025 2048}]
        putmsg stderr 1 \
                "compound {Putfh $fh; Lockt $type $clientid $lowner 1000 8193;"
        putmsg stderr 1 "\tLockt $type $clientid $lowner 1025 2048}"
        ckres "Lockt" $status $expcode $res $PASS
}


# Start testing
# --------------------------------------------------------------

# open a file with deny read
set filename "Oread"
set TESTFILE [file join $BASEDIR $filename]
set st [openfile $dfh $filename $clientid 1 fh stateid seqid lowner]
if {$st == $PASS} {
	# a: Open deny read, try Lockt read, expect OK
	set expcode "OK"
	set ASSERTION "Open deny read, try Lockt read, expect $expcode"
	set tag "$TNAME{a}"
	tlock 1

	# b: Open deny read, try Lockt write, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny read, try Lockt write, expect $expcode"
	set tag "$TNAME{b}"
	tlock 2

	# c: Open deny read, try Lockt readwait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny read, try Lockt readwait, expect $expcode"
	set tag "$TNAME{c}"
	tlock 3

	# d: Open deny read, try Lockt writewait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny read, try Lockt writewait, expect $expcode"
	set tag "$TNAME{d}"
	tlock 4
}
closev4 $TESTFILE $fh $stateid $seqid


# open a file with deny write
set filename "Owrite"
set TESTFILE [file join $BASEDIR $filename]
set st [openfile $dfh $filename $clientid 2 fh stateid seqid lowner]
if {$st == $PASS} {
	# e: Open deny write, try Lockt read, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny write, try Lockt read, expect $expcode"
	set tag "$TNAME{e}"
	tlock 1

	# f: Open deny write, try Lockt write, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny write, try Lockt write, expect $expcode"
	set tag "$TNAME{f}"
	tlock 2

	# g: Open deny write, try Lockt readwait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny write, try Lockt readwait, expect $expcode"
	set tag "$TNAME{g}"
	tlock 3

	# h: Open deny write, try Lockt writewait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny write, try Lockt writewait, expect $expcode"
	set tag "$TNAME{h}"
	tlock 4
}
closev4 $TESTFILE $fh $stateid $seqid


# open a file with deny both
set filename "Oboth"
set TESTFILE [file join $BASEDIR $filename]
set st [openfile $dfh $filename $clientid 3 fh stateid seqid lowner]
if {$st == $PASS} {
	# i: Open deny both, try Lockt read, expect OK
	set expcode "OK"
	set ASSERTION "Open deny both, try Lockt read, expect $expcode"
	set tag "$TNAME{i}"
	tlock 1

	# j: Open deny both, try Lockt write, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny both, try Lockt write, expect $expcode"
	set tag "$TNAME{j}"
	tlock 2

	# k: Open deny both, try Lockt readwait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny both, try Lockt readwait, expect $expcode"
	set tag "$TNAME{k}"
	tlock 3

	# l: Open deny both, try Lockt writewait, expect OK
	set expcode "OK"
	set ASSERTION \
		"Open deny both, try Lockt writewait, expect $expcode"
	set tag "$TNAME{l}"
	tlock 4
}
closev4 $TESTFILE $fh $stateid $seqid


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
