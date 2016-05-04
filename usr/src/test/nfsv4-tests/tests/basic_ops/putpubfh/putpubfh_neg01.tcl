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
# NFSv4 PUTPUBFH operation test - negative tests

# include all test enironment
source PUTPUBFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: putpubfh while the public-FS is shared with krb5, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Putpubfh while the FS is shared with krb5, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
# Need to check for $PUBTDIR to make sure KRB5 is setup in $SERVER
set kpath [path2comp $env(PUBTDIR) $DELM]
set dname [lrange $kpath 0 end-1]
set lname [lrange $kpath end end]
set kfh [get_fh $dname]
set res [compound {Putfh $kfh; Secinfo $lname}]
set slist [lindex [lindex $res 1] 2]
if {[lsearch -regexp $slist "KRB5"] == -1} {
	putmsg stderr 0 \
		"\t Test NOTINUSE: Server has no KRB5 setup w/Public-FS."
} else {
	set res [compound {Putpubfh; Getfh}]
	ckres "Putpubfh" $status $expcode $res $PASS
}


# b: XXX how do we simulate some server errors:
#	NFS4ERR_RESOURCE
# 	NFS4ERR_SERVERFAULT

# c: XXX SERVER has no public FS exported; what should we expect?

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
