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
# NFSv4 OPEN operation test - more of negative tests
# 	Test DQUOT/NOSPC/ROFS, need special FSs setup/support

# include all test enironment
source OPEN.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]
set cid [getclientid $TNAME.[pid]]
if {$cid == -1} {
	putmsg stdout 0 "$TNAME: test setup - getclientid"
	putmsg stderr 0 "\t Test UNRESOLVED: unable to get clientid"
	exit $UNRESOLVED
}
set seqid 1
set owner "$TNAME-OpenOwner"


# Start testing
# --------------------------------------------------------------
# a: Open(CREATE) with user has no more quota, expect DQUOT
set expcode "DQUOT"
set ASSERTION "Open(CREATE) with user has no more quota, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set qpath [path2comp $env(QUOTADIR) $DELM]
set res [compound {Putrootfh; foreach c $qpath {Lookup $c};
	Getfh; Lookup "quotas"}]
# add check of quota setup for Solaris:
if {($env(SRVOS) == "Solaris") && ($status == "NOENT")} {
	putmsg stdout 0 "\t Test NOTINUSE: QUOTA is not setup in server."
} else {
	set qfh [lindex [lindex $res end-1] 2]
	set tf "file_$env(TUSER2).a"
	if {[is_cipso $env(SERVER)]} {
		# Under cipso in Trusted Extension, we do "Open" operation
        	# for QUOTA in non-global zone
		set res [exec zlogin $env(ZONENAME) \
			"su $env(TUSER2) -c \"qfh=$qfh; seqid=$seqid; \
				cid=$cid; owner=$owner; tf=$tf; \
				export qfh seqid cid owner tf; \
				/nfsh /$TNAME\""]
		set status [lindex $res 0]
	} else {
		set res [compound {Putfh $qfh;
			Open $seqid 3 0 "$cid $owner-a" \
			    {1 0 {{mode 0644}}} {0 "$tf"}; Getfh}]
	}
	ckres "Open" $status $expcode $res $PASS
}


# c: Open(CREATE/UNCHECKED) w/FS has no more inode, expect NOSPC
set expcode "NOSPC"
set ASSERTION "Open(CREATE/UNCHECKED) w/FS has no more inode, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set nspcdir [path2comp $env(NSPCDIR) $DELM]
set nsfh [get_fh $nspcdir]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: NOSPC-FS is not setup in server."
} else {
	set res [compound {Putrootfh; foreach c $nspcdir {Lookup $c};
		Open $seqid 3 0 "$cid $owner-c" \
		    {1 0 {{mode 0644}}} {0 "$TNAME-c"}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}


# d: Open(CREATE/GUARDED) w/FS has no more disk, expect NOSPC
set expcode "NOSPC"
set ASSERTION "Open(CREATE/GUARDED) w/FS has no more disk, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
set nsfh [get_fh $nspcdir]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: NOSPC-FS is not setup in server."
} else {
	set res [compound {Putrootfh; foreach c $nspcdir {Lookup $c};
		Open $seqid 3 0 "$cid $owner-d" \
		    {1 1 {{mode 0666} {size 0}}} {0 "$TNAME-d"}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}


# e: Open(CREATE/GUARDED) w/FS is Read-Only, expect ROFS
set expcode "ROFS"
set ASSERTION "Open(CREATE/GUARDED) w/FS is Read-Only, expect $expcode"
set tag "$TNAME{e}"
putmsg stdout 0 "$tag: $ASSERTION"
set rofsdir [path2comp $env(ROFSDIR) $DELM]
set nsfh [get_fh $rofsdir]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: ROFS is not setup in server."
} else {
	set res [compound {Putrootfh; foreach c $rofsdir {Lookup $c};
		Open $seqid 3 0 "$cid $owner-e" \
		    {1 1 {{mode 0666} {size 10}}} {0 "$TNAME-e"}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}

# g: Open(non-CREATE/access=W) in the Read-Only filesystem, expect ROFS
set expcode "ROFS"
set ASSERTION "Open(non-CREATE/acces=W) w/FS is Read-Only, expect $expcode"
set tag "$TNAME{g}"
putmsg stdout 0 "$tag: $ASSERTION"
set nsfh [get_fh $rofsdir]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: ROFS is not setup in server."
} else {
	set res [compound {Putrootfh; foreach c $rofsdir {Lookup $c};
		Open $seqid 2 0 "$cid $owner-g" \
		    {0 0 {{mode 0666}}} {0 "$env(RWFILE)"}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}

# h: Open(non-CREATE/access=RW) in the Read-Only filesystem, expect ROFS
set expcode "ROFS"
set ASSERTION "Open(non-CREATE/acces=RW) w/FS is Read-Only, expect $expcode"
set tag "$TNAME{h}"
putmsg stdout 0 "$tag: $ASSERTION"
set nsfh [get_fh $rofsdir]
if {$nsfh == ""} {
	putmsg stdout 0 "\t Test NOTINUSE: ROFS is not setup in server."
} else {
	set res [compound {Putrootfh; foreach c $rofsdir {Lookup $c};
		Open $seqid 3 0 "$cid $owner-h" \
		    {0 0 {{mode 0666}}} {0 "$env(ROFILE)"}; Getfh}]
	ckres "Open" $status $expcode $res $PASS
}

# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
