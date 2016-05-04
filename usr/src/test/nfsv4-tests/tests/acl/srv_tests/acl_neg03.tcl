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
# a: Test set ACL WHO attr to INTERACTIVE@; return ATTRNOTSUPP 
# b: Test set ACL WHO attr to NETWORK@; return ATTRNOTSUPP 
# c: Test set ACL WHO attr to DIALUP@; return ATTRNOTSUPP 
# d: Test set ACL WHO attr to BATCH@; return ATTRNOTSUPP 
# e: Test set ACL WHO attr to ANONYMOUS@; return ATTRNOTSUPP 
# f: Test set ACL WHO attr to AUTHENTICATED@; return ATTRNOTSUPP 
# g: Test set ACL WHO attr to SERVICE@; return ATTRNOTSUPP 
# These tests return ATTRNOTSUPP for ufs, and return BADOWNER for zfs 

set TESTROOT $env(TESTROOT)

# include common code and init section
source [file join ${TESTROOT} tcl.init]
source [file join ${TESTROOT} testproc]
source [file join ${TESTROOT} acltools]

# connect to the test server
Connect

# setting local variables
set TNAME $argv0

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

# Generate default access masks. 
set default_allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
ACE4_READ_ACL ACE4_READ_NAMED_ATTRS ACE4_READ_DATA \
ACE4_APPEND_DATA ACE4_WRITE_DATA ACE4_WRITE_NAMED_ATTRS ACE4_EXECUTE } ]

set default_deny_mask [ aclmask { ACE4_WRITE_ATTRIBUTES ACE4_WRITE_ACL} ]

set expcode_get "OK" 
if $IsZFS { 
	set expcode_set "BADOWNER" 
} else { 
	set expcode_set "ATTRNOTSUPP" 
} 

# Start testing
# ---------------------------------------------------------------
#a: Test set ACL WHO attr to INTERACTIVE@; 

set tag "$TNAME{a}"
set ASSERTION "Test set ACL WHO attr to INTERACTIVE@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask INTERACTIVE\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask INTERACTIVE\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS

puts ""

# ---------------------------------------------------------------
#b: Test set ACL WHO attr to NETWORK@; 

set tag "$TNAME{b}"
set ASSERTION "Test set ACL WHO attr to NETWORK@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask NETWORK\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask NETWORK\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#c: Test set ACL WHO attr to DIALUP@; 

set tag "$TNAME{c}"
set ASSERTION "Test set ACL WHO attr to DIALUP@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask DIALUP\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask DIALUP\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#d: Test set ACL WHO attr to BATCH@; 

set tag "$TNAME{d}"
set ASSERTION "Test set ACL WHO attr to BATCH@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask BATCH\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask BATCH\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]


ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#e: Test set ACL WHO attr to ANONYMOUS@; 

set tag "$TNAME{e}"
set ASSERTION "Test set ACL WHO attr to ANONYMOUS@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask ANONYMOUS\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask ANONYMOUS\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]


ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#f: Test set ACL WHO attr to AUTHENTICATED@; 

set tag "$TNAME{f}"
set ASSERTION "Test set ACL WHO attr to AUTHENTICATED@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask ANONYMOUS\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask ANONYMOUS\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

# ---------------------------------------------------------------
#g: Test set ACL WHO attr to SERVICE@; 

set tag "$TNAME{g}"
set ASSERTION "Test set ACL WHO attr to SERVICE@ expect $expcode_set"
putmsg stdout 0 "$tag: $ASSERTION"

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

# Create the new ACL settings by modifying the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
# For these tests we add a new WHO group to the end.
#
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "0 0 $default_allow_mask ANONYMOUS\@"]
set acl_list_ln [llength $acl_list]
set acl_list [linsert $acl_list $acl_list_ln "1 0 $default_deny_mask ANONYMOUS\@"]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode_set $res $PASS 

puts ""

#
# Cleanup
#
set tag "$TNAME-cleanup"
set res3 [compound {Putfh $bfh; Remove $filename}]
if {$status != "OK"} {
        putmsg stderr 0 "\t WARNING: cleanup to remove created tmp file failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res3)"
        putmsg stderr 1 "  "
}

Disconnect 
exit $PASS
