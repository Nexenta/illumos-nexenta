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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# NFSv4 CREATE operation test - negative tests
#	Test NOSPC/DQUOT/ROFS, need special FSs support

# include all test enironment
source CREATE.env

# connect to the test server
Connect


# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Create a dir when FS has no more quota, expect DQUOT
set expcode "DQUOT"
set ASSERTION "Create while target FS has no more quota, expect $expcode"
set tag $TNAME{a}
putmsg stdout 0 "$tag: $ASSERTION"
set qpath [path2comp $env(QUOTADIR) $DELM]
set res [compound {Putrootfh; foreach c $qpath {Lookup $c}; 
	Getfh; Lookup "quotas"}]
# add check of quota setup for Solaris:
if {($env(SRVOS) == "Solaris") && ($status == "NOENT")} {
	putmsg stdout 0 "\t Test NOTINUSE: QUOTA is not setup in server."
} else {
	set qfh [lindex [lindex $res end-1] 2]
	# Under cipso in Trusted Extension, we do "Create" operation 
	# for QUOTA in non-global zone
	if {[is_cipso $env(SERVER)]} {
		set res [exec zlogin $env(ZONENAME) \
			"su $env(TUSER2) -c \"export qfh=$qfh; /nfsh /$TNAME\""]
		set status [lindex $res 0]
	} else {
		set res [compound {Putfh $qfh; Create "qd.[pid]" {{mode 777}} d}]
	}
	ckres "Create" $status $expcode $res $PASS
}

# c: try to Create when FS has no more inode, expect NOSPC
set expcode "NOSPC"
set ASSERTION "Create while target FS has no more inode, expect $expcode"
set tag $TNAME{c}
putmsg stdout 0 "$tag: $ASSERTION"
set nsfh [get_fh [path2comp $env(NSPCDIR) $DELM]]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: NOSPC-FS is not setup in server."
} else {
	set res [compound {Putfh $nsfh; Create "nd.[pid]" {{mode 777}} d}]
	ckres "Create" $status $expcode $res $PASS
}


# h: try to Create when FS is READONLY, expect ROFS
set expcode "ROFS"
set ASSERTION "Create while target FS is READONLY, expect $expcode"
set tag $TNAME{h}
putmsg stdout 0 "$tag: $ASSERTION"
set rofh [get_fh [path2comp $env(ROFSDIR) $DELM]]
if {$rofh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: ROFS is not setup in server."
} else {
	set res [compound {Putfh $rofh; Create "d2.[pid]" {{mode 777}} d}]
	ckres "Create" $status $expcode $res $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
