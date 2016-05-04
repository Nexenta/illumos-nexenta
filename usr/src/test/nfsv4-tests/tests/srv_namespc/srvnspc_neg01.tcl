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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 server name space test - negative tests
#

# include all test enironment
source SNSPC.env

set TNAME $argv0

# Start the assertion proc's here
# --------------------------------------------------------------
# a: Verify not able to Create dir in pseudo node, expect ROFS
proc assertion_a {pnode} {
    global TNAME BASEDIR
    set expcode "ROFS"
    set ASSERTION \
	"Verify not able to Create dir in pseudo node, expect $expcode"
    putmsg stdout 0 "$TNAME{a}: $ASSERTION"

    # First do the compound
    if {"/$pnode" == "$BASEDIR"} {
	set res [compound {Putrootfh; Getfh}]
	set pfh [lindex [lindex $res end] 2]
    } else {
	set pfh [get_fh $pnode]
    }
    set newD "newD.[pid]"
    set res [compound {Putfh $pfh; Create $newD {{mode 0777}} d}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: compound got status=($status)"
	putmsg stderr 0 "\t            expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }

    # Verify directory is not created
    set res [compound {Putfh $pfh; Lookup $newD}]
    if {$status != "NOENT"} {
	putmsg stderr 0 "\t Test FAIL: new dir exist after Create failed" 
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }

    logres PASS
    return (0)
}


# b: Verify not able to Setattr in pseudo node, expect ROFS
proc assertion_b {pnode} {
    global TNAME BASEDIR
    set expcode "ROFS"
    set ASSERTION \
	"Verify not able to Setattr in pseudo node, expect $expcode"
    putmsg stdout 0 "$TNAME{b}: $ASSERTION"

    # First do the compound
    if {"/$pnode" == "$BASEDIR"} {
	set res [compound {Putrootfh; Getfh}]
	set pfh [lindex [lindex $res end] 2]
    } else {
	set pfh [get_fh $pnode]
    }
    set nmode 765
    set res [compound {Putfh $pfh; Getattr mode; Setattr {0 0} {{mode $nmode}}}]
    set stat1 $status
    set omode [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    # Verify the node's mode was not changed, if changed,
    # recover it before exiting for other tests
    set res [compound {Putfh $pfh; Getattr mode}]
    set nmode [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    if {$stat1 != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: compound got status=($status)"
	putmsg stderr 0 "\t            expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	if {$omode != $nmode} {
	    set res [compound {Putfh $pfh; Getattr mode; Setattr {0 0} {{mode $omode}}}]
	    if {$status != "OK"} {
		putmsg stderr 0 "\t failed to recover the original mode, this may cause"
		putmsg stderr 0 "\t other tests failed."
		putmsg stderr 1 "\t   res=($res)"
	    }
	}
	return (-1)
    }

    if {$omode != $nmode} {
	putmsg stderr 0 \
	    "\t Test FAIL: pseudo node's mode was changed after Setattr failed" 
	putmsg stderr 1 "\t   res=($res)"
	set res [compound {Putfh $pfh; Getattr mode; Setattr {0 0} {{mode $omode}}}]
	if {$status != "OK"} {
	    putmsg stderr 0 "\t failed to recover the original mode, this may cause"
	    putmsg stderr 0 "\t other tests failed."
	    putmsg stderr 1 "\t   res=($res)"
	}
	return (-1)
    }

    logres PASS
    return (0)
}


# Start the main program here
# --------------------------------------------------------------
# connect to the test server
if {[catch {connect -p ${PORT} -t ${TRANSPORT} ${SERVER}} msg]} {
	putmsg stderr 0 "Test UNINITIATED: unable to connect to $SERVER"
	putmsg stderr 1 $msg
	exit $UNINITIATED
}

set pnode [lindex $BASEDIRS 0]
assertion_a $pnode
assertion_b $pnode


# --------------------------------------------------------------
# disconnect and exit
disconnect
exit $PASS
