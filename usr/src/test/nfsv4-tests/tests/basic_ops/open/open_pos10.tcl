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
# NFSv4 OPEN operation test - positive tests

# include all test enironment
source OPEN.env
source OPEN_proc

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

# ROOTDIR directory; must be set in the environment already
set ROOTDIR $env(ROOTDIR)

source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0

if {[info exists env(DNS_SERVER)] == 1} {
	set domain [get_domain $env(SERVER) $env(DNS_SERVER)]
} else {
	set domain [get_domain $env(SERVER)]
}
if {$domain == $NULL} {
	putmsg stderr 0 "$TNAME{all}:"
        putmsg stderr 0 "\tTest UNINITIATED: unable to determine the domain."
        putmsg stderr 0 "\tAssertions won't be executed."
        exit $UNINITIATED
}

# connect to the test server
Connect

set tag $TNAME.setup
set ROOTDIRS [path2comp $ROOTDIR $::DELM]
set fh [get_fh $ROOTDIRS]

set clientid [getclientid $TNAME.[pid]]
if {$clientid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}


# Start testing
# --------------------------------------------------------------


# a: known mapable user id
set tag $TNAME{a}
set expct "OK"
set ASSERTION "known mapable user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner 5
set group ""
set st [uid_open $fh $filename $clientid owner group res "root@$domain" ""]
ckres "Open" $st $expct $res $PASS


# b: known mapable group id
set tag $TNAME{b}
set expct "OK"
set ASSERTION "known mapable group id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner ""
set group 5
set st [uid_open $fh $filename $clientid owner group res "" "uucp@$domain"]
ckres "Open" $st $expct $res $PASS


# c: owner id 0
set tag $TNAME{c}
set expct "OK"
set ASSERTION "owner id 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner 0
set group ""
set st [uid_open $fh $filename $clientid owner group res "root@$domain" ""]
ckres "Open" $st $expct $res $PASS


# d: group id 0
set tag $TNAME{d}
set expct "OK"
set ASSERTION "group id 0, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner ""
set group 0
set st [uid_open $fh $filename $clientid owner group res "" "root@$domain"]
ckres "Open" $st $expct $res $PASS


# e: user id known only to server
set tag $TNAME{e}
set expct "OK"
set ASSERTION "user id known only to server, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "$::env(TUSERSID)"
set group ""
set st [uid_open $fh $filename $clientid owner group res "root@$domain" ""]
ckres "Open" $st $expct $res $PASS


# --------------------------------------------------------------
# disconnect and exit

Disconnect
exit $PASS
