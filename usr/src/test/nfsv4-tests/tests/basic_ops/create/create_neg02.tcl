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
# NFSv4 CREATE operation test - negative tests with creating other file types

# include all test enironment
source CREATE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: create a new fifo without FH, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set nobj "noFH.[pid]"
set ASSERTION "Create a new fifo without FH, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Create $nobj {{size 22}} f; Getfh}]
ckres "Create" $status $expcode $res $PASS


# b: create a new link with objname existed; expect EXIST
set expcode "EXIST"
set nobj $env(DIR0777)
set ASSERTION "Create a new link with objname existed, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; 
	Create $nobj {{mode 0644}} l $env(DIR0777); Getfh }]
ckres "Create" $status $expcode $res $PASS


# c: try to create an obj while dir removed, expect STALE
set expcode "STALE"
set ASSERTION "Create an obj while dir removed, expect $expcode"
set tag $TNAME{c}
#putmsg stdout 0 "$tag: $ASSERTION"
#puts "\t Test UNTESTED: XXX need hook to remove <cfh> in server\n"


# d: try to create a sock with longname, expect NAMETOOLONG
set expcode "NAMETOOLONG"
set tobj [set_maxname $bfh]
set ASSERTION "Create a sock with longname, expect $expcode"
set tag $TNAME{d}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $tobj {{mode 0666}} s; Getfh }]
ckres "Create" $status $expcode $res $PASS


# e: try to create an obj with type=NF4REG; expect BADTYPE
set expcode "BADTYPE"
set tobj "reg.[pid]"
set ASSERTION "Create an obj with type=NF4REG, expect $expcode"
set tag $TNAME{e}
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Create $tobj {{mode 0700}} r; Getfh }]
#ckres "Create" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need nfsv4shell/nfs4_prot.x to support badtype.\n"


# f: try to create an obj with FH expired, expect FHEXPIRED
set expcode "FHEXPIRED"
set tobj "$BASEDIRS XXX need nfsv4shell to support"
set ASSERTION "Create an obj with FH expired, expect $expcode"
set tag $TNAME{f}
#putmsg stdout 0 "$tag: $ASSERTION"
#set res [compound {Putfh $bfh; Create $tobj {{mode 0777}} d; Getfh }]
#ckres "Create" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need server hook on FH expired.\n"


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
