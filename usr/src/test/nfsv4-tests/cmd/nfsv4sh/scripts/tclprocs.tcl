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
# Collection of tcl procedures
#

#---------------------------------------------------------
# Extract the attributes
#  Usage: extract_attr attrs name
#	It takes two arguments, the attributes list
#	and the attribute name to be extracted.
#	It then returns its attributes.
#
proc extract_attr {attrs name} {

    foreach entry $attrs {
        if {$name == [lindex $entry 0]} {
            return [lindex $entry 1]
        }
    }
}

#---------------------------------------------------------
# Get the filehandle from the list components of a path
#  Usage: get_fh path
#	path: the "path" in "components" format.
# 	      the path must start from rootfh.
#  Return: 
#	the filehandle of the last components of "path";
#       or empty string if operation failed during the process.
#
proc get_fh { path } {
    set result [compound {Putrootfh; foreach c $path {Lookup $c}; Getfh}]
    return [lindex [lindex $result end] 2]
}


#---------------------------------------------------------
# Nicely print the time
#  Usage: nicetime seconds
#	It takes the seconds as the argument and 
# 	nicely print the associated readable date/time
#
proc nicetime { second } {
    return [clock format $second]
}


#---------------------------------------------------------
# print attributes
#  Usage: prn_attrs attribute_list
#   	Given the attribute list {{name val} ...}, 
#	print out each name and its value
#
proc prn_attrs { alist } {
  foreach attr $alist {
    set name [ lindex $attr 0]
    set val  [ lindex $attr 1]

    switch $name {
        supported_attrs	{ puts "\tSupported attrs  = $val" }
        type		{ switch $val {
			  reg { puts "\tFile type        = file"}
			  lnk { puts "\tFile type        = symlink"}
			  default { puts "\tFile type        = $val" }
			  }
			}
        fh_expire_type	{ puts "\tFH expire type   = $val" }
        change		{ puts "\tChange           = $val" }
        size		{ puts "\tFile size        = $val" }
        link_support	{ puts "\tLink support     = $val" }
        symlink_support	{ puts "\tSymlink support  = $val" }
        named_attr	{ puts "\tNamed attr       = $val" }
        fsid		{ puts "\tFile system ID   = $val" }
        unique_handles	{ puts "\tUnique handles   = $val" }
        lease_time	{ puts "\tLease time       = $val" }
        rdattr_error	{ puts "\tRdattr error     = $val" }
        acl		{ puts "\tACL 	           = $val" }
        aclsupport	{ puts "\tACL support      = $val" }
        archive		{ puts "\tArchive          = $val" }
        cansettime	{ puts "\tCan set time     = $val" }
        case_insensitive {puts "\tCase insensitive = $val" }
        case_preserving	{ puts "\tCase preserving  = $val" }
        chown_restricted {puts "\tChown restricted = $val" }
        filehandle	{ puts "\tFile handle      = $val" }
        fileid		{ puts "\tFile ID          = $val" }
        files_avail	{ puts "\tFiles available  = $val" }
        files_free	{ puts "\tFiles free       = $val" }
        files_total	{ puts "\tFiles total      = $val" }
        fs_locations	{ puts "\tFS locations     = $val" }
        hidden		{ puts "\tHidden           = $val" }
        homogeneous	{ puts "\tHomogeneous      = $val" }
        maxfilesize	{ puts "\tMax file size    = $val" }
        maxlink		{ puts "\tMax link         = $val" }
        maxname		{ puts "\tMax name         = $val" }
        maxread		{ puts "\tMax read         = $val" }
        maxwrite	{ puts "\tMax write        = $val" }
        mimetype	{ puts "\tMime type        = $val" }
        mode		{ puts "\tMode bits        = $val" }
        no_trunc	{ puts "\tNo trunc         = $val" }
        numlinks	{ puts "\tNumber of links  = $val" }
        owner		{ puts "\tOwner            = $val" }
        owner_group	{ puts "\tGroup            = $val" }
        quota_avail_hard { puts "\tHard quota       = $val" }
        quota_avail_soft { puts "\tSoft quota       = $val" }
        quota_used	{ puts "\tQuota used       = $val" }
        rawdev		{ puts "\tRaw device       = $val" }
        space_avail	{ puts "\tSpace available  = $val" }
        space_free	{ puts "\tSpace free       = $val" }
        space_total	{ puts "\tSpace total      = $val" }
        space_used	{ puts "\tSpace used       = $val" }
        system		{ puts "\tSystem           = $val" }
        time_access	{ 
			  set nt [nicetime [lindex $val 0] ]
			  puts "\tAccess time      = $val - $nt" 
			}
        time_access_set	{ puts "\tTime access set  = $val" }
        time_backup	{ 
			  set nt [nicetime [lindex $val 0] ]
			  puts "\tBackup time      = $val - $nt" 
			}
        time_create	{
			  set nt [nicetime [lindex $val 0] ]
			  puts "\tCreated time      = $val - $nt" 
			}
        time_delta	{ puts "\tTime delta       = $val" }
        time_metadata	{
			  set nt [nicetime [lindex $val 0] ]
			  puts "\tTime metadata    = $val - $nt" 
			}
        time_modify	{
			  set nt [nicetime [lindex $val 0] ]
			  puts "\tModified time    = $val - $nt"
			}
        time_modify_set	{ puts "\tTime modify set  = $val" }
        default		{ puts "\tUnknown attributes" }
    }
  }
}


#---------------------------------------------------------
# print directory list
#  Usage: prn_dirlist directory_list_w/attributes
#   	Given the directory list { verf entry_name attrs ...}, 
#	e.g. results returned from Readdir op,
#	print out each name and its returned values
#
proc prn_dirlist { dirlist } {

    foreach entry $dirlist {
	set name  [lindex $entry 1]
	puts "  $name"
	prn_attrs [lindex $entry 2]
    }
}


#---------------------------------------------------------
# Convert pathname to components
#  Usage: path2comp path delm
#	It takes the path argument, and convert it to
#	the format of comonents based on the 'delm' delimiter.
#
proc path2comp { path delm } {
    set comps [split $path $delm]
    if { [lindex $comps 0] == "" } {
	    set comps [lrange $comps 1 [expr [llength $comps] - 1] ]
    }
    return $comps
}


#---------------------------------------------------------
# write ascii to a file
#  Usage: write_ascii filehandle stateid data
#   	It takes the filehandle of the file, the stateid,
#	and the ascii data to be written, writes the data
#	to the file starting from offset 0.  All data will
#	be FILE_SYNC.
#
proc write_ascii { fh sid data } {

    set wres [compound {Putfh $fh; Write $sid 0 f a $data}]
    if { $status != "OK" } {
	puts "write_ascii Failed."
	puts $wres
    }
    set winfo [ split [lindex [lindex $wres 1] 2] = ]
    set cnt [ lindex [lindex $winfo 1] 0]
    set cmt [ lindex [lindex $winfo 2] 0]
    puts "Wrote $cmt of $cnt bytes of data."
}


#---------------------------------------------------------
# Read a remote file using NFSv4 when given the path components
#  Usage: readv4_path path stateid offset count
#   	Given the path argument and its stateid, it reads
#	the file with the byte "count", starting from the 
#	given offset; then print out the data being read.
#
proc readv4_path { fpath stateid offset count } {

    set pfh [ get_fh $fpath ]
    set rres [compound {Putfh $pfh; Read $stateid $offset $count}]
    if { $status != "OK" } {
	puts "readv4_path Failed."
	puts $rres
    }
    return [lindex [lindex [lindex $rres 1] 2] 2]
}


#---------------------------------------------------------
# Read a remote file using NFSv4 when given the path filehandle
#  Usage: readv4_fh pfh stateid offset count
#   	Given the path filehandle and its stateid, it reads
#	the file with the byte "count", starting from the 
#	given offset; then print out the data being read.
#
proc readv4_fh { pfh stateid offset count } {

    set rres [compound {Putfh $pfh; Read $stateid $offset $count}]
    if { $status != "OK" } {
	puts "readv4_fh Failed."
	puts $rres
    }
    return [lindex [lindex [lindex $rres 1] 2] 2]
}


# End of tclprocs
