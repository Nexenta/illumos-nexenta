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
# a: Test setting ACE4_DELETE ACL attr in DENY ace access_mask 
# b: Test setting ACE4_WRITE_OWNER ACL attr in DENY ace access_mask 
# c: Test setting ACE4_WRITE_OWNER ACL attr in ALLOW ace access_mask 
# d: Test setting ACE4_SYNCHRONIZE ACL attr in DENY ace access_mask 
# e: Test setting ACE4_READ_NAMED_ATTRS ACL attr in DENY ace access_mask 
# f: Test setting ACE4_WRITE_NAMED_ATTRS ACL attr in DENY ace access_mask 
# g: Test setting ACE4_DELETE_CHILD ACL attr in ALLOW ace access_mask 
# h: Test setting ACE4_DELETE_CHILD ACL attr in DENY ace access_mask 
# i: Test setting ACE4_WRITE_ACL attr in ALLOW ACE whose "who" field is not "OWNER@"
# j: Test setting ACE4_WRITE_ATTRIBUTES attr in ALLOW ACE whose "who" field is not "OWNER@"
# k: Test setting ACE4_WRITE_DATA attr in ALLOW ACE without ACE4_APPEND_DATA
# l: Test setting ACE4_APPEND_DATA attr in ALLOW ACE without ACE4_WRITE_DATA
# m: Test setting ACE4_WRITE_DATA attr in DENY ACE without ACE4_APPEND_DATA
# n: Test setting ACE4_APPEND_DATA attr in DENY ACE without ACE4_WRITE_DATA
#
# All tests expect ATTRNOTSUPP for UFS, and expect OK for ZFS
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
set expcode_get "OK"
if $IsZFS {
	set expcode_set "OK"
} else {
	set expcode_set "ATTRNOTSUPP"
}

set POSIX_READ_ACL $env(POSIX_READ_ACL)
set POSIX_WRITE_ACL $env(POSIX_WRITE_ACL)
set POSIX_EXECUTE_ACL $env(POSIX_EXECUTE_ACL)
set OWNER_ALLOW_ACL $env(OWNER_ALLOW_ACL)
set GENERIC_ALLOW_ACL $env(GENERIC_ALLOW_ACL)
set GENERIC_DENY_ACL $env(GENERIC_DENY_ACL)

# Set params relating to test file
set filename "newfile.[pid]"
set fpath [file join ${BASEDIR} ${filename}]

# Create the test file and get its handle.
set tfh "[creatv4_file $fpath 777]"
if {$tfh == $NULL} {
        putmsg stdout 0 "$TNAME: test setup"
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp file=($filename)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
}

# Get handle for base directory
set bfh [get_fh "$BASEDIRS"]


# Start testing
# ---------------------------------------------------------------
#a: Test setting ACE4_DELETE ACL attr in DENY ACE 
#	expect ATTRNOTSUPP for UFS 
#	expect OK for ZFS

set tag "$TNAME{a}"
set ASSERTION "Test set ACL access_mask attr ACE4_DELETE in DENY ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_READ_ACL \
$POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_DELETE ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#b: Test set ACL access_mask attr ACE4_WRITE_OWNER in DENY ACE 
#	expect ATTRNOTSUPP for UFS
# 	expect OK for ZFS

set tag "$TNAME{b}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_OWNER in DENY ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_WRITE_OWNER ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS

puts ""

# ---------------------------------------------------------------
#c: Test set ACL access_mask attr ACE4_WRITE_OWNER in ALLOW ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{c}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_OWNER in ALLOW ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat "ACE4_WRITE_OWNER" $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask 0

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS

puts ""
# ---------------------------------------------------------------
#d: Test set ACL access_mask attr ACE4_SYNCHRONIZE in DENY ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{d}"
set ASSERTION "Test set ACL access_mask attr ACE4_SYNCHRONIZE in DENY ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_SYNCHRONIZE ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#e: Test set ACL access_mask attr ACE4_READ_NAMED_ATTRS in DENY ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{e}"
set ASSERTION "Test set ACL access_mask attr ACE4_READ_NAMED_ATTRS \
in DENY ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_READ_NAMED_ATTRS ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#f: Test set ACL access_mask attr ACE4_WRITE_NAMED_ATTRS in DENY ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{f}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_NAMED_ATTRS \
in DENY ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_WRITE_NAMED_ATTRS ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""


# ---------------------------------------------------------------
#g: Test set ACL access_mask attr ACE4_DELETE_CHILD in ALLOW ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{g}"
set ASSERTION "Test set ACL access_mask attr ACE4_DELETE_CHILD in ALLOW ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat "ACE4_DELETE_CHILD" $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask 0

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#h: Test set ACL access_mask attr ACE4_DELETE_CHILD in DENY ACE;  
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{h}"
set ASSERTION "Test set ACL access_mask attr ACE4_DELETE_CHILD in DENY ACE, \
expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask ACE4_DELETE_CHILD ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#i: Test setting ACE4_WRITE_ACL attr in ALLOW ACE whose "who" field is not "OWNER@"
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{i}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_ACL with \"who\" \
not OWNER@ in ALLOW ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set group_allow_mask [ aclmask [ concat "ACE4_WRITE_ACL" $GENERIC_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set group_deny_mask [ aclmask $GENERIC_DENY_ACL ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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
set acl_list [lreplace $acl_list 2 2 "1 40 $group_deny_mask GROUP\@"]
set acl_list [lreplace $acl_list 3 3 "0 40 $group_allow_mask GROUP\@"]
set acl_list [lreplace $acl_list 4 4 "1 40 $group_deny_mask GROUP\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""


# ---------------------------------------------------------------
#j: Test setting ACE4_WRITE_ATTRIBUTES attr in ALLOW ACE whose "who" field is not "OWNER@"
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{j}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_ATTRIBUTES with \"who\", \
not OWNER@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set group_allow_mask [ aclmask [ concat "ACE4_WRITE_ATTRIBUTES" $GENERIC_ALLOW_ACL \
$POSIX_READ_ACL $POSIX_WRITE_ACL $POSIX_EXECUTE_ACL ] ]

set group_deny_mask [ aclmask $GENERIC_DENY_ACL ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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
set acl_list [lreplace $acl_list 2 2 "1 40 $group_deny_mask GROUP\@"]
set acl_list [lreplace $acl_list 3 3 "0 40 $group_allow_mask GROUP\@"]
set acl_list [lreplace $acl_list 4 4 "1 40 $group_deny_mask GROUP\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#k: Test setting ACE4_WRITE_DATA attr in ALLOW ACE without ACE4_APPEND_DATA
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{k}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_DATA without \
ACE4_APPEND_DATA in ALLOW ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

#
# POSIX_WRITE_DATA contains ACE4_WRITE_DATA and ACE4_APPEND_DATA, so 
# rather than use that we use ACE4_WRITE_DATA on its own.
#
set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL "ACE4_WRITE_DATA" $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask 0

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#l: Test setting ACE4_APPEND_DATA attr in ALLOW ACE without ACE4_WRITE_DATA
#	expect ATTRNOTSUPP for UFs
#	expect OK for ZFS

set tag "$TNAME{l}"
set ASSERTION "Test set ACL access_mask attr ACE4_APPEND_DATA without \
ACE4_WRITE_DATA in ALLOW ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

#
# POSIX_WRITE_DATA contains ACE4_WRITE_DATA and ACE4_APPEND_DATA, so 
# rather than use that we use ACE4_APPEND_DATA on its own.
#
set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL \
$POSIX_READ_ACL "ACE4_APPEND_DATA" $POSIX_EXECUTE_ACL ] ]

set owner_deny_mask 0

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#m: Test setting ACE4_WRITE_DATA attr in DENY ACE without ACE4_APPEND_DATA
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{m}"
set ASSERTION "Test set ACL access_mask attr ACE4_WRITE_DATA without \
ACE4_APPEND_DATA in DENY ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask $OWNER_ALLOW_ACL ]

#
# POSIX_WRITE_DATA contains ACE4_WRITE_DATA and ACE4_APPEND_DATA, so 
# rather than use that we use ACE4_WRITE_DATA on its own.
#
set owner_deny_mask [ aclmask [ concat $POSIX_READ_ACL "ACE4_WRITE_DATA" \
$POSIX_EXECUTE_ACL ] ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#n: Test setting ACE4_APPEND_DATA attr in DENY ACE without ACE4_WRITE_DATA
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

set tag "$TNAME{n}"
set ASSERTION "Test set ACL access_mask attr ACE4_APPEND_DATA without \
ACE4_WRITE_DATA in DENY ACE, expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

set owner_allow_mask [ aclmask $OWNER_ALLOW_ACL ]

#
# POSIX_WRITE_DATA contains ACE4_WRITE_DATA and ACE4_APPEND_DATA, so 
# rather than use that we use ACE4_APPEND_DATA on its own.
#
set owner_deny_mask [ aclmask [ concat $POSIX_READ_ACL "ACE4_APPEND_DATA" \
$POSIX_EXECUTE_ACL ] ]

set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status $expcode_get $initial_acl $FAIL

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

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

#
#
#
# Cleanup
#
set tag "$TNAME-cleanup"
set res2 [compound {Putfh $bfh; Remove $filename}]
if {$status != "OK"} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res2)"
        putmsg stderr 1 "  "
        Disconnect
        exit $WARNING
}

Disconnect 
exit $PASS
