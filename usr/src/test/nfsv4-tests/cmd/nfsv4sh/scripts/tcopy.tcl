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
# Test script for NFS TCL to do local-to-remote or
# remote-to-local (small) file copy.
#

if { $argc != 2 } {
    puts "Usage: $argv0 <readfile> <writefile>"
    puts "       note: <writefile> must exist and writable"
    puts "       note: if <readfile> or <writefile> is an NFS file,"
    puts "             must be in format of <hostname:/dir/filename>."
    exit 1
}

set rfile [ lindex $argv 0 ]
set wfile [ lindex $argv 1 ]

set rfid "Not opened"
set wfid "Not opened"

proc cleanup { rfid wfid exitcode } {
    if { $rfid != "Not opened" } {
	close $rfid
    }
    if { $wfid != "Not opened" } {
	close $wfid
    }
    exit $exitcode
}

# First check if the <file> is local or remote:
set rremote 0
set rl [ split $rfile : ]
set l [ llength $rl ]
if { $l == 2 } {	# remote file
    set rremote 1
    set rhost [ lindex $rl 0 ]
    set rfile [ split [ lindex $rl 1 ] / ]
    set rfile [ lrange $rfile 1 [expr [llength $rfile] - 1] ]
} else { 		# Open the local file for readding:
    set rfile $rl
    if [ catch { open $rfile r } rfid ] {
        puts stderr "Cannot open local file \[$rfile\] for readding."
	cleanup $rfid $wfid 1
    }
    puts "Opened local file \[$rfile\] for reading."
    set rdata [ read $rfid ]
}

if { $rremote == 1 } {		# open the remote file for reading
    #connect -t udp -p 9999 $host
    connect -t tcp -p 2049 $rhost
    puts "Connected to \[$rhost\] for reading."

    puts "rfile=<$rfile>"
    set res [compound { Putrootfh; foreach i $rfile {Lookup $i};
    	Getfh; Getattr type; Access r}]
    if {$status != "OK"} {
        puts "compound{Lookup $rfile} return status=$status"
	puts "res=$res"
        cleanup $rfid $wfid 2
    }
    set c 0
    foreach i $rfile {incr c}
    set fh  [lindex [lindex $res [expr $c + 1]] 2]
    set rft [lindex [lindex [lindex [lindex $res [expr $c + 2]] 2] 0] 1]
    set rfa [lindex [lindex [lindex [lindex $res [expr $c + 3]] 2] 1] 1]

    puts "res=$res"
    puts "<$fh> <$rft> <$rfa>"
    if {$rft != "reg" && $rfa != "READ"} {
        puts "compound{type/access} don't have correct values."
        cleanup $rfid $wfid 2
    }

    set sid 0
    set res2 [compound { Putfh $fh; Read {0 0} 0 9999}]
    if {$status != "OK"} {
        puts "compound{Read} return status=$status"
        cleanup $rfid $wfid 2
    }
    set rcnt  [lindex [lindex [lindex [ lindex $res2 1] 2] 1] 1]
    set rdata [lindex [lindex [ lindex $res2 1] 2] 2]
    #puts "res=$res2"
    #puts "<$rcnt> <$rdata>"
    puts "Total of \[$rcnt\] bytes have been read from \[[lindex $argv 0]\]."
    disconnect
}

# Now the write file
set wremote 0
set wl [ split $wfile : ]
set w [ llength $wl ]
if { $w == 2 } {	# remote file
    set wremote 1
    set whost [ lindex $wl 0 ]
    set wfile [ split [ lindex $wl 1 ] / ]
    set wfile [ lrange $wfile 1 [expr [llength $wfile] -1] ]
} else {
    set wfile $wl
    if [ catch { open $wfile w+ } wfid ] {
        puts stderr "Cannot open local file \[$wfile\] for writting."
	cleanup $rfid $wfid 1
    }
    puts "Opened local file \[$wfile\] for writing."
    puts -nonewline $wfid $rdata
    flush $wfid
    puts "Following data has been written to \[$wfile\]:"
    seek $wfid 0
    set rd [ read $wfid ]
    puts $rd
}

if { $wremote == 1 } {		# Open the remote file for writing.
    #connect -t udp -p 9999 $host
    connect -t tcp -p 2049 $whost
    puts "Connected remote host \[$whost\] for writing."
    puts "wfile=<$wfile>"

    set res [compound { Putrootfh; foreach i $wfile {Lookup $i};
    	Getfh; Getattr type; Access m}]
    if {$status != "OK"} {
        puts "compound{Lookup $wfile} return status=$status"
	puts "res=$res"
        cleanup $rfid $wfid 2
    }
    set c 0
    foreach i $wfile {incr c}
    set fh  [lindex [lindex $res [expr $c + 1]] 2]
    set wft [lindex [lindex [lindex [lindex $res [expr $c + 2]] 2] 0] 1]
    set wfa [lindex [lindex [lindex [lindex $res [expr $c + 3]] 2] 1] 1]

    puts "res=$res"
    puts "<$fh> <$wft> <$wfa>"
    if {$wft != "reg" && $wfa != "MODIFY"} {
        puts "compound{type/access} don't have correct values."
        cleanup $rfid $wfid 2
    }

    set sid 0
    set res2 [compound { Putfh $fh; Write {0 0} 0 f a $rdata }]
    if {$status != "OK"} {
        puts "compound{Write rdata} return status=$status"
        cleanup $rfid $wfid 2
    }

    #puts "res=$res2"
    set wcnt [lindex [lindex [ lindex $res2 1] 2] 0]
    set wf [ lindex $argv 1 ]
    #puts "<$wcnt> <$wf>"
    puts "Total of \[$wcnt\] bytes have been written to \[$wf\]."
    set r3 [readv4_fh $fh {0 0} 0 9999]
    puts $r3
    disconnect
}

cleanup $rfid $wfid 0
