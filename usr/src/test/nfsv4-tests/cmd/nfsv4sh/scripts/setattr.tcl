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
# Sets and prints the attributes of a file.
#

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <filepath>"
    puts "       note: <filepath> must be full path and writable."
    exit
}

set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]
set attrs {size mode owner owner_group time_access time_modify}

#connect -t udp -p 9999 $host
connect $host


# call the above function to create a test file
set dfh [ get_fh $path ]
if {$dfh == ""} {
	puts stderr "ERROR: dirpath=($path) not found."
	return 1
}

# Create a new file to be used for attribute manipulation
set fname "Tfile.[pid]"
set verifier "[clock seconds]"
set owner "owner[pid]"
set res [compound {Setclientid $verifier $owner {0 0 0}}]
if {$status != "OK"} {
	puts "ERROR: cannot set clientid."
	puts "Res: $res"
	return 2
}
set clientid [lindex [lindex [lindex $res 0] 2] 0]
set cid_verifier [lindex [lindex [lindex $res 0] 2] 1]

# confirm clientid
set res [compound {Setclientid_confirm $clientid $cid_verifier}]
if {$status != "OK"} {
	puts "ERROR: cannot confirm clientid."
	puts "Res: $res"
	return 2
}
# Now try to create (open_type=1) the $fname under $dfh 
set oseqid 1
set otype 1
set oclaim 0
set res [compound {Putfh $dfh; Open $oseqid 3 0 {$clientid $owner} \
       	{$otype 0 {{mode 0640}}} {$oclaim $fname}; Getfh}]
if {$status != "OK"} {
	puts "ERROR: Unable to create ($fname) with Open."
	puts "Res: $res"
	return 3
}
set cl [clock seconds]
set open_sid [lindex [lindex $res 1] 2]
set rflags [lindex [lindex $res 1] 4] 
set nfh [lindex [lindex $res 2] 2]
incr oseqid
# do open_confirm if needed, e.g. rflags==OPEN4_RESULT_CONFIRM=2
if {[expr $rflags & 2] == 2} {
	set tag "OPEN_CONFIRM"
	set res [compound {Putfh $nfh; Open_confirm $open_sid $oseqid}]
	if {$status != "OK"} {
		puts "ERROR: unable to confirm created file $fname."
		puts "Res: $res"
		return 3
	}
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
}

# Generate a compound request to obtain the attributes for the path.
set res [compound { Putfh $nfh; Getattr $attrs }]
if {$status != "OK"} {
	puts "ERROR compound{ Getattr } return status=$status"
	puts "Res: $res"
	return 4
}

puts "Attributes Before Setattr (at [clock format $cl]): "
prn_attrs [lindex [lindex $res 1] 2]

puts "Now sleep for 30 seconds ..."
exec sleep 30
set nta "[expr [clock seconds] - 218] 0"

# Generate a compound request to change the attributes
set res [compound { Putfh $nfh;
	Setattr $open_sid {{size 8888} {mode 0765} {time_access_set {$nta}} };
	Getattr $attrs; }]
if {$status != "OK"} {
	puts "ERROR compound{ Setattr } return status=$status"
	puts "Res: $res"
#	return 5
}

set ncl [clock seconds]
puts "New attributes after Setattr (at [clock format $ncl]): "
prn_attrs [lindex [lindex $res 2] 2]

set res [compound {Putfh $nfh; Close $oseqid $open_sid; 
	Putfh $dfh; Remove $fname}]
if {$status != "OK"} {
	puts stderr "ERROR: Close/Remove failed."
	puts "Res: $res"
	return 6
}

disconnect 
exit 0
