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
# Read a directory, print each entry with attributes
#

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    exit
}

set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]

connect $host

set cookie 0
set eof false

while {$eof != "true"} {

    set result [compound {
        Putrootfh
        foreach c $path {Lookup $c}
	Readdir $cookie 0 1024 1024 { size type time_modify }
    }]

    if {$status != "OK"} {
        puts $status
        exit
    }

    # Get the readdir result from the compound result

    set readdirres [ lindex $result end ]


    # Get the eof flag from the directory result

    set eof [ lindex $readdirres 4 ]
    if { $eof != "true" } { 
    	# Then also need to get its cookie to read more
    	set dlist [ lindex $readdirres 3 ]
    	set cookie [ lindex [ lindex $dlist [expr [llength $dlist] -1]] 0]
    }

    # Now extract the directory listing itself

    set dirlist [ lindex $readdirres 3 ]

    # Print each entry with its attributes in the whole
    # directory in sorted order.

    prn_dirlist [ lsort -index 1 $dirlist ]
}

disconnect
exit 0
