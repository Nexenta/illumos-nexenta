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
# NFSv4 VERIFY operation test - negative tests
#	verify SERVER returned NFSERR_SAME in different cases

# include all test enironment
source VERIFY.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set req_attrs "type fh_expire_type change size link_support
    symlink_support named_attr fsid unique_handles lease_time"

# Start testing
# --------------------------------------------------------------
# a: Verify of a file w/attr=dir, expect NOT_SAME
set expcode "NOT_SAME"
set ASSERTION "Verify of a file w/attr=dir, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(RWFILE); Getfh;
	Verify {{type dir}}; Getfh}]
ckres "Verify" $status $expcode $res $PASS


# b: Verify a file with diff supported attrs, expect NOT_SAME
set expcode "NOT_SAME"
set ASSERTION "Verify a file with diff supported attrs, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(ZIPFILE); Getattr "$req_attrs"}]
set cont [ckres "Getattr" $status "OK" $res $FAIL]
# Verify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# Let's change the "size"
	set si [lsearch -regexp $attrl "size .*"]
	set nal [lreplace $attrl $si $si {size 0}]
	# do a verify on these attributes
	set res [compound {Putfh $bfh; Lookup $env(ZIPFILE); Getfh;
		Verify {$nal}; Getfh}]
	ckres "Verify" $status $expcode $res $PASS
  }


# c: Verify a symlink with diff other attrs, expect NOT_SAME
set expcode "NOT_SAME"
set ASSERTION "Verify a symlink with diff other attrs, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set ckl "type size cansettime chown_restricted fileid files_avail files_free
	files_total homogeneous maxfilesize maxlink maxname maxread maxwrite 
	mode no_trunc numlinks owner owner_group"
set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Getattr "$ckl"}]
set cont [ckres "Getattr" $status "OK" $res $FAIL]
# Verify all attr returned from Getattr
  if {! [string equal $cont "false"]} {
  	set attrl [lindex [lindex $res 2] 2]
	# Let's change the "size"
	set si [lsearch -regexp $attrl "size .*"]
	set nal [lreplace $attrl $si $si {size 0}]
	# do a verify on these attributes
	set res [compound {Putfh $bfh; Lookup $env(SYMLDIR); Getfh;
		Verify {$nal}; Getfh}]
	ckres "Verify" $status $expcode $res $PASS
  }


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
