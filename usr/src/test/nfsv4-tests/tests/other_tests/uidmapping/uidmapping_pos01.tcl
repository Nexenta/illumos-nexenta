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
set tag $TNAME
set TESTFILE [file join $ROOTDIR "$TNAME"]
set clientid ""
set stateid ""
set seqid ""
set fh [openv4 $TESTFILE clientid stateid seqid]
if { $fh == $NULL } {
	putmsg stderr 0 "\t$TNAME: unable to create temp file."
	exit $UNINITIATED
}


# Start testing
# --------------------------------------------------------------

# d1: known user
set tag $TNAME{d1}
set expct "OK"
set ASSERTION "known user, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "uucp@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# d2: known mapable user id
set tag $TNAME{d2}
set expct "OK"
set ASSERTION "known mapable user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner 4
set group ""
set st [uid_map $fh $stateid owner group res "adm@$domain" ""]
ckres "uid_mapping" $st $expct $res $PASS


# e1: known group
set tag $TNAME{e1}
set expct "OK"
set ASSERTION "known group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "staff@$domain"
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# e2: known mapable group id
set tag $TNAME{e2}
set expct "OK"
set ASSERTION "known mapable group id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group 4
set st [uid_map $fh $stateid owner group res "" "adm@$domain"]
ckres "uid_mapping" $st $expct $res $PASS


# f: known user and group
set tag $TNAME{f}
set expct "OK"
set ASSERTION "known user and group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "nuucp@$domain"
set group "nuucp@$domain"
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# g: unmapped user id
set tag $TNAME{g}
set expct "OK"
set ASSERTION "unmapped user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner 5000000
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# h: unmapped group id
set tag $TNAME{h}
set expct "OK"
set ASSERTION "unmapped group id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group 5000000
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# p1: owner root
set tag $TNAME{p1}
set expct "OK"
set ASSERTION "owner root, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "root@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS
# change owner to be different for next assertion
set owner "nobody@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]


# p2: owner id 0
set tag $TNAME{p2}
set expct "OK"
set ASSERTION "owner id 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner 0
set group ""
set st [uid_map $fh $stateid owner group res "root@$domain" ""]
ckres "uid_mapping" $st $expct $res $PASS


# r1: group root
set tag $TNAME{r1}
set expct "OK"
set ASSERTION "group root, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group "root@$domain"
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS
# change group to be different for next assertion
set owner ""
set group "nobody@$domain"
set st [uid_map $fh $stateid owner group res]


# r2: group id 0
set tag $TNAME{r2}
set expct "OK"
set ASSERTION "group id 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner ""
set group 0
set st [uid_map $fh $stateid owner group res "" "root@$domain"]
ckres "uid_mapping" $st $expct $res $PASS


# t: valid UTF8 in owner
set tag $TNAME{t}
set expct "OK"
set ASSERTION "valid UTF8 in owner, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# values in hex: 
#       7e df 80 ef 80 80 f7 80 80 80 fb 80 80 80 80 fd 80 80 80 80 80 
set enc [encoding system]
set res [encoding system identity]
set owner [exec echo $::env(UTF8_USR)]
append owner "@$domain"
set group ""
set res [encoding system $enc]
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# u: valid UTF8 in group
set tag $TNAME{u}
set expct "OK"
set ASSERTION "valid UTF8 in group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# values in hex: 
#       7e df 80 ef 80 80 f7 80 80 80 fb 80 80 80 80 fd 80 80 80 80 80 
set enc [encoding system]
set res [encoding system identity]
set owner ""
set group [exec echo $::env(UTF8_USR)] 
append group "@$domain"
set res [encoding system $enc]
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# v: user id known only to client
set tag $TNAME{v}
set expct "OK"
set ASSERTION "user id known only to client, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERCID)"
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS


# w1: user known only to server
set tag $TNAME{w1}
set expct "OK"
set ASSERTION "user known only to server, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERS)@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS
# change owner to be different for next assertion
set owner "nobody@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]


# w2: user id known only to server
set tag $TNAME{w2}
set expct "OK"
set ASSERTION "user id known only to server, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERSID)"
set group ""
set st [uid_map $fh $stateid owner group res "$::env(TUSERS)@$domain" ""]
ckres "uid_mapping" $st $expct $res $PASS


# x1: user known only to client with common user id
set tag $TNAME{x1}
set expct "OK"
set ASSERTION "user known only to client with common user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERS2)@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]
ckres "uid_mapping" $st $expct $res $PASS
# change owner to be different for next assertion
set owner "nobody@$domain"
set group ""
set st [uid_map $fh $stateid owner group res]


# x2: common user id with user known only to client
set tag $TNAME{x2}
set expct "OK"
set ASSERTION "common user id with user known only to client, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set owner "$::env(TUSERID)"
set group ""
set st [uid_map $fh $stateid owner group res "$::env(TUSERS2)@$domain" ""]
ckres "uid_mapping" $st $expct $res $PASS


# close file to reuse variables in last part of test
set tag $TNAME.cleanup
set fh [closev4 $TESTFILE $fh $stateid $seqid]
if { $fh == $NULL } {
    putmsg stderr 0 "\tWARNING: unable to close or delete temp file."
}

# --------------------------------------------------------------
# disconnect and exit

disconnect
exit $PASS
