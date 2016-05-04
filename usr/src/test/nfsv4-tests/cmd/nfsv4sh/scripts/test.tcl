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

if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    exit
}

set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]

#connect -t udp -p 9999 $host
connect $host

set result [compound {Putrootfh; foreach c $path {Lookup $c};
	Readdir 0 0 1024 1024 { size type } ; Access t;
	Getattr {type size mode time_modify link_support change cansettime}
}]

disconnect 

puts "compound returned Status=\[$status\]"
foreach op $result {
	if {[lindex $op 0] == "Getattr"} {
		puts "  [lindex $op 0] [lindex $op 1]"
		prn_attrs "[lindex $op 2]"
	} else {
		puts "  $op" 
	}
}

exit
