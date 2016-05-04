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
# NFSv4 OPENATTR operation test - negative tests
#	verify SERVER errors returned under error conditions

# include all test enironment
source OPENATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]


# Start testing
# --------------------------------------------------------------
# a: Openattr create at ROFS w/no named_attr dir setup - expect ROFS
set expcode "ROFS"
set ASSERTION "Openattr create at ROFS w/no attrdir setup, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set rfh [get_fh [path2comp $env(ROFSDIR) $DELM]]
if {$rfh == ""} {
    putmsg stdout 0 "\t Test NOTINUSE: ROFSDIR is not setup in server."
} else {
    if { "$env(SRVOS)" == "Solaris" } {
        putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
    } else {
        set res [compound {Putfh $rfh; Lookup $env(RWFILE); Openattr T}]
        ckres "Openattr" $status $expcode $res $PASS
    }
}


# b: Openattr(T) at pseudo node w/no named_attr dir setup - expect ACCESS
set expcode "ACCESS"
set ASSERTION "Openattr(T) at pseudo node w/no attrdir setup, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
} else {
    set Tpath [path2comp $env(SSPCDIR2) $DELM]
    set res [compound {Putrootfh; foreach c $Tpath {Lookup $c};
	Lookupp; Openattr T}]
    ckres "Openattr" $status $expcode $res $PASS
}

# c: OPENATTR create on a FS with no more inode, expect NOSPC
set expcode "NOSPC"
set ASSERTION "OPENATTR create on a FS with no more inode, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
} else {
    set rfh [get_fh [path2comp $env(NSPCDIR) $DELM]]
    if {$rfh == ""} {
        putmsg stdout 0 "\t Test NOTINUSE: NSPCDIR is not setup in server."
    } else {
        set res [compound {Putfh $rfh; Lookup $env(RWFILE); Openattr T}]
        ckres "Openattr" $status $expcode $res $PASS
    }
}

# d: OPENATTR create on a FS with no more quota, expect DQUOT
set expcode "DQUOT"
set ASSERTION "OPENATTR create on a FS with no more quota, expect $expcode"
set tag "$TNAME{d}"
putmsg stdout 0 "$tag: $ASSERTION"
# add check of quota setup for Solaris:
if { "$env(SRVOS)" == "Solaris" } {
    putmsg stdout 0 \
        "\t Test UNSUPPORTED: Solaris server creates ext-attr/dir by default"
} else {
    set qpath [path2comp $env(QUOTADIR) $DELM]
    set res [compound {Putrootfh; foreach c $qpath {Lookup $c};
	Getfh; Lookup "quotas"}]
    set qfh [lindex [lindex $res end-1] 2]
    if {[is_cipso $env(SERVER)]} {
	set RWFILE $env(RWFILE)
	set res [exec zlogin $env(ZONENAME) \
		"su $env(TUSER2) -c \"qfh=$qfh; RWFILE=$RWFILE; \
			export qfh RWFILE; /nfsh /$TNAME\""]
	set status [lindex $res 0]
    } else {
	set res [compound {Putfh $qfh; Lookup $env(RWFILE); Openattr T}]
    }
    ckres "Openattr" $status $expcode $res $PASS
}

# i: OPENATTR(T) w/<cfh> is type of attrdir, expect OK|NOTSUPP
set expcode "OK|NOTSUPP"
set ASSERTION "OPENATTR(T) w/<cfh> is type of attrdir, expect $expcode"
set tag "$TNAME{i}"
putmsg stdout 0 "$tag: $ASSERTION"
# First get the attrdir filehandle:
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr F; Getfh}]
if { [ckres "1st Openattr" $status "OK" $res $FAIL] == "true" } {
    # now try nested Openattr:
    set nfh [lindex [lindex $res 3] 2]
    set res [compound {Putfh $nfh; Openattr T}]
    ckres "Openattr" $status $expcode $res $PASS
}

# j: OPENATTR(F) w/<cfh> is type of namedattr, expect OK|NOTSUPP
set expcode "OK|NOTSUPP"
set ASSERTION "OPENATTR(F) w/<cfh> is type of namedattr, expect $expcode"
set tag "$TNAME{j}"
putmsg stdout 0 "$tag: $ASSERTION"
# First get the attrdir filehandle:
set res [compound {Putfh $bfh; Lookup $env(ATTRDIR); Openattr F; Getfh}]
if { [ckres "1st Openattr" $status "OK" $res $FAIL] == "true" } {
    # now try nested Openattr:
    set nfh [lindex [lindex $res 3] 2]
    set res [compound {Putfh $nfh; Lookup $env(ATTRDIR_AT1); Openattr F}]
    ckres "Openattr" $status $expcode $res $PASS
}


# --------------------------------------------------------------
# disconnect and exit
Disconnect
exit $PASS
