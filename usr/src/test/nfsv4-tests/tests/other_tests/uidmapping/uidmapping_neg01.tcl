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

# ROOTDIR directory; must be set in the environment already
set ROOTDIR $env(ROOTDIR)

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

# get file file handle, ROOTDIR is mounted with option root=<this host>
set tag $TNAME.setup
set TESTFILE [file join $ROOTDIR "$TNAME"]
set clientid ""
set stateid ""
set seqid ""
set fh [openv4 $TESTFILE clientid stateid seqid]
if { $fh == $NULL } {
	putmsg stderr 0 "$TNAME{all}:"
	putmsg stderr 0 "\tTest UNINITIATED: unable to create temp file."
	exit $UNINITIATED
}

set orig_attr [getfileowner $fh]
if { $orig_attr == $NULL } {
	putmsg stderr 0 "$TNAME{all}:"
	putmsg stderr 0 "\tTest UNINITIATED: unable to get $TESTFILE attributes"
	exit $UNINITIATED
}

set Oown [lindex $orig_attr 0]
set Ogrp [lindex $orig_attr 1]

# Start testing
# --------------------------------------------------------------

# a: invalid chars in owner
set tag $TNAME{a}
set expct "BADOWNER"
set ASSERTION "invalid chars in owner, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "owner :+\t\n\r@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# b: invalid chars in group
set tag $TNAME{b}
set expct "BADOWNER"
set ASSERTION "invalid chars in group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "group :\t\n\r@$domain"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# c: negative owner id
set tag $TNAME{c}
set expct "BADOWNER"
set ASSERTION "negative owner id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner -1
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# d:  negative group id
set tag $TNAME{d}
set expct "BADOWNER"
set ASSERTION "negative group id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group -1
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# e: overflowed owner id
set tag $TNAME{e}
set expct "BADOWNER"
set ASSERTION "overflowed owner id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner [string repeat "9" 20]
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# f: overflowed group id
set tag $TNAME{f}
set expct "BADOWNER"
set ASSERTION "overflowed group id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group [string repeat "9" 20]
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# g: invalid chars in domain
set tag $TNAME{g}
set expct "BADOWNER"
set ASSERTION "invalid chars in domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "uucp@eng+ :sun\t\n\rcom"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# g1: invalid extra @ char in domain
set tag $TNAME{g1}
set expct "BADOWNER"
set ASSERTION "invalid extra @ char in domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "uucp@@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# h: invalid UTF8 in owner
# 4748963 uid mapping is not checking for invalid chars
set tag $TNAME{h}
set expct "OK"
set ASSERTION "valid UTF8 in owner, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 0 "\tTest UNTESTED: nfsmapid is not enforcing valid UTF8 codes"
# values in hex:
#     df ff ef ff ff f7 ff ff ff fb ff ff ff ff fd ff ff ff ff ff 00 00
#set enc [encoding system]
#set res [encoding system identity]
#set owner [exec echo $::env(BAD_UTF8)]
#append owner "@$domain"
#set group ""
#set res [encoding system $enc]
#set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
#ckres "uid_mapping" $st $expct $res $PASS


# i: invalid UTF8 in group
# 4748963 uid mapping is not checking for invalid chars
set tag $TNAME{i}
set expct "OK"
set ASSERTION "invalid UTF8 in group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 0 "\tTest UNTESTED: nfsmapid is not enforcing valid UTF8 codes"
# values in hex:
#     df ff ef ff ff f7 ff ff ff fb ff ff ff ff fd ff ff ff ff ff 00 00
#set enc [encoding system]
#set res [encoding system identity]
#set owner ""
#set group [exec echo $::env(BAD_UTF8)]
#append group "@$domain"
#set res [encoding system $enc]
#set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
#ckres "uid_mapping" $st $expct $res $PASS


# j: unknown owner
set tag $TNAME{j}
set expct "BADOWNER"
set ASSERTION "unknown owner, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "[ownid j]@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# k: unknown group
set tag $TNAME{k}
set expct "BADOWNER"
set ASSERTION "unknown group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "[grpid k]@$domain"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# l: unknown owner and group
set tag $TNAME{l}
set expct "BADOWNER"
set ASSERTION "unknown owner and group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "[ownid l]@$domain"
set group "[grpid l]@$domain"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# m: known user, known group, no domain sent
set tag $TNAME{m}
set expct "BADOWNER|OK"
set ASSERTION "known user, known group, no domain sent, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "nuucp"
set group "nuucp"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# o: known owner, unknown domain 
set tag $TNAME{o}
set expct "BADOWNER"
set ASSERTION "known owner, unknown domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "uucp@noexist.sun.com"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# p: known group, unknown domain
set tag $TNAME{p}
set expct "BADOWNER"
set ASSERTION "known group, unknown domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "staff@noexist.sun.com"
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# u: user known only to client
set tag $TNAME{u}
set expct "BADOWNER"
set ASSERTION "user known only to client, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERC)@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


# w: user known only to client with common user id
set tag $TNAME{w}
set expct "BADOWNER"
set ASSERTION "user known only to client with common user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERC2)@$domain"
set group ""
set st [uid_map $fh $stateid owner group res $Oown $Ogrp]
ckres "uid_mapping" $st $expct $res $PASS


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

