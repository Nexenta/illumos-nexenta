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
# TCL procedure for ACCESS operation testing

set DEBUG $env(DEBUG)

#---------------------------------------------------------
# Test procedure to verify ACCESS bit masks
#  Usage: ckaccess access_list explist continue-flag prn-pass
# 	acl:  the access_list to be checked
# 	exp:  the expected access bit to check against the list
#	cont: continue-flag (true|false) if we should continue
#	prn:  flag to indication if PASS message should be printed
#
#  Return: 
#	true:  if all expected bits match
#	false: if the access_list do not match the ck_bits
#
proc ckaccess {acl exp cont prn} {
    global DEBUG

    # stop the verification if 'continue-flag' is FALSE
    if {[string equal $cont "false"]} { return false }

    # parse the access_list list
    set nomatch ""
    set aclist [split $acl ","]
    foreach b [split $exp ""] {
	if {"$b" == "r"} {
	    if {[lsearch -exact $aclist "READ"] == -1} {
		set nomatch [append $nomatch "r"]
	    }
	} elseif {"$b" == "l"} {
	    if {[lsearch -exact $aclist "LOOKUP"] == -1} {
		set nomatch [append $nomatch l]
	    }
	} elseif {"$b" == "m"} {
	    if {[lsearch -exact $aclist "MODIFY"] == -1} {
		set nomatch [append $nomatch m]
	    }
	} elseif {"$b" == "t"} {
	    if {[lsearch -exact $aclist "EXTEND"] == -1} {
		set nomatch [append $nomatch t]
	    }
	} elseif {"$b" == "d"} {
	    if {[lsearch -exact $aclist "DELETE"] == -1} {
		set nomatch [append $nomatch d]
	    }
	} elseif {"$b" == "x"} {
	    if {[lsearch -exact $aclist "EXECUTE"] == -1} {
		set nomatch [append $nomatch x]
	    }
	} else {
            putmsg stderr 0 "\t Test UNRESOLVED: invalid expect bits ($exp)."
	    putmsg stderr 1 "\t   acl=($acl)"
	    putmsg stderr 1 " "
	    return false
	}
    }
    if {$nomatch != ""} {
	putmsg stderr 0 "\t Test FAIL: \[$nomatch\] bit(s) has no match"
	putmsg stderr 1 "\t   acl=($acl)"
	putmsg stderr 1 "\t   exp=($exp)"
	putmsg stderr 1 " "
	return false
    }
    if {$prn == 0} {
	putmsg stdout 0 "\t Test PASS"
    }
    return true
}

