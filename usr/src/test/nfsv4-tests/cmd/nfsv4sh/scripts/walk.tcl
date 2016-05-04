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
# Do a file tree walk.
#
# This script accepts a hostname and a pathname to
# a directory.  It then recursively descends the
# directory hierarchy listing all the files and
# directory. Each directory level is indented.


#  Given an attribute name, extract its 
#  value from an attribute list that looks
#  like this:
#  { {type dir} {size 1664} {filehandle 7C842044} }

# NOTE (03/01/2000):
#  this script does not work if path exported by
#  server is more than one component.
#

proc extract_attr {attrs name} {

    foreach entry $attrs {
        if {$name == [lindex $entry 0]} {
            return [lindex $entry 1]
        }
    }
}


# Do a path lookup and return a filehandle

proc get_handle { path } {
    set result [compound {Putrootfh; foreach c $path {Lookup $c}; Getfh}]
    return [lindex [lindex $result end] 2]
}

# This procedure is invoked recursively to list
# The entries in a directory hierarchy. The first
# argument is a filehandle.  The second is the
# recursion depth which is used to control indenting.

proc dolist { fh depth} {

    set cookie 0
    set eof false
    
    while { $eof != "true" } {
    
        set result [compound {
            Putfh $fh
            Readdir $cookie 0 1024 1024 {type filehandle}
        }]
    
        if {$status != "OK"} {
            puts $status
            exit
        }
    
    
        # Get the readdir result from the compound result
    
        set readdirres [ lindex $result 1 ]
    
    
        # Get the eof flag from the directory result
    
        set eof [ lindex $readdirres 4 ]
    
    
        # Now extract the directory listing itself
    
        set dirlist [ lindex $readdirres 3 ]


	# Examine each entry in the directory

        foreach entry $dirlist {

            set cookie [ lindex $entry 0 ]
            set name   [ lindex $entry 1 ]
            set attrs  [ lindex $entry 2 ]
            set type   [ extract_attr $attrs "type" ]
            set fh2    [ extract_attr $attrs "filehandle" ]


            # Indent the line

            for { set i 0 } { $i < $depth } { incr i } {
                puts -nonewline "   "
            }


            # If the entry is a directory, invoke the
            # procedure recursively. Otherwise, just
            # list the entry name.

            if {$type == "dir"} {
                puts "$name/"
                dolist $fh2 [expr $depth+1]

            } else {
                puts "$name"
            }
        }
    }

    return
}

#####################

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    exit
}

set host [ lindex $argv 0 ]
set path [ split [ lindex $argv 1 ] / ]
if { [lindex $path 0] == "" } {
	set path [lrange $path 1 [expr [llength $path] - 1]]
}

# The Java server temporarily runs
# on port 999 so as not to interfere
# with the native NFS server.

#connect -p 9999 -t udp $host
connect $host

dolist [get_handle $path] 0
