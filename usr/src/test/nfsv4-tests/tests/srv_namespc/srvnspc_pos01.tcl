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
# a: Readdir on rootFH, only see pseudo nodes as dir, expect OK
proc assertion_a {pnode} {
    global TNAME
    set expcode "OK"
    set ASSERTION \
	"Readdir on rootFH, only see pseudo nodes as dir, expect $expcode"
    putmsg stdout 0 "$TNAME{a}: $ASSERTION"
    set tag "$TNAME{a}"

    # First do the compound
    set res [compound {Putrootfh; Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }

    # now check the results
    set rdres [lindex [lindex $res 1] 3]
    set match 0
    foreach entry $rdres {
	set name [lindex $entry 1]
	set type [extract_attr [lindex $entry 2] "type"]
	if {$type != "dir"} {
	    putmsg stderr 0 "\t Test FAIL: invalid pseudo node type=($type)"
	    putmsg stderr 1 "\t   rdres=($rdres)"
	    return (-1)
	}
	if {$name == $pnode} {
		set match 1
	}
    }
    if {$match == 0} {
	putmsg stderr 0 "\t Test FAIL: unable to find pseudo node for BASEDIRS."
	putmsg stderr 1 "\t   pnode=($pnode)"
	return (-1)
    }
    logres PASS
    return (0)
}

# b: Readdir on exported node, see whole dir, expect OK
proc assertion_b {dfh} {
    global env
    global TNAME
    set expcode "OK"
    set ASSERTION "Readdir on exported node, see whole dir, expect $expcode"
    putmsg stdout 0 "$TNAME{b}: $ASSERTION"
    set tag "$TNAME{b}"

    # First do the compound
    set res [compound {Putfh $dfh; Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }

    # now check the results; files should be included
    set rdres [lindex [lindex $res 1] 3]
    set nlist ""
    foreach entry $rdres {
	set name [lindex $entry 1]
	set nlist "$nlist $name"
	set type [extract_attr [lindex $entry 2] "type"]
	if {($name == $env(RWFILE)) && ($type != "reg")} {
            putmsg stderr 0 \
	        "\t Test FAIL: file($name) has type=($type), expected=(reg)"
	    putmsg stderr 1 "\t   rdres=($rdres)"
	    return (-1)
	}
    }
    set ffile "$env(ROFILE)"
    if {[lsearch -exact $nlist "$ffile"] == -1} {
	putmsg stderr 0 "\t Test FAIL: file($ffile) not found in name list."
	putmsg stderr 1 "\t   nlist=($nlist)"
	return (-1)
    }
    logres PASS
    return (0)
}

# c: Readdir on pseudo node has same results w/Lookupp, expect OK
proc assertion_c {bdir nodename} {
    global TNAME
    set expcode "OK"
    set ASSERTION \
	"Readdir on pseudo node has same results w/Lookupp, expect $expcode"
    putmsg stdout 0 "$TNAME{c}: $ASSERTION"
    set tag "$TNAME{c}"

    if {[is_cipso $nodename]} {
	putmsg stderr 0 \
	    "\t Test UNSUPPORTED: Not supported for Trusted Extensions CIPSO"
	putmsg stderr 1 "\t                   nodename=($nodename)"
	return (-1)
    }

    # First Readdir on the pseudo node
    set pnode [lrange $bdir 0 [expr [llength $bdir] - 2]]
    set bdfh [get_fh $pnode]
    set res [compound {Putfh $bdfh; Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: 1st Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    # Save the readdir list
    set rdres1 [lindex [lindex $res 1] 3]

    # Try Readdir again with LOOKUPP from BASEDIR
    set bfh [get_fh $bdir]
    set res [compound {Putfh $bfh; Lookupp; 
	Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: 2nd Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    # Save the readdir list
    set rdres2 [lindex [lindex $res 2] 3]

    # now check the results, both rdres should be the same
    if {"$rdres1" != "$rdres2"} {
	putmsg stderr 0 \
		"\t Test FAIL: 2 Readdir's of same node got different results"
	putmsg stderr 1 "\t   rdres1=($rdres1)"
	putmsg stderr 1 "\t   rdres2=($rdres2)"
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

set dfh [get_fh "$BASEDIRS $env(DIR0777)"]
assertion_b $dfh

assertion_c $BASEDIRS $env(SERVER)


# --------------------------------------------------------------
# disconnect and exit
set tag ""
disconnect
exit $PASS
