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
# NFSv4 LINK operation test - negative tests

# include all test enironment
source LINK.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set ffh [get_fh "$BASEDIRS $env(TEXTFILE)"]


# Start testing
# --------------------------------------------------------------
# a: try to Link while source obj is removed, expect ENOENT
set expcode "NOENT"
set ASSERTION "try to Link while source obj is removed, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set tag "$TNAME{a}"
set newf "Link-F.[pid]"
set nffh [creatv4_file [file join $BASEDIR $newf]]
if { $nffh != $NULL } {
    # now the link test:
    set res [compound {Putfh $nffh; Savefh;
	Putfh $bfh; Remove $newf; Link "L.new"; Getfh}]
    ckres "Link" $status $expcode $res $PASS
} else {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp file."
    set cont "false"
}


# b: try to Link while target dir is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Link while target dir is removed, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set tag "$TNAME{b}"
set tmpd "tmp.[pid]"
set res [compound {Putfh $bfh; Create $tmpd {{mode 0751}} d; Getfh}]
set tfh [lindex [lindex $res 2] 2]
check_op "Putfh $bfh; Remove $tmpd" "OK" "UNINITIATED"
set res [compound {Putfh $bfh; Lookup "$env(TEXTFILE)"; Savefh;
	Putfh $tfh; Link newl2b}]
ckres "Link" $status $expcode $res $PASS


# c: Link with newname has zero length, expect INVAL
set expcode "INVAL"
set ASSERTION "Link with newname has zero length, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set tag "$TNAME{c}"
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link ""}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# d: Link with newname is not UTF-8, expect INVAL
set expcode "INVAL"
set ASSERTION "Link with newname is not UTF-8, expect $expcode"
#putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set tag "$TNAME{c}"
#puts "\t Test UNTESTED: XXX how to create non-UTF-8 compliance name??\n"


# e: Link with newname set to ".", expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Link with newname set to '.', expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set tag "$TNAME{e}"
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link "."}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# f: Link with newname set to "..", expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Link with newname set to '..', expect $expcode"
putmsg stdout 0 "$TNAME{f}: $ASSERTION"
set tag "$TNAME{f}"
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link ".."}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# g: Link with newname included path delimiter, expect INVAL
set expcode "INVAL"
set ASSERTION "Link with newname included path delimiter, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set tag "$TNAME{g}"
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link "new-$DELM-link"}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# i: Link with newname longer than maxname, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Link with newname longer than maxname, expect $expcode"
putmsg stdout 0 "$TNAME{i}: $ASSERTION"
set tag "$TNAME{i}"
set nli [set_maxname $bfh]
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $bfh; Link $nli}]
set cont [ckres "Link" $status $expcode $res $FAIL]
if {[string equal $cont "false"] && $DEBUG} {
	putmsg stderr 1 "\t   length of newname = ([string length $nli])"
}
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# m: Link across filesystems, expect XDEV
set expcode "XDEV"
set ASSERTION "Link to a file across filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{m}: $ASSERTION"
set tag "$TNAME{m}"
set xfh [get_fh [path2comp $env(SSPCDIR) $DELM]]
set res [compound {Putfh $ffh; Getattr numlinks; Savefh;
	Putfh $xfh; Link "err-link"}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
linkcnt_equal $lcnt1 $ffh $cont $PASS


# n: make a Link in ROFS, expect ROFS
set expcode "ROFS"
set ASSERTION "make a Link to a ReadOnly filesystem, expect $expcode"
putmsg stdout 0 "$TNAME{n}: $ASSERTION"
set tag "$TNAME{n}"
set rofh [get_fh [path2comp $env(ROFSDIR) $DELM]]
set res [compound {Putfh $rofh; Lookup $env(RWFILE); Getattr numlinks;
	Getfh; Savefh; Putfh $rofh; Link "err-rolink"}]
set cont [ckres "Link" $status $expcode $res $FAIL]
set lcnt1 [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
set rffh [lindex [lindex $res 3] 2]
linkcnt_equal $lcnt1 $rffh $cont $PASS

# p: newname is already a hardlink to source, expect EXIST (issue 130)
set expcode "EXIST"
set ASSERTION "newname is already a hardlink to source, expect $expcode"
putmsg stdout 0 "$TNAME{p}: $ASSERTION"
set tag "$TNAME{p}"
set newln "newln.[pid]"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Savefh;
	Putfh $bfh; Link $newln}]
if { [ckres "Link1" $status "OK" $res $FAIL] == "true" } {
	# try to link again, should fail w/EXIST
	set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getattr numlinks;
		Getfh; Savefh; Putfh $bfh; Link $newln}]
	set cont [ckres "Link" $status $expcode $res $FAIL]
	# and make sure link-count was not increased w/this failure
	set lcnt1 [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
	set newfh [lindex [lindex $res 3] 2]
	linkcnt_equal $lcnt1 $newfh $cont $PASS
	# Cleanup: remove the created link
	compound {Putfh $bfh; Remove $newln}
}


# --------------------------------------------------------------
# disconnect and exit
set tag ""
Disconnect
exit $PASS
