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
# NFSv4 numbered attributes:
#
# a: Test get attr FATTR4_RAWDEV get major/minor info. of a NF4BLK file,
#    expect OK
# b: Test get attr FATTR4_RAWDEV get major/minor info. of a NF4CHR file,
#    expect OK
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
set expcode "OK"

# Get testfile pathname
set bfh [get_fh "$BASEDIRS"]

# Start testing
# ---------------------------------------------------------------
# a: Test get attr FATTR4_RAWDEV of a NF4BLK file, expect OK

set tag "$TNAME{a}"
set ASSERTION "Test get attr FATTR4_RAWDEV of a NF4BLK file, expect OK"
putmsg stdout 0 "$tag: $ASSERTION"

# Setup attr for testing purposes
set attr {rawdev}

#Get the raw device attr of the NF4BLK special file
#Raw device of this block file should be {77 188} which is defined in \
#    v4test.cfg and implemented in mk_srvdir.ksh file
set res [compound {
	Putfh $bfh;
	Lookup $env(BLKFILE);
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { $cont == "true" } {

	set attrval [ extract_attr [lindex [lindex $res 2] 2] $attr ]

	if { $attrval == "77 188" } {
		putmsg stdout 0 "\t Test PASS"
	} else {
		putmsg stderr 0 "\t Test FAIL: unexpected {$attrval} raw device\
			returned for this block file, it should be {77 188}\
			which is defined in v4test.cfg and implemented in\
			mk_srvdir.ksh file"
		putmsg stderr 1 "\t    res=($res)."
	}
}

# ---------------------------------------------------------------
# b: Test get attr FATTR4_RAWDEV of a NF4CHR file, expect OK

set tag "$TNAME{b}"
set ASSERTION "Test get attr FATTR4_RAWDEV of a NF4CHR file, expect OK"
putmsg stdout 0 "$tag: $ASSERTION"

# Setup attr for testing purposes
set attr {rawdev}

#Get the raw device attr of the NF4CHR special file
#Raw device of this character file should be {88 177} which is defined in \
#    v4test.cfg and implemented in mk_srvdir.ksh file
set res [compound {
	Putfh $bfh;
	Lookup $env(CHARFILE);
	Getattr $attr
}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]

if { $cont == "true" } {

	set attrval [ extract_attr [lindex [lindex $res 2] 2] $attr ]

	if { $attrval == "88 177" } {
		putmsg stdout 0 "\t Test PASS"
	} else {
		putmsg stderr 0 "\t Test FAIL: unexpected {$attrval} raw device\
			returned for this character file, it should be {88 177}\
			which is defined in v4test.cfg and implemented in\
			mk_srvdir.ksh file"
		putmsg stderr 1 "\t    res=($res)."
	}
}

Disconnect
exit $PASS
