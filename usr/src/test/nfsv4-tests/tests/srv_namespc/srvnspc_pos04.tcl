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
# a: Verify LOOKUPP across mount point, expect OK
proc assertion_a {bdir} {
    global TNAME
    set expcode "OK"
    set ASSERTION "Verify LOOKUPP across mount point, expect $expcode"
    putmsg stdout 0 "$TNAME{a}: $ASSERTION"
    set tag "$TNAME{a}"

    # First Readdir on the mount point
    set mfh [get_fh $bdir]
    set res [compound {Putfh $mfh; Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: 1st Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    # Save the readdir list
    set rdres1 [lindex [lindex $res 1] 3]

    # Try Readdir again with LOOKUPP the node
    set mnode [lrange $bdir [expr [llength $bdir] - 1] end]
    set res [compound {Putfh $mfh; Lookupp; 
		Lookup $mnode; Readdir 0 0 1024 8192 {type rdattr_error}}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test UNRESOLVED: 2nd Readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    # Save the readdir list
    set rdres2 [lindex [lindex $res 3] 3]

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


# b: Verify walk backward with LOOKUPP, thru mnt/export/pseudo nodes, expect OK
proc assertion_b {bdir nodename} {
    global TNAME
    set expcode "OK"
    set ASSERTION "LOOKUPP backward thru mnt/export/pseudo nodes"
    set ASSERTION "$ASSERTION, expect $expcode"
    putmsg stdout 0 "$TNAME{b}: $ASSERTION"
    set tag "$TNAME{b}"

    if {[is_cipso $nodename]} {
	putmsg stderr 0 \
	    "\t Test UNSUPPORTED: Not supported for Trusted Extensions CIPSO"
	putmsg stderr 1 "\t                   nodename=($nodename)"
	return (-1)
    }

    # First walk up the path (which has exported/mounted/pseudo) with LOOKUPP
    set efh [get_fh $bdir]
    set ncomp [llength $bdir]
    set res [compound {Putfh $efh; 
	foreach c $bdir {Lookupp; Readdir 0 0 1024 8192 {type rdattr_error}};
	Getfh}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: LOOKUPP got status=($status)"
	putmsg stderr 0 "\t            expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set newfh [lindex [lindex $res end] 2]
    set rootfh [get_fh {}]
    if {$newfh != "$rootfh"} {
	putmsg stderr 0 "\t Test FAIL: LOOKUPP to top, filehandle is different"
	putmsg stderr 1 "\t            rootfh=($rootfh)"
	putmsg stderr 1 "\t            newfh=($newfh)"
	return (-1)
    }

    logres PASS
    return (0)
}


# c: Verify LOOKUP of FS unshared sees underlying dir, expect OK
proc assertion_c {bdir nsnode} {
    global TNAME
    global env
    set expcode "OK"
    set ASSERTION "LOOKUP of FS unshared sees underlying dir, expect $expcode"
    putmsg stdout 0 "$TNAME{c}: $ASSERTION"
    set tag "$TNAME{c}"

    # Lookup the unshared filesystem to see the underlying directory
    set bfh [get_fh $bdir]
    set res [compound {Putfh $bfh; Lookup $nsnode; Getattr type; Getfh}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: LOOKUP ($nsnode) got status=($status)"
	putmsg stderr 0 "\t            expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set dtype [lindex [lindex [lindex [lindex $res 2] 2] 0] 1]
    if {$dtype != "dir"} {
	putmsg stderr 0 "\t Test FAIL: GETATTR type of $nsnode is not dir"
	putmsg stderr 0 "\t            got dtype=($dtype)"
	putmsg stderr 1 "\t            res=($res)"
	return (-1)
    }

    # For Solaris, client is now allowed to access this directory 
    # regardless its (mode) permission
    if {$env(SRVOS) == "Solaris"} {
	set nfh [lindex [lindex $res 3] 2]
        set res [compound {Putfh $nfh; Readdir 0 0 256 256 {size rdattr_error}}]
	if {$status != "ACCESS"} {
	    putmsg stderr 0 "\t Test FAIL: READDIR did not fail with ACCESS"
	    putmsg stderr 0 "\t            got status=($status)"
	    putmsg stderr 1 "\t            res=($res)"
	    return (-1)
	}
	set res [compound {Putfh $nfh; Create ${TNAME}_c {{mode 0777}} d}]
	if {$status != "ACCESS"} {
	    putmsg stderr 0 "\t Test FAIL: Create/dir did not fail with ACCESS"
	    putmsg stderr 0 "\t            got status=($status)"
	    putmsg stderr 1 "\t            res=($res)"
	    return (-1)
	}
    }

    logres PASS
    return (0)
}


# d: Verify SECINFO of FS unshared OK with underlying dir, expect OK
proc assertion_d {bdir nsnode} {
    global TNAME
    global env
    set expcode "OK"
    set ASSERTION "SECINFO of FS unshared OK with underlying dir"
    set ASSERTION "$ASSERTION, expect $expcode"
    putmsg stdout 0 "$TNAME{d}: $ASSERTION"
    set tag "$TNAME{d}"

    # Secinfo the unshared filesystem and the underlying directory
    set bfh [get_fh $bdir]
    set res [compound {Putfh $bfh; Secinfo $nsnode; Getfh}]
    if {$status != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: Secinfo got status=($status)"
	putmsg stderr 0 "\t            expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set newfh [lindex [lindex $res 2] 2]
    if {$newfh != "$bfh"} {
	putmsg stderr 0 "\t Test FAIL: after SECINFO filehandles are different"
	putmsg stderr 1 "\t            newfh=($newfh)"
	putmsg stderr 1 "\t            bfh=($bfh)"
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

set nspath "[path2comp $env(NOTSHDIR) $DELM]"
set nsnode [lrange $nspath [expr [llength $nspath] - 1] end]

assertion_a "[path2comp $env(SSPCDIR2) $DELM]"
assertion_b "[path2comp $env(SSPCDIR3) $DELM]" $env(SERVER)
assertion_c "$BASEDIRS" $nsnode
assertion_d "$BASEDIRS" $nsnode


# --------------------------------------------------------------
# disconnect and exit
set tag ""
disconnect
exit $PASS
