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
# Simple script to test open of a file with and without creation,
# non-claimed, non-checked and with the current user and process
# number as the owner ID
#

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    puts "       <pathname>: full path dir name to create test file."
    exit 1
}

# set host and file pathname (original)
set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]
set fname "nfile.[pid]"

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
set verifier "[clock seconds]"
set owner "owner[pid]"

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
puts "\nTEST #1: Open to create $fname ..."
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
	set tag "OPEN_CONFIRM"
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

# then close this file
incr oseqid
set tag "CLOSE1"
set res [compound {Putfh $nfh; Close $oseqid $open_sid}]
puts "\nNow Close the created file: Close $oseqid ($open_sid) ..."
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Close OPEN/create failed."
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
puts "\n\nTEST #2: Open with/non-CREATE $fname ..."
puts -nonewline "  Open $oseqid 3 0 {$clientid $owner}"
puts " {$otype 0 {{mode $mode} {size 1025}}} {$oclaim $fname}"
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Can not open file $fname under $path"
	return 3
}
# store the needed open info
set open_sid2 [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh2 [lindex [lindex $res 2] 2]

# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	incr oseqid
	puts "\nOpen_confirm ($open_sid2) $oseqid ..."
	set res [compound {Putfh $nfh; Open_confirm "$open_sid2" $oseqid}]
	puts "Res: $res"
	if {$status != "OK"} {
		puts stderr "ERROR: unable to confirm with open-non-create."
		return 2
	}
	set open_sid2 [lindex [lindex $res 1] 2]
}

set tag "CLOSE2"
incr oseqid
set res [compound {Putfh $nfh; Close $oseqid $open_sid2}]
puts "\nNow Close non-create file: Close $oseqid ($open_sid2) ..."
puts "Res: $res"
if {$status != "OK"} {
	puts stderr "ERROR: Final close2 failed."
	return 2
}


# If we get here, test is good; thus remove the created file
set res [compound {Putfh $dfh; Remove $fname}]
puts "\nFinally Remove $fname ..."
puts "Res: $res"
if {$status != "OK"} {
        puts stderr "ERROR: Can not remove file $fname under $path"
        return 3
}

disconnect
exit 0
