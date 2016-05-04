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
# Test script for NFS TCL
#
# This script is to check server's responses to errors
# with different operations, including Lookup, Link,
# Rename, Remove, etc.
#

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    puts "       note: <pathname> must be a file, and"
    puts "             it's parent directory must be writable"
    exit 1
}

set host [lindex $argv 0]
set path [ path2comp [lindex $argv 1] "/" ]
set pathlen [expr [llength $path] - 1]

set dir [lrange $path 0 [expr $pathlen - 1]]
set fname [lindex $path $pathlen]

#connect -t udp -p 9999 $host
connect $host
puts "connected to $host ..."
set dfh [get_fh $dir]

# 1. Check for NOFILEHANDLE : 
set result [compound { Lookup $fname }]
if { $status != "NOFILEHANDLE" } {
	puts "compound {Lookup $path}"
	puts "   FAILED: expect it to return NOFILEHANDLE"
	puts ""
	puts $result
	exit 2
}
puts "checking Lookup NOFILEHANDLE OK"

# 2. Check for NOENT : 
set result [compound { Putfh $dfh; Lookup enoent }]
if { $status != "NOENT" } {
	puts "compound {Putfh $dfh; Lookup enoent }"
	puts "   FAILED: expect it to return NOENT"
	puts ""
	puts $result
	exit 2
}
puts "checking Lookup NOENT OK"

# 3. Check for <sfh> is dir in Link : 
# first verify pathname to be a file.
set result [compound { Putrootfh; foreach c $path {Lookup $c}; Getattr type}]
set ftype [lindex [lindex [lindex [lindex $result end] 2] 0] 1]
if { $ftype != "reg" } {
	puts "($path) is not a file"
	puts "Link requires a file to be linked"
	exit 2
}

set result [compound { Putfh $dfh; Savefh; Lookup $fname; Link linkfile}]
if { ($status != "ISDIR") && ($status != "NOTDIR")} {
	puts "compound {Putrootfh; Lookup {$dir}; Savefh;"
	puts "          Lookup {$fname}; Link linkfile}"
	puts "   FAILED: expect it to return ISDIR/NOTDIR"
	puts ""
	puts $result
#	exit 2
}
puts "checking Link ISDIR/NOTDIR OK"

# Check for <sfh> is not saved in Rename : 
set result [compound { Putfh $dfh; Rename $fname "NewFile"}]
if { $status != "NOFILEHANDLE" } {
	puts "compound {Putfh $dfh; Rename $fname NewFile}"
	puts "   FAILED: expect it to return NOFILEHANDLE"
	puts ""
	puts $result
	exit 2
}
# make sure $fname still exists (since operation failed):
set result [compound { Putfh $dfh; Lookup $fname }]
if { $status == "NOENT" } {
	puts "  after rename failed, \[$fname\] should still exist."
}

puts "checking Rename NOFILEHANDLE OK"

# Check for directory is not empty in Remove : 
set dname [lindex $dir [expr [llength $dir] - 1]]
set result [compound { Putfh $dfh; Lookupp; Remove $dname}]
if { $status != "NOTEMPTY" } {
	puts "compound {Putfh $dfh; Lookupp; Remove $dname}"
	puts "   FAILED: expect it to return NOTEMPTY"
	puts ""
	puts $result
	exit 2
}
# make sure $dir still exists (since operation failed):
set result [compound { Putrootfh; foreach c $dir {Lookup $c} }]
if { $status == "NOENT" } {
	puts "  after rename failed, \[$dir\] should still exist."
}

puts "checking Remove NOTEMPTY OK"

exit 0
