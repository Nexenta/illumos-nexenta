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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 named attributes:
#
# a: Try to do CREATE op of symlink in named attr directory, expect INVAL 
#

set TESTROOT $env(TESTROOT)
set delm $env(DELM)

# include common code and init section
source ${TESTROOT}${delm}tcl.init
source ${TESTROOT}${delm}testproc

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set expcode "INVAL|NOTSUPP"

# Start testing
# ------------------------------------------------------------------------
# a: Try to do CREATE op of symlink in named attr directory, expect INVAL 
set ASSERTION \
    "Try to do CREATE op of symlink in named attr directory, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"

set nlnk "newlnk"
set LFILE $env(ATTRFILE_AT1)
# Create symlink in named attr directory
set res [compound { 
	Putfh $bfh;
	Lookup $env(ATTRFILE);
	Getfh;
	Openattr T;
	Create $nlnk {{mode 0777}} l $LFILE }]
ckres "Create" $status $expcode $res $PASS

Disconnect 
exit 0
