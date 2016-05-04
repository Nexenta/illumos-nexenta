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
# Evaluate a path and print the
# filehandle for each component.
#
# Given the args "server  a/b/c" it prints
#
#	C25A82BC: a
#	E6D341F6: b
#	6249B195: c
#


if { $argc != 2 } {
    puts "Usage: $argv0 <hostname> <pathname>"
    exit
}

set host [ lindex $argv 0 ]
set path [ path2comp [lindex $argv 1] "/" ]

#connect -t udp -p 9999 $host
connect $host


# Generate a compound request that
# contains a lookup for each component.

set result [compound {
    Putrootfh
	# the following only works if first component is shared
	foreach component $path {
		Lookup $component 
		Getfh
	}
}]

if {$status != "OK"} {
    puts "ERROR, compound{} return status=$status"
    exit
}


# For each pathname component extract
# its filehandle from the result.
# After the initial putrootfh, the
# result is an alternation of lookup
# and getfh results, hence the increment
# by 2.

set inx 2
foreach component $path {
    set fh [lindex [lindex $result $inx ] 2]
    puts "$fh: $component"
    incr inx 2
}
