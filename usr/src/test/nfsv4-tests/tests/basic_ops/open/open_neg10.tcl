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
# NFSv4 OPEN operation test - negative tests
#	Verify server returns correct BADOWNER errors.

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


# a: unknown owner
set tag $TNAME{a}
set expct "BADOWNER"
set ASSERTION "unknown owner, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "[ownid j]@$domain"
set group ""
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# b: unknown group
set tag $TNAME{b}
set expct "BADOWNER"
set ASSERTION "unknown group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner ""
set group "[grpid k]@$domain"
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# c: unknown owner and group
set tag $TNAME{c}
set expct "BADOWNER"
set ASSERTION "unknown owner and group, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "[ownid l]@$domain"
set group "[grpid l]@$domain"
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# d: known user, known group, no domain sent
set tag $TNAME{d}
set expct "BADOWNER|OK"
set ASSERTION "known user, known group, no domain sent, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "nuucp"
set group "nuucp"
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# e: known owner, unknown domain 
set tag $TNAME{e}
set expct "BADOWNER"
set ASSERTION "known owner, unknown domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "uucp@noexist.sun.com"
set group ""
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# f: known group, unknown domain
set tag $TNAME{f}
set expct "BADOWNER"
set ASSERTION "known group, unknown domain, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner ""
set group "staff@noexist.sun.com"
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# k: user known only to client
set tag $TNAME{k}
set expct "BADOWNER"
set ASSERTION "user known only to client, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "$::env(TUSERC)@$domain"
set group ""
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# m: user known only to client with common user id
set tag $TNAME{m}
set expct "BADOWNER"
set ASSERTION "user known only to client with common user id, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set filename $tag
set TESTFILE [file join $ROOTDIR "$filename"]
set owner "$::env(TUSERC2)@$domain"
set group ""
set st [uid_open $fh $filename $clientid owner group res]
ckres "Open" $st $expct $res $PASS


# --------------------------------------------------------------
# disconnect and exit

Disconnect
exit $PASS
