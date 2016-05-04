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
# NFSv4 PUTROOTFH operation test - negative tests

# include all test enironment
source PUTROOTFH.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0

# Start testing
# --------------------------------------------------------------
# a: putrootfh while the FS is shared w/krb5, expect WRONGSEC
set expcode "WRONGSEC"
set ASSERTION "Putrootfh while root-FS is shared with krb5, expect $expcode"
#putmsg stdout 0 "$TNAME{a}: $ASSERTION"
# XXX how to check for ROOTFS to make sure KRB5 is setup in $SERVER
#putmsg stderr 0 "\t Test UNTESTED: XXX need to share w/KRB5 on root"


# b: XXX how do we simulate some server errors:
#	NFS4ERR_RESOURCE
# 	NFS4ERR_SERVERFAULT

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
