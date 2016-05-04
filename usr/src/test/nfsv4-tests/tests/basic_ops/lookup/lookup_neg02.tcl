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
# NFSv4 LOOKUP operation test - more of negative tests

# include all test enironment
source LOOKUP.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Lookup with an obj not exist, expect NOENT
set expcode "NOENT"
set ASSERTION "Lookup with an obj not exist, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "NOENT.[pid]"}]
ckres "Lookup" $status $expcode $res $PASS


# d: Lookup with CFH as a file, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Lookup with CFH as a file, expect $expcode"
putmsg stdout 0 "$TNAME{d}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(TEXTFILE); Lookup $env(TEXTFILE)}]
ckres "Lookup" $status $expcode $res $PASS


# e: Lookup with CFH as a fifo, expect NOTDIR
set expcode "NOTDIR"
set ASSERTION "Lookup with CFH as a fifo, expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set tobj "FIFO[pid]"
set res [compound {Putfh $bfh; Create $tobj {{mode 0666}} f; Getfh}]
set tfh [lindex [lindex $res 2] 2]
set res [compound {Putfh $tfh; Lookup newfile}]
ckres "Lookup" $status $expcode $res $PASS
set res [compound {Putfh $bfh; Remove $tobj}]


# m: try to Lookup of expired FH, expect FHEXPIRED
set expcode "FHEXPIRED"
set ASSERTION "Lookup an expired FH, expect $expcode"
#putmsg stdout 0 "$TNAME{m}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need server hook for FH expired.\n"


# n: Lookup with cfh is bad, expect BADHANDLE
set expcode "BADHANDLE"
set ASSERTION "Lookup with cfh is bad, expect $expcode"
#putmsg stdout 0 "$TNAME{n}: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook from server to set cfh to a bad FH\n"


# w: Lookup with component name too long, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set ASSERTION "Lookup with component name too long, expect $expcode"
#putmsg stdout 0 "$TNAME{w}: $ASSERTION"
#puts "\t Test UNTESTED: XXX how to create an obj w/nametoolong for lookup?\n"


# x: Lookup with WrongSec, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Lookup with wrongSec, expect $expcode"
putmsg stdout 0 "$TNAME{x}: $ASSERTION"
# check for $KRB5DIR to make sure KRB5 is setup in $SERVER
  set kpath [path2comp $env(KRB5DIR) $DELM]
  set dname [lrange $kpath 0 end-1]
  set lname [lrange $kpath end end]
  set kfh [get_fh $dname]
  set res [compound {Putfh $kfh; Secinfo $lname}]
  set slist [lindex [lindex $res 1] 2]
  if {[lsearch -regexp $slist "KRB5"] == -1} {
	putmsg stderr 0 "\t Test NOTINUSE: KRB5 is not setup in server."
  } else {
	set res [compound {Putfh $kfh; Lookup $lname}]
	ckres "Lookup" $status $expcode $res $PASS
  }


# y: XXX how do we simulate some server errors:
#	NFS4ERR_MOVED
# 	NFS4ERR_SERVERFAULT
#	NFS4ERR_RESOURCE
#	NFS4ERR_IO


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
