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
# NFSv4 READDIR operation test - negative tests
#	verify SERVER errors returned with invalid Getattr.

# include all test enironment
source READDIR.env

Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh $BASEDIRS]

# Start testing
# --------------------------------------------------------------
# a: Readdir without Putrootfh, expect NOFILEHANDLE
set expcode "NOFILEHANDLE"
set ASSERTION "Readdir without Putrootfh, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Readdir 0 0 1024 1024 type}]
ckres "Readdir" $status $expcode $res $PASS


# b: try to Readdir while the obj is removed, expect STALE
set expcode "STALE"
set ASSERTION "try to Readdir while obj is removed, expect $expcode"
#set tag "$TNAME{b}"
#putmsg stdout 0 "$tag: $ASSERTION"
#set tmpd "tmp.[pid]"
#set res [compound {Putfh $bfh; Create $tmpd {{mode 0777}} d; Getfh}]
#set tfh [lindex [lindex $res 2] 2]
#check_op "Putfh $bfh; Remove $tmpd" "OK" "UNINITIATED"
#set res [compound {Putfh $tfh; Readdir 0 0 1024 1024 type; Getfh}]
#ckres "Readdir" $status $expcode $res $PASS
#puts "\t Test UNTESTED: XXX need to remove <cfh> between PUTFH/READDIR\n"


# d: Readdir of of dir0711 as <other>, expect ACCESS
set expcode "ACCESS"
set ASSERTION "Readdir of of dir0711 as <other>, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup $env(DIR0711);
	Readdir 0 0 512 512 mode}]
ckres "Readdir" $status $expcode $res $PASS


# e: Readdir of dir_noperm (mode=000), expect ACCESS
set expcode "ACCESS"
set ASSERTION "Readdir of dir_noperm (mode=000), expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set res [compound {Putfh $bfh; Lookup "$env(DNOPERM)";
	Readdir 0 0 512 1024 named_attr}]
ckres "Readdir" $status $expcode $res $PASS


# m: Readdir with a bad cookie, expect BAD_COOKIE
set expcode "BAD_COOKIE"
set ASSERTION "Readdir with a bad cookie, expect $expcode"
set tag "$TNAME{m}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 88888888888888888
set cookieverf 0
set res [compound {Putfh $bfh; 
	Readdir $cookie $cookieverf 512 2048 change}]
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
	"\t Test UNSUPPORTED: Solaris server does not return $expcode."
} else {
    ckres "Readdir" $status $expcode $res $PASS
}

# n: Readdir with a bad cookieverf, expect BAD_COOKIE
set expcode "BAD_COOKIE"
set ASSERTION "Readdir with a bad cookieverf, expect $expcode"
set tag "$TNAME{n}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 0
set cookieverf 88888888888888888
set res [compound {Putfh $bfh;
	Readdir $cookie $cookieverf 512 2048 fsid}]
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
	"\t Test UNSUPPORTED: Solaris server does not return $expcode."
} else {
    ckres "Readdir" $status $expcode $res $PASS
}

# o1: Readdir w/first cookieverf is non-zero, expect NOT_SAME
set expcode "NOT_SAME"
set ASSERTION "Readdir with first cookieverf non-zero, expect $expcode"
set tag "$TNAME{o1}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 0
set cookieverf 1
set res [compound {Putfh $bfh;
	Readdir $cookie $cookieverf 512 512 {aclsupport case_insensitive}}]
ckres "Readdir" $status $expcode $res $PASS

# o2: Readdir w/corrupted second cookieverf, expect NOT_SAME
set expcode "NOT_SAME"
set ASSERTION "Readdir w/corrupted 2nd cookieverf, expect $expcode"
set tag "$TNAME{o2}"
putmsg stdout 0 "$tag: $ASSERTION"
set cookie 0
set verf 0
set dfh [get_fh "$BASEDIRS $env(LARGEDIR)"]
set res [compound {Putfh $dfh; 
	Readdir $cookie $verf 1024 1024 {size mode}; Getfh}]
if {[ckres "Readdir" $status "OK" $res $FAIL] == "true"} {
    set eof [lindex [lindex $res 1] 4]
    if { $eof != "false" } {
    	putmsg stdout 0 \
	    "\t Test NOTINUSE: $env(LARGEDIR) is to get eof=false"
    } else {
        set rdres [lindex [lindex $res 1] 3]
        set cookie [lindex [lindex $rdres end] 0]
	# get the verifier and corrupt it for testing
	set verf [lindex [lindex $res 1] 2]
	set badverf [string replace $verf 0 2 "77"]
	set res [compound {Putfh $dfh;
		Readdir $cookie $badverf 1024 1024 {type}; Getfh}]
	ckres "Readdir" $status $expcode $res $PASS
    }
}

# q: Readdir w/time_modify_set set, expect INVAL|ATTRNOTSUPP
#    Readdir should fail if request asks for WRITE-only attribute
set expcode "INVAL|ATTRNOTSUPP"
set ASSERTION "Readdir w/time_modify_set attr, expect $expcode"
set tag "$TNAME{q}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "time_modify_set type";
set res [compound {Putfh $bfh; Lookup $env(DIR0777); Getfh;
        Readdir 0 0 2048 2048 $attrs; Getfh}]
putmsg stdout 1 "compound {Putfh $bfh;"
putmsg stdout 1 "\t Lookup $env(DIR0777); Getfh;"
putmsg stdout 1 "\t Readdir 0 0 2048 2048 $attrs; Getfh}"
ckres "Readdir" $status $expcode $res $PASS

# r: Readdir w/time_access_set set, expect INVAL|ATTRNOTSUPP
#    Solaris server would fail the request if it asks for WRITE-only attribute;
#    even though "rdattr_error".
set expcode "INVAL|ATTRNOTSUPP"
set ASSERTION "Readdir w/{time_access_set rdattr_error} attrs, expect $expcode"
set tag "$TNAME{r}"
putmsg stdout 0 "$tag: $ASSERTION"
set attrs "time_access_set rdattr_error";
set res [compound {Putfh $bfh; Lookup $env(DIR0755);
        Readdir 0 0 1024 1024 $attrs; Getfh}]
putmsg stdout 1 "compound {Putfh $bfh; Lookup $env(DIR0755);"
putmsg stdout 1 "\t Readdir 0 0 1024 1024 $attrs; Getfh}"
ckres "Readdir" $status $expcode $res $PASS

# s: Readdir of attrdir w/time_access/modify_set set, expect INVAL|ATTRNOTSUPP
set expcode "INVAL|ATTRNOTSUPP"
set tattrs {"time_access_set aclsupport" "rdattr_error type time_modify_set"};
set i 1
foreach attr $tattrs {
    set tag "$TNAME{s$i}"
    set ASSERTION "Readdir of attrdir w/{$attr} attr, expect $expcode"
    putmsg stdout 0 "$tag: $ASSERTION"
    set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr F;
        Readdir 0 0 1024 1024 $attr; Getfh}]
    putmsg stdout 1 "compound {Putfh $bfh; Lookup $env(ATTRDIR);"
    putmsg stdout 1 "\t Openattr F; Readdir 0 0 40960 2048 $attr; Getfh}"
    ckres "Readdir" $status $expcode $res $PASS
    incr i
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
