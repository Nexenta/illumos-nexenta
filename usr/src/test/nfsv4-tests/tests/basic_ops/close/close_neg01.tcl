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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Close testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

# connect to the test server
Connect


# XXX add catch here later
set tag $TNAME.setup
set dfh [get_fh $BASEDIRS]

proc setparms {} {
	uplevel 1 {set stateid ""}
	uplevel 1 {set seqid ""}
	uplevel 1 {set rflags ""}
	uplevel 1 {set res ""}
	uplevel 1 {set st ""}
	uplevel 1 {set fh ""}
	uplevel 1 {set xfh ""}
}


# Start testing
# --------------------------------------------------------------

# a: directory filehandle
set tag $TNAME{a}
set expct "ISDIR|BAD_STATEID"
set ASSERTION "directory filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
set st [closetst $dfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}

# b: removed file filehandle
#set tag $TNAME{b}
#set expct "STALE"
#set ASSERTION "removed file filehandle, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [openv4 $TESTFILE clientid stateid seqid ]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#	exit $UNINITIATED
#}
#if {[removev4 $TESTFILE] == $NULL} {
#	putmsg stdout 0 "Can not remove $TESTFILE"
#}
#set res ""
#set st [closetst $fh $stateid $seqid res]
#ckres "Close" $st $expct $res $PASS


# c: symlink to dir filehandle
set tag $TNAME{c}
set expct "BAD_STATEID"
set ASSERTION "symlink to dir filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# XXX add catch here later
set xfh [get_fh [env2path SYMLDIR]]
set res ""
set st [closetst $xfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# d: block file filehandle
set tag $TNAME{d}
set expct "BAD_STATEID"
set ASSERTION "block file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# XXX add catch here later
set xfh [get_fh [env2path BLKFILE]]
set res ""
set st [closetst $xfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# e: char file filehandle
set tag $TNAME{e}
set expct "BAD_STATEID"
set ASSERTION "char file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# XXX add catch here later
set xfh [get_fh [env2path CHARFILE]]
set res ""
set st [closetst $xfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# f: fifo file filehandle
set tag $TNAME{f}
set expct "BAD_STATEID"
set ASSERTION "fifo file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# XXX add catch here later
set xfh [get_fh [env2path FIFOFILE]]
set res ""
set st [closetst $xfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# g: wrong file filehandle 
set tag $TNAME{g}
set expct "BAD_STATEID"
set ASSERTION "wrong file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
# XXX add catch here later
set xfh [get_fh [env2path ROFILE]]
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
set st [closetst $xfh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# h: corrupted filehandle
#set tag $TNAME{h}
#set expct "BADHANDLE"
#set ASSERTION "corrupted filehandle, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [openv4 $TESTFILE clientid stateid seqid ]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#	exit $UNINITIATED
#}
## XXX add catch here later
#set xfh [string replace $fh end-7 end "DEADBEEF"]
#set res ""
#set st [closetst $xfh $stateid $seqid res]
#ckres "Close" $st $expct $res $PASS
#if {[removev4 $TESTFILE] == $NULL} {
#	putmsg stdout 0 "Can not remove $TESTFILE"
#}


# i: filehandle set to 0s
#set tag $TNAME{i}
#set expct "BADHANDLE"
#set ASSERTION "filehandle set to 0s, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [openv4 $TESTFILE clientid stateid seqid ]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#	exit $UNINITIATED
#}
## XXX add catch here later
#set xfh [binary format "S4" {0 0 0 0}]
#set res ""
#set st [closetst $xfh $stateid $seqid res]
#ckres "Close" $st $expct $res $PASS
#if {[removev4 $TESTFILE] == $NULL} {
#	putmsg stdout 0 "Can not remove $TESTFILE"
#}

# j: filehandle set to 1s
#set tag $TNAME{j}
#set expct "BADHANDLE"
#set ASSERTION "filehandle set to 1s, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [openv4 $TESTFILE clientid stateid seqid ]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#	exit $UNINITIATED
#}
## XXX add catch here later
#set xfh [binary format "S4" {65535 65535 65535 65535}]
#set res ""
#set st [closetst $xfh $stateid $seqid res]
#ckres "Close" $st $expct $res $PASS
#if {[removev4 $TESTFILE] == $NULL} {
#	putmsg stdout 0 "Can not remove $TESTFILE"
#}


# k: filehandle set to NULL
set tag $TNAME{k}
set expct "NOFILEHANDLE"
set ASSERTION "no filehandle set, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
# XXX add catch here later
set res ""
set st [closetst "" $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}



# l: wrong file stateid
set tag $TNAME{l}
set expct "BAD_STATEID"
set ASSERTION "wrong file stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set fil2 "close-2-[clock clicks]"
set TSTF2 [file join $BASEDIR $fil2]
set ste2 ""
set sq2 ""
set rf2 ""
set fh2 [opencnftst $dfh $fil2 $clientid ste2 sq2 rf2 ]
if {$fh2 == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TSTF2."
	exit $UNINITIATED
}
set st [openconf4 $fh2 $rf2 ste2 sq2]
if {$st != "OK"} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open_confirm $TSTF2."
	exit $UNINITIATED
}
set res ""
set st [closetst $fh $ste2 $seqid res]
ckres "Close" $st $expct $res $PASS
#close file with real info now
set st [closetst $fh $stateid $seqid res]
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}
closev4 $TSTF2 $fh2 $ste2 $sq2
unset fil2 TSTF2 sq2 rf2


# m: wrong file stateid diff clientid
set tag $TNAME{m}
set expct "BAD_STATEID"
set ASSERTION "wrong file stateid diff clientid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set fil2 "close-2-[clock clicks]"
set TSTF2 [file join $BASEDIR $fil2]
set ste2 ""
set cl2 ""
set sq2 ""
set rf2 ""
set fh2 [openv4 $TSTF2 cl2 ste2 sq2]
if {$fh2 == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TSTF2."
	exit $UNINITIATED
}
set res ""
set st [closetst $fh $ste2 $seqid res]
ckres "Close" $st $expct $res $PASS
#close file with real info now
set st [closetst $fh $stateid $seqid res]
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}
closev4 $TSTF2 $fh2 $ste2 $sq2
unset fil2 TSTF2 cl2 sq2 rf2


# n1: corrupted stateid (stateid/seqid + 1)
set tag $TNAME{n1}
set expct "BAD_STATEID"
set ASSERTION "corrupted stateid (stateid/seqid + 1), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set bseqid [expr [lindex $stateid 0] + 1]
set bad_osid "$bseqid [lindex $stateid 1]"
set res ""
set st [closetst $fh $bad_osid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}

# n2: corrupted stateid (trashed-other)
set tag $TNAME{n2}
set expct "BAD_STATEID|STALE_STATEID"
set ASSERTION "corrupted stateid (trashed-other), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set newS ""
set oldS [lindex $stateid 1]
set l [string length $oldS]
for {set i 0} {$i < $l} {incr i} {
    	append newS [string index $oldS end-$i]
}
set bad_osid "[lindex $stateid 0] $newS"
set res ""
set st [closetst $fh $bad_osid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# o: stateid set to 0-special-stateid
set tag $TNAME{o}
set expct "BAD_STATEID"
set ASSERTION "Close w/0-special-stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 0 "\t Test UNTESTED"
putmsg stdout 0 "\t   Temporary commented out due to 4811769 (p4)"
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [openv4 $TESTFILE clientid stateid seqid ]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#	exit $UNINITIATED
#}
#set ste3 "0 0"
#set res ""
#set st [closetst $fh $ste3 $seqid res]
#ckres "Close" $st $expct $res $PASS
#if {[removev4 $TESTFILE] == $NULL} {
#	putmsg stdout 0 "Can not remove $TESTFILE"
#}


# p: stateid set to 1-special-stateid
set tag $TNAME{p}
set expct "BAD_STATEID"
set ASSERTION "Close w/1-special-stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set ste3 "1 1"
set res ""
set st [closetst $fh $ste3 $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# r: simulate retransmitted, seqid increased by 3
set tag $TNAME{r}
set expct "BAD_SEQID"
set ASSERTION "simulate retransmitted, seqid increased by 3, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
incr seqid 3
set st [closetst $fh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# s: previous seqid
set tag $TNAME{s}
set expct "BAD_SEQID"
set ASSERTION "previous seqid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
incr seqid -1
set st [closetst $fh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# t: seqid old (set to 1)
set tag $TNAME{t}
set expct "BAD_SEQID"
set ASSERTION "seqid old (set to 1), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
incr seqid 1
set st [closetst $fh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# u: seqid set to 0
set tag $TNAME{u}
set expct "BAD_SEQID"
set ASSERTION "seqid set to 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
set seqid 0
set st [closetst $fh $stateid $seqid res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# v: seqid set to NULL
set tag $TNAME{v}
set expct "BAD_SEQID"
set ASSERTION "seqid set to NULL, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
set st [closetst $fh $stateid {""} res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}


# w: seqid corrupted (set to 1234567890)
set tag $TNAME{w}
set expct "BAD_SEQID"
set ASSERTION "seqid (set to 1234567890) corrupted, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set res ""
set sq2 1234567890
set st [closetst $fh $stateid $sq2 res]
ckres "Close" $st $expct $res $PASS
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}

# x: close again using stateid from close
set tag $TNAME{x}
set expct "BAD_STATEID|OLD_STATEID"
set ASSERTION "close again using stateid from close, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set st [closetst $fh $stateid $seqid res]
	if {$st != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: failed in 1st close."
	    putmsg stderr 0 "\t\t status=($st)"
	} else {
	    set csid [lindex [lindex $res 1] 2]
	    incr seqid
	    set st [closetst $fh $csid $seqid res]
	    ckres "Close" $st $expct $res $PASS
	    if {[removev4 $TESTFILE] == $NULL} {
		putmsg stdout 0 "Can not remove $TESTFILE"
	    }
	}
}

# z: get NFS4ERR_EXPIRED
set tag $TNAME{z}
set expct "EXPIRED|BAD_STATEID"
set ASSERTION "get NFS4ERR_EXPIRED, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid ]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}

# Wait until lease time expires
set SERVER $env(SERVER)
set CLIENT $env(CLIENT)
set tmstr [get_sctime $SERVER $CLIENT]
set Delay [expr ($LEASE_TIME + 5) * 1000]
after $Delay
set res ""
set st [closetst $fh $stateid $seqid res]
set tmstr "$tmstr\nafter $Delay and closetst are done, \
		get system time again"
set tmstr "$tmstr\n[get_sctime $SERVER $CLIENT]"
set ret [ckres "Close" $st $expct $res $PASS]
if {!$ret} {
	# if fail, puts related time info on server and client
	# and cpu info as well
	puts $tmstr
	set cpucmd "/usr/sbin/psrinfo -pv"
	puts "\nCPU info of server: $SERVER"
	puts [exec rsh -n -l root $SERVER "$cpucmd"]
	puts "\nCPU info of client: $CLIENT"
	puts [exec sh -c "$cpucmd"]

}
if {[removev4 $TESTFILE] == $NULL} {
	putmsg stdout 0 "Can not remove $TESTFILE"
}

# XXX reconnect if more assertions are added
#
# y: get NFS4ERR_DELAY ???????????
# z: get NFS4ERR_RESOURCE ? should we test it from opentestcases ?
# other assertions to implement (recovery & migration & security)
# : get NFS4ERR_FHEXPIRED (volatile filehandles, recovery)
# : get NFS4ERR_GRACE	(recovery)
# : get NFS4ERR_LEASE_MOVED (migration)
# : get NFS4ERR_MOVED	(migration)
# : get NFS4ERR_SERVERFAULT (recovery)
# : get NFSV$ERR_STALE_STATEID


# --------------------------------------------------------------
# disconnect and exit

Disconnect
exit $PASS

