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
# Test script to create a new file, test Open/Lock/Locku/Lockt/Close operations.
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
#connect -t udp $host
connect -t tcp $host

# get dir file handle
set dfh [get_fh $path]
if {$dfh == ""} {
	puts stderr "ERROR: pathname=($path) not found."
	return 1
}

# negotiate the cleintid
# set unique clientid and verifier
set verifier "[clock seconds]01010"
set owner "[pid]"

set res [compound {Setclientid $verifier $owner {0 0 0}}]
puts "\nSetclientid $verifier $owner ..."
puts "Res: $res"
set clientid [lindex [lindex [lindex $res 0] 2] 0]
set cid_verifier [lindex [lindex [lindex $res 0] 2] 1]

# confirm clientid
set res [compound {Setclientid_confirm $clientid $cid_verifier}]
puts "\nSetclientid_confirm $clientid $cid_verifier ..."
puts "Res: $res"

# Now try to create (open_type=1) a new test file under $path with Open op
set oseqid 1
set otype 1
set mode 0664
set oclaim 0
set tag "OPEN1"
set res [compound {Putfh $dfh; 
        Open $oseqid 3 0 {$clientid $owner} \
        {$otype 0 {{mode $mode} {size 0}}} {$oclaim $fname};
	Getfh; Getattr {mode size}}]
puts "\nOpen to create $fname ..."
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

# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	incr oseqid
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	puts "\nOpen_confirm ($open_sid) $oseqid ..."
	puts "Res: $res"
	if {$status != "OK"} {
		puts stderr "ERROR: unable to confirm created file $fname."
		return 2
	}
	set open_sid [lindex [lindex $res 1] 2]
}

# Now try a WRITE Lock
set lseqid 1
set ltype 2
set reclaim F
set offset 0
set length 1024
set newlock T
set tag "LOCK"
incr oseqid
set res [compound {Putfh $nfh; 
	Lock $ltype $reclaim $offset $length $newlock \
	$open_sid $lseqid {$oseqid $clientid $owner}}]
puts "\nTry a WRITE lock on the file ..."
puts "  Lock $ltype $reclaim $offset $length $newlock ($open_sid) $lseqid ($oseqid $clientid $owner)"
puts "Res: $res"
incr oseqid
if {$status != "OK"} {
	puts stderr "ERROR: Failed to set Write lock the file, Close and exit."
	set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
	puts "\nafter fail to lock, Close $oseqid ($open_sid) ..."
	puts "Res: $res"
	return 2;
}
set lock_sid [lindex [lindex $res 1] 2]

set new_owner "fake_owner"
# Now try LOCKT:
set res [compound {Putfh $nfh; Lockt $ltype $clientid $new_owner 0 1024}]
puts "\nfirst LOCKT with owner($clientid $new_owner) of region 0-1024"
puts "Res: $res"
if {$status != "DENIED"} {
        puts stderr "conflict Lockt(0-1024) was not denied"
        return 3
}

set res [compound {Putfh $nfh; Lockt $ltype $clientid $new_owner 1025 2048}]
puts "\nsecond LOCKT with owner($clientid $new_owner) of region 1025-2048"
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "Lockt(1025-2048) got status=$status"
        return 3
}

# try LOCKT with the original owner on the locked range, expect OK
set res [compound {Putfh $nfh; Lockt $ltype $clientid $owner 0 1024}]
puts "\nthird LOCKT with owner($clientid $owner) of region 0-1024"
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "Lockt of original owner (0-1024) got status=$status"
        return 3
}


# Then unlock the lock
incr lseqid
set tag "UNLOCK"
set res [compound {Putfh $nfh; 
	Locku $ltype $lseqid $lock_sid $offset $length}]
puts "\nLocku $ltype $lseqid ($lock_sid) $offset $length"
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "ERROR: Failed to unlock $offset-$length of the file"
        set res [compound {Putfh $nfh; Close $oseqid ($open_sid)}]
	puts "\nafter fail to unlock, Close $oseqid ($open_sid) ..."
	puts "Res: $res"
        return 2;
}
set lock_sid [lindex [lindex $res 1] 2]

# Lockt again should be OK now:
set res [compound {Putfh $nfh; Lockt $ltype $clientid $new_owner 0 1024}]
puts "\nforth LOCKT with owner($clientid $new_owner) of region 0-1024"
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "Lockt(0-1024) after Locku was not OK"
        return 3
}

# finally close this file
set tag "CLOSE1"
set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
puts "\nFinal test file for now: Close $oseqid ($open_sid) ..."
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Final close failed."
	return 2
}

#check if the file is really there
if [catch {set fh [get_fh "$path $fname"]} file_here ] {
	puts stderr "ERROR: File in <path/$fname> must exist at this point."
	return 1
}

# try open without create on the same file
set otype 0
set tag "OPEN2"
incr oseqid
set res [compound {Putfh $dfh; 
        Open $oseqid 3 0 {$clientid $owner} \
        {$otype 0 {{mode $mode}}} {$oclaim $fname}; Getfh}]
puts "\nOpen again with/non-CREATE $fname (size > 0)..."
puts -nonewline "  Open $oseqid 3 0 {$clientid $owner}"
puts " {$otype 0 {{mode $mode} {size 188}}} {$oclaim $fname}"
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Can not open file $fname under $path"
	return 3
}
# store the needed open info
set open_sid2 [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh2 [lindex [lindex $res 2] 2]
incr oseqid

# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	set res [compound {Putfh $nfh; Open_confirm "$open_sid2" $oseqid}]
	puts "\nOpen_confirm ($open_sid2) $oseqid ..."
	puts "Res: $res"
	if {$status != "OK"} {
		puts stderr "ERROR: unable to confirm with open-non-create."
		return 2
	}
	set open_sid2 [lindex [lindex $res 1] 2]
	incr oseqid
}



set tag "CLOSE2"
set res [compound {Putfh $nfh; Close $oseqid $open_sid2}]
puts "\nFinal Close $oseqid ($open_sid2) ..."
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Final close2 failed."
	return 2
}


# If we get here, test is good; thus remove the created file
set res [compound {Putfh $dfh; Remove $fname}]
puts "\nRemove $fname ..."
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "ERROR: Can not remove file $fname under $path"
        return 3
}

disconnect
exit 0
