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
# UID Mapping testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

if {[info exists env(DNS_SERVER)] == 1} {
	set domain [get_domain $env(SERVER) $env(DNS_SERVER)]
} else {
	set domain [get_domain $env(SERVER)]
}
if {$domain == $NULL} {
	putmsg stderr 0 "\t$TNAME: unable to determine the domain."
	putmsg stderr 0 "\tAssertions won't be executed."
	exit $UNINITIATED
}

# connect to the test server
Connect


set attrs {owner owner_group}

# get file file handle
set tag $TNAME.setup
set TESTFILE [file join $BASEDIR "$TNAME"]
set clientid ""
set stateid ""
set seqid ""
set fh [openv4 $TESTFILE clientid stateid seqid]
if { $fh == $NULL } {
	putmsg stderr 0 "\t$TNAME: unable to create temp file."
	putmsg stderr 0 "\tAssertions a to d won't be executed."
	exit $UNINITIATED
}

set orig_attr [getfileowner $fh]
if { $orig_attr == $NULL } {
        putmsg stderr 0 "$TNAME{all}:"
        putmsg stderr 0 "\tTest UNINITIATED: unable to get $TESTFILE attributes"        exit $UNINITIATED
}

set Oown [lindex $orig_attr 0]
set Ogrp [lindex $orig_attr 1]

# Start testing
# --------------------------------------------------------------

# assertions to test PERM errors
#(trying to change owner/group without root access)


# a: owner root
set tag $TNAME{a}
set expct "PERM"
set ASSERTION "owner root, no root access, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "root@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# b: owner id 0
set tag $TNAME{b}
set expct "PERM|BADOWNER"
set ASSERTION "owner id 0, no root access, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner 0
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# c: group rooc
set tag $TNAME{x}
set expct "PERM"
set ASSERTION "group root, no root access, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "root@$domain"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# d: group id 0
set tag $TNAME{d}
set expct "PERM|BADOWNER"
set ASSERTION "group id 0, no root access, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group 0
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# xxx: embedded NULL in owner
# xxy: embedded NULL in group
# nfsv4shell reads internally owner and owner_group using strcpy
# so even that "binary format" can created strings with embedded
# NULLs, nfsv4shell will truncate them. XXX future improvement needed.


# close file
set tag $TNAME.cleanup
set fh [closev4 $TESTFILE $fh $stateid $seqid]
if { $fh == $NULL } {
    putmsg stderr 0 "\tWARNING: unable to close or delete temp file."
}

# --------------------------------------------------------------
# disconnect and exit

Disconnect
exit $PASS

