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
# NFSv4 ACL attributes:
#
# a: Test removing file owner read/write perms - expect OK
# b: Test restoring file owner read/write perms - expect OK
# c: Test removing file owner read/execute perms - expect OK
# d: Test restoring file owner read/execute perms - expect OK
# e: Test removing file owner write/execute perms - expect OK
# f: Test setting file owner write/execute perms - expect OK
#

set TESTROOT $env(TESTROOT)

# include common code and init section
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} acltools]

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set expcode "OK"

set POSIX_READ_ACL $env(POSIX_READ_ACL)
set POSIX_WRITE_ACL $env(POSIX_WRITE_ACL)
set POSIX_EXECUTE_ACL $env(POSIX_EXECUTE_ACL)
set OWNER_ALLOW_ACL $env(OWNER_ALLOW_ACL)
set GENERIC_DENY_ACL $env(GENERIC_DENY_ACL)

# Get handle for base directory
set bfh [get_fh "$BASEDIRS"]

# Set params relating to test file
set tfile "newfile.[pid]"
set fpath [file join ${BASEDIR} ${tfile}]

# Create the test file with all perms set (-rwxrwxrwx) and get its handle.
set tfh "[creatv4_file $fpath 777]"
if {$tfh == $NULL} {
        putmsg stdout 0 "$TNAME: test setup"
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($tfile)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
}


# Start testing
# ------------------------------------------------------------------------
# a: Test removing file owner read/write perms - expect OK

set tag "$TNAME{a}"
set ASSERTION "Test removing file owner read/write perms  - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask [ concat $POSIX_READ_ACL $POSIX_WRITE_ACL ] ]

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode $initial_acl $FAIL

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set acl_list [extract_acl_list $initial_acl]
putmsg stderr 1 "$tag: initial ACL : $acl_list"

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list [lreplace $acl_list 0 0 "0 0 $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 0 $owner_deny_mask OWNER\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"


# Set the new ACL values.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]


ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $acl_list] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# b: Test restoring file owner read/write perms - expect OK

set tag "$TNAME{b}"
set ASSERTION "Test restoring file owner read/write perms - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

restore_perms $tfh OWNER FILE

# ------------------------------------------------------------------------
# c: Test removing file owner read/execute perms - expect OK

set tag "$TNAME{c}"
set ASSERTION "Test removing file owner read/execute perms - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_WRITE_ACL ] ]

set owner_deny_mask [ aclmask [ concat $POSIX_READ_ACL $POSIX_EXECUTE_ACL ] ]

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode $initial_acl $FAIL

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set acl_list [extract_acl_list $initial_acl]
putmsg stderr 1 "$tag: initial ACL : $acl_list"

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list [lreplace $acl_list 0 0 "0 0 $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 0 $owner_deny_mask OWNER\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Set the new ACL values.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $acl_list] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# d: Test restoring file owner read/execute perms - expect OK

set tag "$TNAME{d}"
set ASSERTION "Test restoring file owner write/execute perms  - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

restore_perms $tfh OWNER FILE

# ------------------------------------------------------------------------
# e: Test removing file owner write/execute perms - expect OK

set tag "$TNAME{e}"
set ASSERTION "Test removing file owner execute perms - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_READ_ACL ] ]

set owner_deny_mask [ aclmask [ concat $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode $initial_acl $FAIL

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set acl_list [extract_acl_list $initial_acl]
putmsg stderr 1 "$tag: initial ACL : $acl_list"

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list [lreplace $acl_list 0 0 "0 0 $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 0 $owner_deny_mask OWNER\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"


# Set the new ACL values.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: new ACL : $acl_list"

	if { [compare_acl_lists $new_acl_list $acl_list] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# f: Test restoring file owner write/execute perms - expect OK

set tag "$TNAME{f}"
set ASSERTION "Test restoring file owner execute perms - expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

restore_perms $tfh OWNER FILE


# ------------------------------------------------------------------------
# Cleanup
#
set tag "$TNAME-cleanup"
set res3 [compound {Putfh $bfh; Remove $tfile}]
if {$status != "OK"} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res3)"
        putmsg stderr 1 "  "
}

Disconnect 
exit $PASS
