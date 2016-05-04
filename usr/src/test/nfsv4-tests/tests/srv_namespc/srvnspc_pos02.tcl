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

# proc to recursively list the directory hierachy
proc dolist { fh } {
    set cookie 0
    set eof false
    while { $eof != "true" } {
        set res [compound { Putfh $fh; Readdir $cookie 0 1024 1024 {type} }]
        if {$status != "OK"} {
	    return "$status $res"
        }
        set readdirres [ lindex $res 1 ]
        set eof [ lindex $readdirres 4 ]
        set dirlist [ lindex $readdirres 3 ]

	# Examine each entry in the directory
        foreach entry $dirlist {
            set cookie [ lindex $entry 0 ]
            set name   [ lindex $entry 1 ]
            set attrs  [ lindex $entry 2 ]
            set type   [ extract_attr $attrs "type" ]

            # If the entry is a directory, invoke the
            # procedure recursively.
            if {$type == "dir"} {
	        set res [compound { Putfh $fh; Lookup $name; Getfh }]
	        if {$status != "OK"} {
		    return "$status $res"
	        }
		set fh2 [ lindex [lindex $res 2] 2]
                dolist $fh2
            }
        }
    }
    return "OK"
}

# Start the assertion proc's here
# --------------------------------------------------------------
# a: Walk down path thru pseudo & exported nodes, expect OK
#    the 'ssnpd' would have crossing mount & export points.
proc assertion_a {path} {
    global TNAME
    set expcode "OK"
    set ASSERTION \
	"Walk down the path thru pseudo & exported nodes, expect $expcode"
    putmsg stdout 0 "$TNAME{a}: $ASSERTION"
    set tag "$TNAME{a}"

    set res [dolist [get_fh $path]]
    if {"[lindex $res 0]" != "$expcode"} {
	putmsg stderr 0 "\t Test FAIL: unable to dolist."
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }

    logres PASS
    return (0)
}


# b: Verify mount point crossing, expect OK
#    the 'ssnpd' would have crossing mount & export points.
proc assertion_b {ssnpd} {
    global TNAME
    global BASEDIRS
    set expcode "OK"
    set ASSERTION "Verify mount point crossing, expect $expcode"
    putmsg stdout 0 "$TNAME{b}: $ASSERTION"
    set tag "$TNAME{b}"

    # Do the compound to LOOKUP thru the path with crossing mount points
    # starts to traverse from the BASEDIR.
    set save_spc ""
    set fh [get_fh $BASEDIRS]
    foreach d "[lrange $ssnpd [llength $BASEDIRS] end]" {
        set res [compound {Putfh $fh; Readdir 0 0 1024 8192 {type filehandle};
		Lookup $d; Getattr {space_avail}; Getfh}]
        if {$status != "$expcode"} {
	    putmsg stderr 0 \
		"\t Test UNRESOLVED: compound of <$d> got status=($status)"
	    putmsg stderr 0 "\t                  expected=($expcode)"
	    putmsg stderr 1 "\t   res=($res)"
	    return (-1)
	}

	# check FH in crossing mount points
	set rdres [lindex [lindex $res 1] 3]
	set spc [extract_attr [lindex [lindex $res 3] 2] "space_avail"]
	foreach entry $rdres {
	    set attr [lindex $entry 2]
	    set type [extract_attr $attr "type"]

	    # The crossing mount point should be a 'dir'
	    # and the space_avail value will be different from its parent.
	    if {($spc != "") && ($spc != $save_spc) && ($type == "dir")} {
		set name [lindex $entry 1]
		if {$name == $d} {
		    set dfh [extract_attr $attr "filehandle"]
		    # Filehandles are different from crossing mnt & its parent
		    if {$dfh == $fh} {
			putmsg stderr 0 \
		"\t Test FAIL: <$d> crossing mnt-point, but FHs are the same"
			putmsg stderr 1 "\t   fh=($fh)"
			putmsg stderr 1 "\t   dfh=($dfh)"
			return (-1)
		    }
		}
	    }
	}
	set save_spc $spc
	set fh [lindex [lindex $res 4] 2]
    }

    logres PASS
    return (0)
}


# c: Check fsid for crossing filesystems, expect OK
proc assertion_c {bdir rofs} {
    global TNAME
    set expcode "OK"
    set ASSERTION "Check fsid for crossing filesystems, expect $expcode"
    putmsg stdout 0 "$TNAME{c}: $ASSERTION"
    set tag "$TNAME{c}"

    # First Get fsid pseudo node and BASEDIR
    set pnode [lrange $bdir 0 [expr [llength $bdir] - 2]]
    set pfh [get_fh $pnode]
    set rfh [get_fh $rofs]
    if {"$rfh" == ""} {
	# no such filesystem setup in server, exit the test
	putmsg stderr 0 \
		"\t Test NOTINUSE: ROFS is not setup in server."
	return (2)
    }
    set res [compound {Putfh $pfh; Getattr fsid;
		Putfh $rfh; Getattr fsid}]
    if {$status != "$expcode"} {
	putmsg stderr 0 \
		"\t Test UNRESOLVED: Getattr got status=($status)"
	putmsg stderr 0 \
		"\t                  expected=($expcode)"
	putmsg stderr 1 "\t   res=($res)"
	return (-1)
    }
    set pfsid [lindex [lindex [lindex [lindex $res 1] 2] 0] 1]
    set rfsid [lindex [lindex [lindex [lindex $res 3] 2] 0] 1]

    # Check the fsid's, should be different
    if {$pfsid == $rfsid} {
        putmsg stderr 0 \
	    "\t Test FAIL: fsid on 2 diff_FSs are the same."
	putmsg stderr 1 "\t   res=($res)"
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

assertion_a "[path2comp $env(SSPCDIR) $env(DELM)]"
assertion_b "[path2comp $env(SSPCDIR3) $env(DELM)]"
assertion_c $BASEDIRS [path2comp $env(ROFSDIR) $env(DELM)]


# --------------------------------------------------------------
# disconnect and exit
set tag ""
disconnect
exit $PASS
