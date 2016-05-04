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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Open_confirm testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

# connect to the test server
Connect


# set clientid with server
set tag $TNAME.setup
set clientid ""
set res ""
set cverf ""
if {[setclient [clock clicks] "o.[pid]" clientid cverf res] == "OK"} {
	if {[setclientconf $clientid $cverf res] != "OK"} {
		putmsg stdout 0 "ERROR: cannot setclientid"
		return $UNINITIATED
	}
} else {
	return $UNINITIATED
}

# XXX add catch here later
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
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set st [openconf4 $dfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# b: using open_sid from a closed file
set tag $TNAME{b}
set expct "BAD_STATEID|OLD_STATEID"
set ASSERTION "using open_sid from a closed file,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [openv4 $TESTFILE clientid stateid seqid]
if {$fh == $NULL} {
    putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
    set st [closetst $fh $stateid $seqid res]
    if {$st != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: failed to close the file."
    } else {
    	set stateid [lindex [lindex $res 1] 2]
	# re-open the file and try to confirm w/previous stateid
	set fh2 [opencnftst $dfh $filename $clientid nsid seqid rflags]
	if {$fh2 == $NULL} {
	    putmsg stderr 0 "\t Test UNRESOLVED: failed to open file again."
 	} else {
	    set st [openconf4 $fh2 $rflags stateid seqid res]
	    ckres "Open_confirm" $st $expct $res $PASS
	}
    }
    removev4 $TESTFILE
}


# c: removed file
#set tag $TNAME{c}
#set expct "STALE"
#set ASSERTION "removed file, open_confirm retransmit, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set filename $tag
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	closev4 $TESTFILE $fh $stateid $seqid
#	set st [openconf4 $fh $rflags stateid seqid res]
#	ckres "Open_confirm" $st $expct $res $PASS
#}


# d: symlink to dir filehandle
set tag $TNAME{d}
set expct "BAD_STATEID"
set ASSERTION "symlink to dir filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# XXX add catch here later
	set xfh [get_fh [env2path SYMLDIR]]
	set st [openconf4 $xfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# e: block file filehandle
set tag $TNAME{e}
set expct "BAD_STATEID"
set ASSERTION "block file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# XXX add catch here later
	set xfh [get_fh [env2path BLKFILE]]
	set st [openconf4 $xfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# f: char file filehandle
set tag $TNAME{f}
set expct "BAD_STATEID"
set ASSERTION "char file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# XXX add catch here later
	set xfh [get_fh [env2path CHARFILE]]
	set st [openconf4 $xfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# g: fifo file filehandle
set tag $TNAME{g}
set expct "BAD_STATEID"
set ASSERTION "fifo file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# XXX add catch here later
	set xfh [get_fh [env2path FIFOFILE]]
	set st [openconf4 $xfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# h: wrong file filehandle 
set tag $TNAME{h}
set expct "BAD_STATEID|BADHANDLE"
set ASSERTION "wrong file filehandle, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# XXX add catch here later
	set xfh [get_fh [env2path ROFILE]]
	set st [openconf4 $xfh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# i: corrupted filehandle
#set tag $TNAME{i}
#set expct "BADHANDLE"
#set ASSERTION "corrupted filehandle, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set filename $tag
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	set xfh [string replace $fh end-7 end "DEADBEEF"]
#	set st [openconf4 $xfh $rflags stateid seqid res]
#	ckres "Open_confirm" $st $expct $res $PASS
#	closev4 $TESTFILE $fh $stateid $seqid
#}


# j: filehandle set to 0s
#set tag $TNAME{j}
#set expct "BADHANDLE"
#set ASSERTION "filehandle set to 0s, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set filename $tag
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	set xfh [binary format "S4" {0 0 0 0}]
#	set st [openconf4 $xfh $rflags stateid seqid res]
#	ckres "Open_confirm" $st $expct $res $PASS
#	closev4 $TESTFILE $fh $stateid $seqid
#}


# k: filehandle set to 1s
#set tag $TNAME{k}
#set expct "BADHANDLE"
#set ASSERTION "filehandle set to 1s, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need a thread to set directly <cfh>"
#set filename $tag
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	set xfh [binary format "S4" {65535 65535 65535 65535}]
#	set st [openconf4 $xfh $rflags stateid seqid res]
#	ckres "Open_confirm" $st $expct $res $PASS
#	closev4 $TESTFILE $fh $stateid $seqid
#}


# l: filehandle set to NULL
set tag $TNAME{l}
set expct "NOFILEHANDLE"
set ASSERTION "no filehandle set, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set st [openconf4 "" $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}	


# m: wrong file stateid
set tag $TNAME{m}
set expct "BAD_STATEID"
set ASSERTION "wrong file stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set fil2 "opencf2[clock clicks]"
	set TSTF2 [file join $BASEDIR $fil2]
	set ste2 ""
	set sq2 ""
	set rf2 ""
	set fh2 [opencnftst $dfh $fil2 $clientid ste2 sq2 rf2]
	if {$fh2 == $NULL} {
		putmsg stderr 0 "\t Test UNINITIATED: unable to open $TSTF2."
	} else {
		set st [openconf4 $fh $rflags ste2 seqid res]
		ckres "Open_confirm" $st $expct $res $PASS
		closev4 $TESTFILE $fh $stateid $seqid
		closev4 $TSTF2 $fh2 $ste2 $sq2
		unset fil2 TSTF2 sq2 rf2
	}
}


# n1: corrupted stateid (stateid/seqid + 1)
set tag $TNAME{n1}
set expct "BAD_STATEID"
set ASSERTION "corrupted stateid (stateid/seqid + 1), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set bseqid [expr [lindex $stateid 0] + 1]
	set bad_osid "$bseqid [lindex $stateid 1]"
	set st [openconf4 $fh $rflags bad_osid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}

# n2: corrupted stateid (trashed-other)
set tag $TNAME{n2}
set expct "BAD_STATEID|STALE_STATEID"
set ASSERTION "corrupted stateid (trashed-other), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set newS ""
	set oldS [lindex $stateid 1]
	set l [string length $oldS]
	for {set i 0} {$i < $l} {incr i} {
    		append newS [string index $oldS end-$i]
	}
	set bad_osid "[lindex $stateid 0] $newS"
	set st [openconf4 $fh $rflags bad_osid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}

# o: stateid set to 0-special-stateid
set tag $TNAME{o}
set expct "BAD_STATEID"
set ASSERTION "Openconfirm w/0-special-stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 0 "\t Test UNTESTED"
putmsg stdout 0 "\t   Temporary commented out due to 4811769 (p4)"
#set filename $tag
#set TESTFILE [file join $BASEDIR $tag]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	set ste2 "0 0"
#	set st [openconf4 $fh $rflags ste2 seqid res]
#	ckres "Open_confirm" $st $expct $res $PASS
#	closev4 $TESTFILE $fh $stateid $seqid
#}	


# p: stateid set to 1-special-stateid
set tag $TNAME{p}
set expct "BAD_STATEID"
set ASSERTION "Openconfirm w/1-special-stateid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set ste2 "1 1"
	set st [openconf4 $fh $rflags ste2 seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# s: retransmitted after success w/previous seqid
set tag $TNAME{s}
set expct "BAD_SEQID"
set ASSERTION "retransmitted after success w/previous seqid,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set st [openconf4 $fh $rflags stateid seqid res]
	incr seqid -2
	set st [openconf4 $fh $rflags stateid seqid res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# t: seqid old (set to 1)
set tag $TNAME{t}
set expct "BAD_SEQID"
set ASSERTION "seqid old (set to 1), expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set sq2 1
	set st [openconf4 $fh $rflags stateid sq2 res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}	


# u: seqid set to 0
set tag $TNAME{u}
set expct "BAD_SEQID"
set ASSERTION "seqid set to 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set sq2 0
	set st [openconf4 $fh $rflags stateid sq2 res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}	


# v: seqid set to NULL
#set tag $TNAME{v}
#set expct "BAD_SEQID"
#set ASSERTION "seqid set to NULL, expect $expct"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "Test Untested: nfsh unable to take NULL as input"
#set filename $tag
#set TESTFILE [file join $BASEDIR $filename]
#setparms
#set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
#if {$fh == $NULL} {
#	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
#} else {
#	set sq2 ""
#	set st [openconf4 $fh $rflags stateid sq2 res]
#	ckres "Open_confirm" $st $expct $res $PASS
#	closev4 $TESTFILE $fh $stateid $seqid
#}


# w: seqid corrupted (set to 1234567890)
set tag $TNAME{w}
set expct "BAD_SEQID"
set ASSERTION "seqid corrupted, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	set sq2 1234567890
	set st [openconf4 $fh $rflags stateid sq2 res]
	ckres "Open_confirm" $st $expct $res $PASS
	closev4 $TESTFILE $fh $stateid $seqid
}


# x: normal file, seqid increased & send 2nd openconfirm
set tag $TNAME{x}
set expct "BAD_SEQID"
set ASSERTION \
	"normal file, seqid increased & send 2nd openconfirm,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	exit $UNINITIATED
}
set ste2 $stateid
set st [openconf4 $fh $rflags ste2 seqid res]
set st [openconf4 $fh $rflags stateid seqid res]
ckres "Open_confirm" $st $expct $res $PASS
closev4 $TESTFILE $fh $stateid $seqid


# y: openconfirm when not requested
set tag $TNAME{y}
set expct "BAD_STATEID"
set ASSERTION "openconfirm when not requested, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename "$tag[clock seconds]"
set TESTFILE [file join $BASEDIR $filename]
setparms
set owner 1720
set fh [basic_open $dfh $filename 1 "$clientid $owner" stateid seqid \
	status 1 1 644 1 2 0 1]
if {$fh < 0} {
        putmsg stderr 0 "\t Test UNINITIATED: unable to create $TESTFILE."
} else {
	incr seqid
	set res [compound {Putfh $dfh; Open $seqid 1 0 \
		{$clientid $owner} {0 0 {{mode 644}}} {0 $filename}; \
		Getfh}]
	putmsg stdout 1 "compound {Putfh $dfh;"
	putmsg stdout 1 "\tOpen $seqid 1 0 {$clientid $owner}"
	putmsg stdout 1 "\t{0 0 {{mode 0644}}} {0 $filename}; Getfh}"
	if {$status != "OK"} {
		putmsg stdout 1 "Cannot open ($filename)."
		putmsg stdout 1 "Res: $res"
		set fh $NULL
	} else {
		incr seqid
		set stateid [lindex [lindex $res 1] 2]
		set rflags [lindex [lindex $res 1] 4]
		set fh [lindex [lindex $res 2] 2]
		putmsg stdout 1 \
		  "stateid = $stateid\nrflags = $rflags\nseqid = $seqid"
	}
	if {$fh == $NULL} {
        	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
	} else {
		# make sure open_confirm was not requested
		if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == \
			$OPEN4_RESULT_CONFIRM} {
			putmsg stderr 0 \
		    	"\tTest NOTINUSE: open_confirm requested for $TESTFILE."
			removev4 $TESTFILE
		} else {
        		# XXX add catch here later
        		set st [openconf4 $fh $rflags stateid seqid res]
        		ckres "Open_confirm" $st $expct $res $PASS
        		closev4 $TESTFILE $fh $stateid $seqid
		}
	}
}


# z: openconfirm after lease expired
set tag $TNAME{z}
set expct "EXPIRED|BAD_STATEID"
set ASSERTION "openconfirm after lease expired, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $BASEDIR $tag]
set SERVER $env(SERVER)
set CLIENT $env(CLIENT)
set ret true
setparms
set fh [opencnftst $dfh $filename $clientid stateid seqid rflags]
if {$fh == $NULL} {
	putmsg stderr 0 "\t Test UNINITIATED: unable to open $TESTFILE."
} else {
	# Wait until lease time expires
	set Delay [expr ($LEASE_TIME + 5) * 1000]
	putmsg stdout 1 "after $Delay"
	set tmstr [get_sctime $SERVER $CLIENT]
	after $Delay
	set st [openconf4 $fh $rflags stateid seqid res]
	set tmstr "$tmstr\nafter $Delay and openconf4 are done, \
			get system time again"
	set tmstr "$tmstr\n[get_sctime $SERVER $CLIENT]"
	set ret [ckres "Open_confirm" $st $expct $res $PASS]
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

	# since LEASE has expired (can't close the file), just remove tmp file
	removev4 $TESTFILE
}	

# --------------------------------------------------------------
# disconnect and exit

Disconnect
exit $PASS

