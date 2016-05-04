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

# Get the TESTROOT directory;
set TESTROOT $env(TESTROOT)

# include common code and init section
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set expcode "OK"


# Start testing 
# -----------------------------------------------------------------
# a: Verify Solaris server has FATTR4_ACL in supported_attrs list
set ASSERTION "Verify Solaris server has FATTR4_ACL in supported_attrs list"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

# Get a list of the supported attributes
set attr {supported_attrs}
set res [compound { Putfh $bfh; Lookup $env(TEXTFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr($attr)" $status $expcode $res $FAIL]
set ACL_SUPPORT 0

if { ![string equal $cont "false"] } {
    putmsg stdout 1 "\nres=<$res>\n"
    set ffh [lindex [lindex $res 2] 2]
    set slist [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]

    # Verify Solaris has "acl" in the supported_attrs list
    if {($env(SRVOS) == "Solaris")} {
	if { [ lsearch -exact $slist "acl" ] < 0 } {
	    putmsg stdout 0 \
		"\tTest FAIL: did not find <acl> in the supported_attrs list"
	    putmsg stdout 1 "\t\tslist: <$slist>"
	} else {
	    # Attempt Getattr of acl attribute
	    set res2 [compound { Putfh $ffh; Getattr acl }]
    	    set cont [ckres "Getattr/acl" $status $expcode $res2 $FAIL]
	    if {$cont == "true"} {
		putmsg stdout 1 "\nres2=<$res2>\n"
    		set aclres [lindex [lindex [lindex [lindex $res2 1] 2] 0] 1]
		if { [ lsearch -regexp $aclres "OWNER" ] < 0 } {
		    putmsg stdout 0 \
			"\tTest FAIL: Getattr/acl did not return correct ace's?"
		    putmsg stdout 1 "\t\taclres=<$aclres>"
	        } else {
		    putmsg stdout 0 "\tTest PASS"
		    set ACL_SUPPORT 1
		}
	    }
	}
    } else {
	putmsg stdout 0 "\t Test NOTINUSE: unknown acl support for this server."
    }
}


# ----------------------------------------------------------------------
# b: Verify Solaris server has minimum ACL_SUPPORT of a filesystem object
set ASSERTION "Verify Solaris server has minimum ACL_SUPPORT of a FS object"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"

# Based on {a}, "acl" is in the supported_attrs list of Solaris system
# So, we want to verify "aclsupport" will have at least ALLOW+DENY for Solaris.
putmsg stdout 1 "ACL_SUPPORT set from assertion{a} is <$ACL_SUPPORT>\n"
if {($env(SRVOS) == "Solaris")} {
    if { $ACL_SUPPORT != 1 } {
	putmsg stdout 0 \
		"\tTest UNRESOLVED: <acl> is NOT supported well in this server?"
	putmsg stdout 0 \
		"\t\tcheck assertion{a} for possible reason."
    } else {
	# Verify the server should have the minimum ACL support
	# which includes ALLOW_ACL and DENY_ACL
	set res [compound { Putfh $bfh; Getattr aclsupport }]
	set cont [ckres "Getattr" $status $expcode $res $FAIL]
	if { ![string equal $cont "false"] } {
		set ALLOW_ACL 1
		set DENY_ACL 2
		set minsupp [expr $ALLOW_ACL | $DENY_ACL]
		set aclsupp [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
		putmsg stdout 1 "\tres=<$res>"
		putmsg stdout 1 "\tminsupp=<$minsupp>, aclsupp=<$aclsupp>"
		if { [expr $aclsupp & $minsupp] != $minsupp } {
        		putmsg stdout 0 \
			    "\tTest FAIL: aclsupport does not have min support"
        		putmsg stdout 0 \
			   "\t\taclsupp=$<aclsupp>, expected minsupp=<$minsupp>"
		} else {
        		putmsg stdout 0 "\tTest PASS"
		}
	}
    }
} else {
    putmsg stdout 0 "\t Test NOTINUSE: unknown acl support for this server."
}


# ----------------------------------------------------------------------
# c: Verify archive attr is not in the supported_list of Solaris server
set ASSERTION "Verify ARCHIVE is not in supported_list of Solaris server"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set ARCHIVE_SUPPORT 0

# Get a list of the supported attributes
set attr {supported_attrs}
set res [compound { Putfh $bfh; Lookup $env(EXECFILE); Getfh; Getattr $attr }]
set cont [ckres "Getattr($attr)" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
    putmsg stdout 1 "\nres=<$res>\n"
    set ffh [lindex [lindex $res 2] 2]
    set slist [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    set attr2 {archive}

    # Verify Solaris does not have "archive" in the supported_attrs list
    if {($env(SRVOS) == "Solaris")} {
	if { [ lsearch -exact $slist $attr2 ] < 0 } {
	    # Attempt Getattr of this non-supported attribute
	    set res2 [compound { Putfh $ffh; Getattr $attr2 }]
    	    set cont [ckres "Getattr/$attr2" $status $expcode $res2 $FAIL]
	    if {$cont == "true"} {
		putmsg stdout 1 "\nres2=<$res2>\n"
    		set alist [lindex [lindex $res2 1] 2]
		if { [ lsearch -regexp $alist $attr2 ] < 0 } {
		    putmsg stdout 0 "\tTest PASS"
	        } else {
		    putmsg stdout 0 \
			"\tTest FAIL: Getattr/$attr returned unexpected value"
		    putmsg stdout 1 "\t\talist=<$alist>"
		}
	    }
	} else {
	    putmsg stdout 0 \
		"\tTest FAIL: Solaris server does not support <$attr2>"
	    putmsg stdout 0 \
		"\t\t but found <$attr2> in the supported_attrs list"
	    putmsg stdout 1 "\t\tslist: <$slist>"
	    set ARCHIVE_SUPPORT 1
	}
    } else {
	putmsg stdout 0 \
		"\t Test NOTINUSE: unknown $attr2 support for this server."
	set ARCHIVE_SUPPORT 2
    }
}

# ----------------------------------------------------------------------
# d: Verify Solaris server return false to FATTR4_CASE_INSENSITIVE
set ASSERTION "Verify Solaris server return false to FATTR4_CASE_INSENSITIVE"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"

set CASE_SUPPORT 0

# Get a list of the supported attributes
set attr {supported_attrs}
set res [compound { Putfh $bfh; Lookup $env(DIR0711); Getfh; Getattr $attr }]
set cont [ckres "Getattr($attr)" $status $expcode $res $FAIL]

if { ![string equal $cont "false"] } {
    putmsg stdout 1 "\nres=<$res>\n"
    set ffh [lindex [lindex $res 2] 2]
    set slist [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]
    set attr2 {case_insensitive}

    # CASE_INSENSITIVE should be in supported_attrs list to return a value
    if {($env(SRVOS) == "Solaris")} {
	if { [ lsearch -exact $slist $attr2 ] < 0 } {
	    putmsg stdout 0 \
		"\tTest FAIL: <$attr2> is expected to be in Solaris server's"
	    putmsg stdout 0 \
	"\t\t supported_attrs list, to return FALSE value; but didn't find it."
	    putmsg stdout 1 "\t\tslist: <$slist>"
	} else {
	    # Attempt Getattr of this attribute to check the value
	    set res2 [compound { Putfh $ffh; Getattr $attr2 }]
    	    set cont [ckres "Getattr/$attr2" $status $expcode $res2 $FAIL]
	    if {$cont == "true"} {
		putmsg stdout 1 "\nres2=<$res2>\n"
    		set cival [lindex [lindex [lindex [lindex $res2 1] 2] 0] 1]
		if { [string compare -nocase $cival "false"] == 0} {
		    putmsg stdout 0 "\tTest PASS"
		    set CASE_SUPPORT 1
	        } else {
		    putmsg stdout 0 \
			"\tTest FAIL: Getattr/$attr2 returned unexpected value"
		    putmsg stdout 0 \
			"\t\t cival=<$cival>, expected=<false>"
		}
	    }
	}
    } else {
	putmsg stdout 0 \
		"\t Test NOTINUSE: unknown $attr2 support for this server."
    }
}


# Verify server doesn't allow SETATTR of read-only attributes
set expcode "INVAL"

# ----------------------------------------------------------------------
# e: Verify server returns INVAL if Setattr of <aclsupport> attr (readonly)
set ASSERTION "Try to Setattr{aclsupport}; expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"

if { $ACL_SUPPORT == 1 } {
	# send a SETATTR request to "aclsupport" attribute
	set res [compound { Putfh $bfh; Setattr {0 0} {{aclsupport "true"}} }]
	ckres "Setattr(aclsupport)" $status $expcode $res $PASS
} else {
    	putmsg stdout 0 "\t Test NOTINUSE: acl is not supported by this server."
}


# ----------------------------------------------------------------------
# f: Verify server returns INVAL if Setattr of <case_insensitive> attr
set ASSERTION "Try to Setattr{case_insensitive}; expect $expcode"
set tag "$TNAME{f}"
putmsg stdout 0 "$tag: $ASSERTION"

if { $CASE_SUPPORT == 1 } {
	# send a SETATTR request to "aclsupport" attribute
	set res [compound { Putfh $bfh; \
		Setattr {0 0} {{case_insensitive "true"}} }]
	ckres "Setattr(aclsupport)" $status $expcode $res $PASS
} else {
    	putmsg stdout 0 \
	"\t Test NOTINUSE: case_insensitive is not supported by this server."
}


# Test server behaves if we try to SETATTR of read-only attributes
set expcode "ATTRNOTSUPP"

# ----------------------------------------------------------------------
# g: Verify server returns ATTRNOSUPP if Setattr of <archive> attr (readonly)
set ASSERTION "Try to Setattr{archive,RO_attr}; expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"

if { $ARCHIVE_SUPPORT == 0 } {
	# send a SETATTR request to "archive" attribute
	set res [compound { Putfh $bfh; Lookup $env(RWFILE); \
		Setattr {0 0} {{archive "false"}}; Getattr $attr }]
	ckres "Setattr(archive)" $status $expcode $res $PASS
} else {
    	putmsg stdout 0 \
	"\t Test NOTINUSE: support for ARCHIVE attr is unknown at this server."
}


Disconnect 
exit $PASS 
