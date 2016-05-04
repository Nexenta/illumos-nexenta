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
# e: setclientid_confirm: clientid set to 0s
set tag $TNAME{e}
Connect
set expct "STALE_CLIENTID"
set ASSERTION "setclientid_confirm: clientid set to 0s,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "$tag"
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
# 4 words all set to 0s
set clientid [binary format "s4" {0 0 0 0}]
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# f: setclientid_confirm: clientid set to 1s
set tag $TNAME{f}
Connect
set expct "STALE_CLIENTID"
set ASSERTION "setclientid_confirm: clientid set to 1s,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "$tag"
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
# 4 words all set to 1s
set clientid [binary format "S4" {65535 65535 65535 65535}]
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# h: Setclientid_confirm: clientid set to -1
set tag $TNAME{h}
Connect
set expct "STALE_CLIENTID"
set ASSERTION "Setclientid_confirm: clientid set to -1,\n\texpect $expct"
putmsg stdout 0 "$tag: $ASSERTION"
set verifier "[clock clicks]"
set owner "$tag"
set cverf ""
set st [setclient $verifier $owner clientid cverf res]
set clientid "-1"
if {$st == "OK"} {
	set st [setclientconf $clientid $cverf res]
	set retcode "FAIL"
} else {
	set retcode "UNRESOLVED"
}
ckres "Setclientid_confirm" $st $expct $res $PASS $retcode
Disconnect


# i: generate resource error
#set tag $TNAME{i}
#set expct "RESOURCE"
#set ASSERTION "generate resource error"
#putmsg stdout 0 "$tag: $ASSERTION"
#putmsg stdout 0 "\tTest UNTESTED need server thread to insert problem" 


# --------------------------------------------------------------
# Disconnect and exit

exit $PASS
