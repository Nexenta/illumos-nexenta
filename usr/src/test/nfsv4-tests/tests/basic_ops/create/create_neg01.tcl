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
# NFSv4 CREATE operation test - negative tests with creating DIR

# include all test enironment
source CREATE.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: create a new dir without FH, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ndir "noFH.[pid]"
set ASSERTION "Create a new dir without FH, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Create $ndir {{mode 0711}} d; Getfh}]
ckres "Create" $status $expcode $res $PASS


# b: try to create a dir with CFH is not a dir, expect NOTDIR
set expcode "NOTDIR"
set tpath "$BASEDIRS $env(SYMLDIR)"
set ASSERTION "Create a dir with CFH is notdir, expect $expcode"
set tag $TNAME{b}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR);
	Create $ndir {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# c: try to create a dir with CFH/dir has mode=0000, expect ACCESS
set expcode "ACCESS"
set tpath "$BASEDIRS $env(DNOPERM)"
set ASSERTION "Create a dir with CFH has 0 mode, expect $expcode"
set tag $TNAME{c}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DNOPERM);
	Create $ndir {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# d: try to create a dir with objname="xx/xx", expect INVAL
set expcode "INVAL"
set DL $env(DELM)
set ndir "XXX${DL}xxx"
set ASSERTION "Create a dir with objname='xx${DL}xx', expect $expcode"
set tag $TNAME{d}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $ndir {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# e: try to create a dir with name is zero length, expect INVAL
set expcode "INVAL"
set ASSERTION "Create a dir with name is zero length, expect $expcode"
set tag $TNAME{e}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create "" {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# f: create a new dir with name existed; expect EXIST
set expcode "EXIST"
set ndir $env(RWFILE)
set ASSERTION "Create a new dir with name existed, expect $expcode"
set tag $TNAME{f}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create $ndir {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# g: try to create a dir with objname='.', expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Create a dir with objname='.', expect $expcode"
set tag $TNAME{g}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create {.} {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# h: try to create a dir with objname='..', expect INVAL|OK
set expcode "INVAL|OK"
set ASSERTION "Create a dir with objname='..', expect $expcode"
set tag $TNAME{h}
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Create {..} {{mode 0755}} d; Getfh }]
ckres "Create" $status $expcode $res $PASS


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
