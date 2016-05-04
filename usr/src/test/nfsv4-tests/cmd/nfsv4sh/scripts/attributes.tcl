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

# Print the attributes of a given file or directory.

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    exit
}

set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]

#connect -t udp -p 9999 $host
connect $host

# Generate a compound request that obtains the attributes for the path.
# Try to get all attributes

set al "supported_attrs type fh_expire_type change size link_support
	symlink_support named_attr fsid unique_handles lease_time rdattr_error
	acl aclsupport archive cansettime case_insensitive case_preserving 
	chown_restricted filehandle fileid files_avail files_free files_total
	fs_locations hidden homogeneous maxfilesize maxlink maxname maxread
	maxwrite mimetype mode no_trunc numlinks owner owner_group 
	quota_avail_hard quota_avail_soft quota_used rawdev 
	space_avail space_free space_total space_used system time_access 
	time_backup time_create time_delta time_metadata time_modify "
set aln [llength $al]

# "time_access_set & time_modify_set" are for Setattr only; INVAL for Getattr

set fh [get_fh $path]
if {$fh == ""} {
	puts stderr "ERROR: path=($path) not found in server=($host)."
	exit 1
}
set res [compound {Putfh $fh; 
		for {set i 0} {$i < $aln} {incr i 3} {
			Getattr [lrange $al $i [expr $i + 2]] }
	}]
if {$status != "OK"} {
	puts "ERROR: compound{} return status=$status"
	puts "  Res: $res"
    	exit 2
}

# build the result list:
set all_attr_res ""
foreach attr_res [lrange $res 1 end] {
	set all_attr_res "$all_attr_res [lindex $attr_res 2]"
}


# Print all values of returned attributes;
puts "All attributes for \[[lindex $argv 1]\] are:"
prn_attrs $all_attr_res

disconnect
exit 0
