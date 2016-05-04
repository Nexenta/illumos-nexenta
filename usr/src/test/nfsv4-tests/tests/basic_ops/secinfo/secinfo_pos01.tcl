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
# NFSv4 SECINFO operation test - positive tests
#   This test assumes system/user has correct KRB5 pricipal setup.

# include all test enironment
source SECINFO.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Secinfo of a regular dir under exported FS, expect OK
set expcode "OK"
set ASSERTION "Secinfo of a regular dir under exported FS, expect $expcode"
putmsg stdout 0 "$TNAME{a}: $ASSERTION"
set res [compound {Putfh $bfh; Secinfo $env(DIR0777)}]
set cont [ckres "Secinfo" $status $expcode $res $FAIL]
# verify the sec-list returned
  if {! [string equal $cont "false"]} {
  	set slist [lindex [lindex $res 1] 2]
  	if {[lsearch -regexp $slist "AUTH_"] == -1} {
            putmsg stderr 0 "\t Test FAIL: did not get expected SEC."
            putmsg stderr 0 "\t            expected=(AUTH_*), got=($slist)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 " "
	} else {
	    logres PASS
	}
  }


# b: Secinfo of a regular file under exported FS, expect OK
set expcode "OK"
set ASSERTION "Secinfo of a regular file under exported FS, expect $expcode"
putmsg stdout 0 "$TNAME{b}: $ASSERTION"
set res [compound {Putfh $bfh; Getfh; Secinfo $env(RWFILE); Getfh}]
set cont [ckres "Secinfo" $status $expcode $res $FAIL]
# verify the sec-list returned
  if {! [string equal $cont "false"]} {
  	set slist [lindex [lindex $res 2] 2]
  	if {[lsearch -regexp $slist "AUTH_"] == -1} {
            putmsg stderr 0 "\t Test FAIL: did not get expected SEC."
            putmsg stderr 0 "\t            expected=(AUTH_*), got=($slist)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 " "
	} else {
	    # verify FH retains its value
	    set fh1 [lindex [lindex $res 1] 2]
	    fh_equal $fh1 $bfh $cont $PASS
	}
  }


# c: Secinfo of a regular exported dir, expect OK
set expcode "OK"
set ASSERTION "Secinfo of a regular exported dir, expect $expcode"
putmsg stdout 0 "$TNAME{c}: $ASSERTION"
set tdir [path2comp $env(SSPCDIR) $env(DELM)]
set bd [lrange $tdir 0 end-1]
set cm [lrange $tdir [llength $bd] end]
set res [compound {Putrootfh; foreach c $bd {Lookup $c}; Secinfo $cm}]
set cont [ckres "Secinfo" $status $expcode $res $FAIL]
# verify the sec-list returned
  if {! [string equal $cont "false"]} {
  	set slist [lindex [lindex $res end] 2]
  	if {[lsearch -regexp $slist "AUTH_"] == -1} {
            putmsg stderr 0 "\t Test FAIL: did not get expected SEC."
            putmsg stderr 0 "\t            expected=(AUTH_*), got=($slist)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 " "
	} else {
	    logres PASS
	}
  }


# e: Secinfo of parent dir '..', expect OK
set expcode "OK"
set ASSERTION "Secinfo of parent dir '..', expect $expcode"
putmsg stdout 0 "$TNAME{e}: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DIR0777)";
	Secinfo ".."}]
set cont [ckres "Secinfo" $status $expcode $res $FAIL]
# verify the sec-list returned
  if {! [string equal $cont "false"]} {
	set slist [lindex [lindex $res end] 2]
	if {[lsearch -regexp $slist "AUTH_"] == -1} {
	    putmsg stderr 0 "\t Test FAIL: did not get expected SEC."
	    putmsg stderr 0 "\t            expected=(AUTH_*), got=($slist)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 " "
	} else {
	    logres PASS
	}
  }


# g: Secinfo of a KRB5 exported dir, expect OK
set expcode "OK"
set ASSERTION "Secinfo of a KRB5 exported dir, expect $expcode"
putmsg stdout 0 "$TNAME{g}: $ASSERTION"
set k5dir [path2comp $env(KRB5DIR) $env(DELM)]
set bd [lrange $k5dir 0 end-1]
set cm [lrange $k5dir [llength $bd] end]
set res [compound {Putrootfh; foreach c $bd {Lookup $c}; Secinfo $cm}]
set cont [ckres "Secinfo" $status $expcode $res $FAIL]
# verify the sec-list returned
  if {! [string equal $cont "false"]} {
  	set slist [lindex [lindex $res end] 2]
  	if {[lsearch -regexp $slist "KRB5"] == -1} {
            putmsg stderr 0 \
		"\t Test NOTINUSE: $SERVER did not setup KRB5 w/($env(KRB5DIR))"
            putmsg stderr 0 "\t            got-SEC=($slist)"
            putmsg stderr 1 "\t   res=($res)"
            putmsg stderr 1 " "
	} else {
	    logres PASS
	}
  }


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
