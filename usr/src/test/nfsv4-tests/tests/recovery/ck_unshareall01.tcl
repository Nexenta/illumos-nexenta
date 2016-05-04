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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 unsharell test using nfsv4shell
#

# include all test enironment
source RECOV_proc

set TNAME $argv0

# connect to the test server
Connect

# First check this test is not started before previous tests
# grace period ends.
set ckgrace [file join $MNTPTR wait_for_grace]
exec echo "wait_for_grace tmp file" > $ckgrace
exec rm -f $ckgrace

# Start the assertions here
# --------------------------------------------------------------
# a: Putrootfh after server unshareall, expect SERVERFAULT
set expcode "SERVERFAULT"
set ASSERTION "Putrootfh after server unshareall, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"

# First a compound to check we can READDIR at root
set res [compound {Putrootfh; Readdir 0 0 1024 8192 {type filehandle}; Getfh}]
if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: First readdir got status=($status)"
	putmsg stderr 0 "\t                  expected=(OK)"
	putmsg stderr 1 "\t   res=($res)"
} else {
    set nfh [lindex [lindex $res 2] 2]

    # Now run a program to have $SERVER unshareall
    putmsg stderr 1 "  exec $SRVPROG unshare"
    set TmpFile [file join $env(TMPDIR) $TNAME.tmp.[pid]]
    if {[catch {exec $SRVPROG "unshare" 2> $TmpFile} out]} {
	putmsg stderr 0 "\t Test UNRESOLVED: failed to unshareall at $SERVER"
	putmsg stderr 0 "\t   out=($out)"
	if { $DEBUG > 1 } {
		if {[catch {open $TmpFile} fd]} {
    			putmsg stderr 1 "  Cannot open $TmpFile: $fd"
		} else {
			read $fd
			close $fd
		}
	}
    } else {
        putmsg stderr 1 "  out=($out)"
    	# Now the test of sending a Putrootfh compound
    	set res [compound {Putrootfh; Readdir 0 0 1024 8192 {type filehandle}}]
    	ckres "Putrootfh" $status $expcode $res $PASS

	# b: Putfh of an FH after server unshareall, expect STALE
	set expcode "STALE"
	set ASSERTION \
	    "Putfh of an old FH after server unshareall, expect $expcode"
	set tag "$TNAME{b}"
	putmsg stdout 0 "$tag: $ASSERTION"

    	set res [compound {Putfh $nfh; Readdir 0 0 1024 8192 {mode}}]
    	ckres "Putfh" $status $expcode $res $PASS
    }
}

# Finally reshareall from $SERVER 
putmsg stderr 1 "  exec $SRVPROG share"
if {[catch {exec $SRVPROG "share" 2> $TmpFile} out]} {
	putmsg stderr 0 "\t WARNING: failed to shareall again at $SERVER"
	putmsg stderr 0 "\t          next test maybe affected."
	putmsg stderr 1 "  out=($out)"
	if { $DEBUG > 1 } {
		if {[catch {open $TmpFile} fd]} {
    			putmsg stderr 1 "  Cannot open $TmpFile: $fd"
		} else {
			read $fd
			close $fd
		}
	}
} else {
	putmsg stderr 1 "  out=($out)"
}

# --------------------------------------------------------------
# cleanup, disconnect and exit
file delete $TmpFile
set tag ""
Disconnect
exit $PASS
