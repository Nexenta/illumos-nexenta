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
# Setclientid and setclientid_confirm testing.

# TESTROOT directory; must be set in the environment already
set TESTROOT $env(TESTROOT)

source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} lcltools]

# setting local variables
set TNAME $argv0


# Start testing
# --------------------------------------------------------------

# a: new unique client
set tag $TNAME{a}
Connect
set expct "OK"
set ASSERTION "Setclientid new unique client, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# a1: new unique client
set tag $TNAME{a1}
set ASSERTION "Setclientid_confirm new unique client,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# b: verifier set to 0s
set tag $TNAME{b}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to 0s, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# four words with 0s
set verifier [binary format "S4" {0 0 0 0}]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# b1: verifier set to 0s
set tag $TNAME{b1}
set ASSERTION "Setclientid_confirm verifier set to 0s,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# c: verifier max integer
set tag $TNAME{c}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to max integer, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# four words with 1s
set verifier [binary format "S4" {65535 65535 65535 65535}]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# c1: verifier max integer
set tag $TNAME{c1}
set ASSERTION \
	"Setclientid_confirm verifier set to max integer,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# d: verifier set to alphanumeric characters
set tag $TNAME{d}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to alphanumeric chars, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "ab12ef90"
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# d1: verifier set to alphanumeric characters
set tag $TNAME{d1}
set ASSERTION \
	"Setclientid_confirm verifier set to alphanumeric chars,\n\t\
expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# e: verifier set to alphabetic characters
set tag $TNAME{e}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to alphabetic chars, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "zyxw&:+/"
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# e1: verifier set to alphabetic characters
set tag $TNAME{e1}
set ASSERTION \
	"Setclientid_confirm verifier set to alphabetic chars,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# f: verifier with embeded nulls
set tag $TNAME{f}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier with embeded nulls, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# 0000 FFFF 0000 FFFF
set verifier [binary format "S4" {0 65535 0 65535}]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# f1: verifier with embeded nulls
set tag $TNAME{f1}
set ASSERTION \
	"Setclientid_confirm verifier with embeded nulls,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# g: verifier set to single char
set tag $TNAME{g}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to single char, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# char =0xFF
set verifier [binary format "c" 255]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# g1: verifier set to single char
set tag $TNAME{g1}
set ASSERTION \
	"Setclientid_confirm verifier set to single char,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# h: verifier set to single null char
set tag $TNAME{h}
Connect
set expct "OK"
set ASSERTION "Setclientid verifier set to single null char, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier [binary format "c" 0]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# h1: verifier set to single null char
set tag $TNAME{h1}
set ASSERTION \
	"Setclientid_confirm verifier set to single null char, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# i: verifier set to binary value (all 1s}
set tag $TNAME{i}
Connect
set expct "OK"
set ASSERTION \
	"Setclientid verifier set to binary value (all 1s},\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
# 70 words all with 1s
set verifier [binary format "S70" \
	[split [string range [string repeat "65535 " 70] 0 end-1] " "]]
set owner "$tag"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# i1: verifier set to binary value (all 1s}
set tag $TNAME{i1}
set ASSERTION \
	"Setclientid_confirm verifier set to bin value (all 1s}, \
expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# j: owner set to long string (512 in length)
set tag $TNAME{j}
Connect
set expct "OK"
set ASSERTION \
	"Setclientid owner set to long string (512 in length),\n\t\
expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "[string repeat "a" 512]"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# j1: owner set to long string (512 in length)
set tag $TNAME{j1}
set ASSERTION \
	"Setclientid_confirm owner set to long str (512 length),\n\t\
expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# k: owner set to single char
set tag $TNAME{k}
Connect
set expct "OK"
set ASSERTION "Setclientid owner set to single char, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
# char = 0xFF 
set owner "[binary format "c" 255]"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# k1: owner set to single char
set tag $TNAME{k1}
set ASSERTION "Setclientid_confirm owner set to single char,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# l: owner set to binary value (all 1s}
set tag $TNAME{l}
Connect
set expct "OK"
set ASSERTION "Setclientid owner set to binary value (all 1s},\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
# 70 words all with 1s
set owner "[binary format "S70" \
	[split [string range [string repeat "65535 " 70] 0 end-1] " "]]"
set clientid ""
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# l1: owner set to binary value (all 1s}
set tag $TNAME{l1}
set ASSERTION \
	"Setclientid_confirm owner set to binary value (all 1s},\n\t\
 expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode


# m: send duplicate of setclientid
set tag $TNAME{m}
Connect
set expct "OK"
set ASSERTION "send duplicate of setclientid, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "$tag"
set clientid ""
putmsg stdout 1 "First Setclientid"
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
putmsg stdout 1 "Second Setclientid"
set st [setclient $verifier $owner clientid cverf res]
ckres "Setclientid" $st $expct $res $PASS

# m1: send duplicate of setclientid_confirm
set tag $TNAME{m1}
set expct "OK"
set ASSERTION "send duplicate of setclientid_confirm, expect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
putmsg stdout 1 "First Setclientid_confirm"
if {$st == "OK"} {
        set st [setclientconf $clientid $cverf res]
        putmsg stdout 1 "Second Setclientid_confirm"
        set st [setclientconf $clientid $cverf res]
        set retcode "FAIL"
} else {
        set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode


# --------------------------------------------------------------
# exit

Disconnect

exit $PASS
