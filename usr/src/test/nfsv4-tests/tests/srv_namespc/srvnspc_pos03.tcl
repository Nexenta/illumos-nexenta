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
# NFSv4 server name space test - positive tests
#

# include all test enironment
source SNSPC.env

set TNAME $argv0

# Start the assertion proc's here
# --------------------------------------------------------------
# a: pseudo node's attrs are subset of supported_attrs, expect OK
proc assertion_a {bdir} {
    global TNAME
    set expcode "OK"
    set ASSERTION \
	"pseudo node's attrs are subset of supported_attrs, expect $expcode"
    putmsg stdout 0 "$TNAME{a}: $ASSERTION"

    # First Get supported_attr from pseudo node
    set pnode [lrange $bdir 0 [expr [llength $bdir] - 2]]
    set pfh [get_fh $pnode]
    set res [compound {Putfh $pfh; Getattr supported_attrs}]
    if {$status != "$expcode"} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: Getattr pseudo node got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set psattrs [lindex [lindex [lindex $res 1] 2] 1]

    # Now get supported_attr from exported_FS node
    set bfh [get_fh $bdir]
    set res [compound {Putfh $bfh; Getattr supported_attrs}]
    if {$status != "$expcode"} {
	putmsg stderr 0 \
	    "\t Test UNRESOLVED: Getattr exported_FS node got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set rsattrs [lindex [lindex [lindex $res 1] 2] 1]

    # now check the results
    set notmatch ""
    foreach entry $psattrs {
	if {[lsearch -exact $rsattr $entry] == -1} {
	    set notmatch "$notmatch $entry"
	}
    }
    if {$notmatch != ""} {
        putmsg stderr 0 \
	    "\t Test FAIL: attrs from pseudo node not found in supported_attrs:"
        putmsg stderr 0 "\t            notmatch=($notmatch)"
	return (-1)
    }

    logres PASS
    return (0)
}


# b: Getattr of unsupported_attrs in pseudo node, expect OK
proc assertion_b {bdir} {
    global TNAME
    set expcode "OK"
    set ASSERTION \
	"Getattr of unsupported_attrs in pseudo node, expect $expcode"
    putmsg stdout 0 "$TNAME{b}: $ASSERTION"

    # First Get supported_attr from pseudo node
    set pnode [lrange $bdir 0 [expr [llength $bdir] - 2]]
    set pfh [get_fh $pnode]
    set res [compound {Putfh $pfh; Getattr supported_attrs}]
    if {$status != "$expcode"} {
	putmsg stderr 0 \
	    "\t Test UNRESOLVED: Getattr supported_attrs got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set psattrs [extract_attr [lindex [lindex $res 1] 2] "supported_attrs"]

    # check if "hidden" as the supported_attr
    set ss_attr "hidden"
    if {[lsearch -exact $psattrs $ss_attr] >= 0} {
        putmsg stderr 0 \
	    "\t Test NOTINUSE: attr($ss_attr) in supported in pseudo node."
	putmsg stderr 0 "\t   res=($res)"
        return (2)
    }

    # now do the GETATTR, should be OK, but no attribute returned
    set res [compound {Putfh $pfh; Getattr $ss_attr}]
    if {$status != "$expcode"} {
	putmsg stderr 0 \
	    "\t Test FAIL: Getattr $ss_attr got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set attrs [lindex [lindex $res 1] 2]
    if {$attrs != ""} {
        putmsg stderr 0 \
	    "\t Test FAIL: attr($ss_attr) from pseudo node got attr returned"
        putmsg stderr 0 "\t            res=($res)"
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

assertion_a $BASEDIRS
assertion_b $BASEDIRS


# --------------------------------------------------------------
# disconnect and exit
disconnect
exit $PASS
