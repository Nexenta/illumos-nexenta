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
# TCL procedure for LINK operation testing

set DEBUG $env(DEBUG)

#---------------------------------------------------------
# Test procedure to verify the numlinks attribute of the file
#  Usage: linkcnt_equal lcnt1 objfh continue-flag prn-pass
# 	lcnt1: number of numlinks use to compare
# 	objfh: the FH of the obj to be compared with
#	cont:  continue-flag (true|false) if we should continue
#	prn:   flag to indication if PASS message should be printed
#
#  Return: 
#	true:  if numlinks are equal
#	false: if lcnt1 and numlinks(ckobj) are not equal, or 
#	       something failed in the process.
#
proc linkcnt_equal {lcnt1 objfh cont prn} {
    global DEBUG

    # stop the verification if 'continue-flag' is FALSE
    if {[string equal $cont "false"]} { return false }

    set res [compound {Putfh $objfh; Getattr numlinks}]
    if {"$status" != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: Unable to get objfh(numlinks)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    return false
    }
    set lcnt2 [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    if {$lcnt1 != $lcnt2} {
	if {$prn == 0} {
	    # do not print error in case user want to compare with NOT-equal
	    putmsg stderr 0 "\t Test FAIL: link count are not equal."
	    putmsg stderr 1 "\t   lcnt1=($lcnt1)"
	    putmsg stderr 1 "\t   lcnt2=($lcnt2)"
	    putmsg stderr 1 "  "
        }
	return false
    } else {
	if {$prn == 0} {
		putmsg stdout 0 "\t Test PASS"
	}
	return true
    }
}


#---------------------------------------------------------
# Test procedure to set maxlink to an object
#  Usage: set_maxlink objfh ldirfh
# 	objfh:  the FH of the obj to be compared with
# 	ldirfh: the FH of the directory where links to be created
#
#  Return: 
#	$malx: the value of maxlink if all created successfully
#	false: if something failed during the process.
#
proc set_maxlink {objfh ldirfh} {
    global DEBUG

    # first get the system's maxlink value
    set res [compound {Putfh $objfh; Getattr maxlink}]
    if {"$status" != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: Unable to get objfh(maxlink)"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    return false
    }
    set maxl [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    set i 1
    while {$i <= $maxl && "$status" == "OK"} {
	    set res [compound {Putfh $objfh; Savefh; Putfh $ldirfh; Link L$i}]
	    incr i
    }
    if {$i < $maxl && "$status" != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: failed to create $maxl links"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    return false
    }
    return $maxl
}


#---------------------------------------------------------
# Test procedure to cleanup the links to an object
#  Usage: cleanup_links objfh ldirfh continue-flag
# 	objfh:  the FH of the obj to be compared with
# 	ldirfh: the FH of the directory where links to be created
#	cont:   continue-flag (true|false) if we should continue
#
#  Return: 
#	true:  maxlink removed successfully
#	false: if something failed during the process.
#
proc cleanup_links {maxl ldirfh cont} {
    global DEBUG

    # stop the verification if 'continue-flag' is FALSE
    if {[string equal $cont "false"]} { return false }

    set i 1; set status OK
    while {$i <= $maxl && "$status" == "OK"} {
	    set res [compound {Putfh $ldirfh; Remove L$i}]
	    incr i
    }
    if {$i < $maxl && "$status" != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: failed to Remove $maxl links"
	    putmsg stderr 1 "\t   res=($res)"
	    putmsg stderr 1 "  "
	    return false
    }
    return true
}
