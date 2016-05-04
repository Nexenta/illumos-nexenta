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
# NFSv4 NVERIFY operation test - negative tests
#	verify SERVER returned NFSERR_SAME in different cases

# include all test enironment
source NVERIFY.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set req_attrs "type fh_expire_type change size link_support
    symlink_support named_attr fsid unique_handles lease_time"

# Start testing
# --------------------------------------------------------------
# a: Nverify a file with same supported attrs, expect SAME
set expcode "SAME"
set ASSERTION "Nverify a file with same supported attrs, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ZIPFILE); Getattr "$req_attrs"}]
set cont [ckres "Getattr" $status "OK" $res $FAIL]
# Nverify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# do a nverify on these attributes
	set res [compound {Putfh $bfh; Lookup $env(ZIPFILE); Getfh;
		Nverify {$attrl}; Getfh}]
	ckres "Nverify" $status $expcode $res $PASS
  }


# b: Nverify a symlink with same other attrs, expect SAME
set expcode "SAME"
set ASSERTION "Nverify a symlink with same other attrs, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set ckl "type size cansettime chown_restricted fileid files_avail files_free
	files_total homogeneous maxfilesize maxlink maxname maxread maxwrite 
	mode no_trunc numlinks owner owner_group"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Getattr "$ckl"}]
set cont [ckres "Getattr" $status "OK" $res $FAIL]
# Nverify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# do a nverify on these attributes
	set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Getfh;
		Nverify {$attrl}; Getfh}]
	ckres "Nverify" $status $expcode $res $PASS
  }

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
