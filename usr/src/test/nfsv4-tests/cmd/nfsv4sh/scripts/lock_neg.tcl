#!nfsh
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

#
# This script is to test some irregular conditions of Lock/Open/Close 
# operations:
# 1. Try to close a locked file;
# 2. Try to close a file twice;
# 3. Locku without lock in file;
# 4. Close with lock_stateid;
#

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    puts "       <pathname>: full path dir name to create test file."
    exit 1
}

# set host and file pathname (original)
set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]
set fname "tfile.[pid]"

# connect to the server
connect $host

# get dir file handle
set dfh [get_fh $path]
if {$dfh == ""} {
	puts stderr "ERROR: pathname=($path) not found."
	return 1
}

# negotiate the cleintid
# set unique clientid and verifier
set verifier "[clock clicks]01010"
set owner "[pid]"

set tag "SETCLIENTID"
set res [compound {Setclientid $verifier $owner {0 0 0}}]
puts "\nSetclientid $verifier $owner ..."
puts "Res: $res"
set clientid [lindex [lindex [lindex $res 0] 2] 0]
set cid_verifier [lindex [lindex [lindex $res 0] 2] 1]

# confirm clientid
set tag "SETCLIENTID_CONFIRM"
set res [compound {Setclientid_confirm $clientid $cid_verifier}]
puts "\nSetclientid_confirm $clientid $cid_verifier ..."
puts "Res: $res"

# Now try to create (open_type=1) a new test file under $path with Open op
set oseqid 1
set otype 1
set mode 0644
set oclaim 0
set tag "OPEN_CREATE"
set res [compound {Putfh $dfh; 
        Open $oseqid 3 0 {$clientid $owner} \
        {$otype 0 {{mode $mode} {size 0}}} {$oclaim $fname};
	Getfh; Getattr {mode size}}]
puts "\nOpen to create $fname (size=0) ..."
puts -nonewline "  Open $oseqid 3 0 {$clientid $owner}"
puts " {$otype 0 {{mode $mode} {size 0}}} {$oclaim $fname}"
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Unable to create ($fname) with Open."
	return 2
}
# store the needed open info
set open_sid [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh [lindex [lindex $res 2] 2]
set attr [lindex [lindex $res 3] 2]
incr oseqid

# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	set tag "OPEN_CONFIRM"
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	puts "\nOpen_confirm ($open_sid) $oseqid ..."
	puts "Res: $res"
	if {$status != "OK"} {
		puts stderr "ERROR: unable to confirm created file $fname."
		return 2
	}
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
}

# Now try a WRITEW_LT Lock
set lseqid 1
set ltype 4
set reclaim F
set offset 16
set length 1023
set newlock T
set tag "LOCK_WRITEW"
set res [compound {Putfh $nfh; 
	Lock $ltype $reclaim $offset $length $newlock \
	$open_sid $lseqid {$oseqid $clientid $owner}}]
puts "\nLock $ltype $reclaim $offset $length $newlock ($open_sid) $lseqid ..."
puts "Res: $res"
incr oseqid
if {$status != "OK"} {
	puts stderr "ERROR: failed to set WRITEW_LT lock, Close and exit."
	set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
	puts "\nafter fail to lock, Close $oseqid ($open_sid) ..."
	puts "Res: $res"
	return 2;
}
set lock_sid [lindex [lindex $res 1] 2]

# The TEST #1, close this file without Locku - expect OK | LOCKS_HELD
puts "\n** Test #1: Close this file without Locku - expect OK | LOCKS_HELD"
set tag "CLOSE1"
set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
puts "\nTest#1: Close $oseqid ($open_sid) (without Locku)..."
puts "Res: $res"
if { ($status != "OK") && ($status != "LOCKS_HELD") } {
	puts stderr "ERROR: close failed unexpectedly, statue=($status)."
	return 2
}
set close_sid [lindex [lindex $res 1] 2]

# The TEST #2, try to close this closed file again - expect fails.
puts "\n** Test #2: try to close this closed file - expect fails."
set tag "CLOSE2"
incr oseqid
set res [compound {Putfh $nfh; Close $oseqid $close_sid}]
puts "\ntry to close $oseqid $close_sid again ..."
puts "Res: $res"
if { ($status != "OK") && ($status != "OLD_STATEID") } {
	puts stderr "ERROR: close the file again returned status=($status)."
	puts stderr "\texpected to get OK|OLD_STATEID"
	return 2
}

# Test3, setup to open the file again.
puts "\n** Setup to open the file again ..."
set verifier "[clock clicks]01011"
set owner "[pid]-2"
set tag "SETCLIENTID2"
set res [compound {Setclientid $verifier $owner {0 0 0}}]
puts "\nSetclientid $verifier $owner ..."
puts "Res: $res"
set clientid [lindex [lindex [lindex $res 0] 2] 0]
set cid_verifier [lindex [lindex [lindex $res 0] 2] 1]

# confirm clientid
set tag "SETCLIENTID_CONFIRM2"
set res [compound {Setclientid_confirm $clientid $cid_verifier}]
puts "\nSetclientid_confirm $clientid $cid_verifier ..."
puts "Res: $res"

# Now try to open the test file (open_type=0) file without create.
set oseqid2 10
set otype 0
set mode 0644
set oclaim 0
set tag "OPEN-no-create"
set res [compound {Putfh $dfh; 
        Open $oseqid2 3 0 {$clientid $owner} \
        {$otype 0 {{mode $mode}}} {$oclaim $fname};
	Getfh; Getattr {mode size}}]
puts "\nOpen without create $fname ..."
puts -nonewline "  Open $oseqid2 3 0 {$clientid $owner}"
puts " {$otype 0 {{mode $mode}}} {$oclaim $fname}"
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: unable to Open ($fname)."
	return 2
}
# store the needed open info
set open_sid2 [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh2 [lindex [lindex $res 2] 2]
incr oseqid2

# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	set tag "OPEN_CONFIRM2"
	set res [compound {Putfh $nfh2; Open_confirm "$open_sid2" $oseqid2}]
	puts "\nOpen_confirm $open_sid2 $oseqid2 ..."
	puts "Res: $res"
	if {$status != "OK"} {
		puts stderr "unable to confirm created file $fname."
		return 2
	}
	set open_sid2 [lindex [lindex $res 1] 2]
	incr oseqid2
}

# Now Lockt without any lock in file using new clientid - expect OK
puts "\n** Test #3: Lockt with no lock in file w/new clientid - expect OK"
set lseqid2 1
set ltype 3
set offset 256
set length 10
puts "\nLockt $ltype $clientid $owner $offset $length ..."
set tag "LOCKT2"
set res [compound {Putfh $nfh2; Lockt $ltype $clientid $owner $offset $length}]
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Lockt failed"
	set res [compound {Putfh $nfh2; Close $oseqid2 $open_sid2}]
	puts "\nafter fail to Lockt, Close $oseqid2 $open_sid2 ..."
	puts "Res: $res"
	return 2;
}

# Now Locku without any lock in file using old lock_sid - expect OLD_STATEID
puts "\n** Test #4: Locku w/no lock in file w/old lock_sid - expect OK|OLD_STATEID"
set ltype 3
set offset 256
set length 10
incr lseqid
set tag "LOCKU-w/noLock"
set res [compound {Putfh $nfh2; 
	Locku $ltype $lseqid $lock_sid $offset $length}]
puts "\nLocku $ltype $lseqid $lock_sid $offset $length..."
puts "Res: $res"
if { ($status != "OK") && ($status != "OLD_STATEID") } {
	puts stderr "ERROR: Locku failed w/status=($status)"
	puts stderr "\texpoected to get OK|OLD_STATEID"
	set res [compound {Putfh $nfh2; Close $oseqid2 $open_sid2}]
	puts "\nafter fail to unlock, Close $oseqid2 $open_sid2 ..."
	puts "Res: $res"
	return 2;
}


# Finally close the file and exit
puts "\n** Finally close the file and exit - expect OK"
set tag "CLOSE3"
set res [compound {Putfh $nfh2; Close $oseqid2 $open_sid2}]
puts "\nClose $oseqid2 $open_sid2 ..."
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: final Close failed"
	puts "Res: $res"
	return 2;
}

puts "\n** --- the end ---"

disconnect
exit 0
