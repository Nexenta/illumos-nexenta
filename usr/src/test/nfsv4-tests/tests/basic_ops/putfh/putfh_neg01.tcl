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
# NFSv4 PUTFH operation test - negative tests

# include all test enironment
source PUTFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set fh [ get_fh "$BASEDIRS" ]

# Start testing
# --------------------------------------------------------------
# a: try to putfh of a bad FH="0000", expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{a}"
set ASSERTION "Putfh a bad FH='0000', expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set bfh "0000"
set res [compound {Putfh $bfh; Getattr type}]
ckres "Putfh" $status $expcode $res $PASS


# b: putfh of a FH w/len < valid len server provides, expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{b}"
set ASSERTION "Putfh a FH with len < valid_FH_len from server, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set fh_len [string length $fh]
set endck [ expr $fh_len - 1]
for {set i 1} {$i < $endck} {incr i} {
	set bfh [string range $fh 0 $i]
	set res [compound {Putfh $bfh; Getattr filehandle}]
	set con [ckres "Putfh" $status $expcode $res $FAIL]
	if {$con == "false"} {
		putmsg stdout 0 "  i=<$i>, bfh=<$bfh>"
		set bfh_len [string length $bfh]
		putmsg stdout 1 "    valid_fh=<$fh>"
		putmsg stdout 1 "    fh_len=<$fh_len>, bfh_len=<$bfh_len>"
		break
	}
}
if {$con == "true"} {
	putmsg stdout 0 "\t Test PASS"
}

# c: putfh of a FH w/len > valid len server provides, expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{c}"
set ASSERTION "Putfh a FH with len > valid_FH_len from server, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set fh_len [string length $fh]
set bfh $fh
for {set i 1} {$i < 33} {incr i} {
	set bfh "${bfh}0"
	set res [compound {Putfh $bfh; Getattr filehandle}]
	set con [ckres "Putfh" $status $expcode $res $FAIL]
	if {$con == "false"} {
		putmsg stdout 0 "  i=<$i>, bfh=<$bfh>"
		set bfh_len [string length $bfh]
		putmsg stdout 1 "    valid_fh=<$fh>"
		putmsg stdout 1 "    fh_len=<$fh_len>, bfh_len=<$bfh_len>"
		break
	}
}
if {$con == "true"} {
	putmsg stdout 0 "\t Test PASS"
}


# d: object.nfs_fh4_val=NULL, expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{d}"
set ASSERTION "Putfh object.nfs_fh4_val=NULL, expect $expcode"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need nfsv4shell to null the object.\n"


# e: object.nfs_fh4_len=-1, expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{e}"
set ASSERTION "Putfh object.nfs_fh4_len=-1, expect $expcode"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "$TNAME{e}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need nfsv4shell to set invalid len the object.\n"


# f: object.nfs_fh4_len=0??, expect BADHANDLE
set expcode "BADHANDLE"
set tag "$TNAME{f}"
set ASSERTION "Putfh object.nfs_fh4_len=0, expect $expcode"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need nfsv4shell to set zero len the object.\n"


# g: Putfh the FH with file removed, expect STALE
set expcode "STALE"
set tag "$TNAME{g}"
set ASSERTION "Putfh the FH with file removed, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"
set tmpd "tmp.[pid]"
set res [compound {Putfh $fh; Create $tmpd {{mode 0777}} d; Getfh}]
set tfh [lindex [lindex $res 2] 2]
set res [compound {Putfh $fh; Remove $tmpd; Putfh $tfh; Getfh}]
ckres "Putfh" $status $expcode $res $PASS


# h: putfh with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set tag "$TNAME{h}"
set ASSERTION "Putfh while FH changed to KRB5, expect $expcode"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need support to change SEC of FH from SERVER.\n"


# i: XXX how do we simulate some server errors:
#	NFS4ERR_MOVE
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE


# m: try to putfh of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set tag "$TNAME{m}"
set ASSERTION "Putfh an expired FH, expect $expcode"
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server hook for FH to expire.\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
