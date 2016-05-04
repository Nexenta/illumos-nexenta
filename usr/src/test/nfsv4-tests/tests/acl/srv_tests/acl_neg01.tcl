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
# a: Test set ACL flag attr ACE4_NO_PROPAGATE_INHERIT_ACE; expect ATTRNOTSUPP 
# b: Test set ACL flag attr ACE4_SUCCESSFUL_ACCESS_ACE_FLAG; expect ATTRNOTSUPP 
# c: Test set ACL flag attr ACE4_FAILED_ACCESS_ACE_FLAG; expect ATTRNOTSUPP 
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
#a: Test set ACL flag attr ACE4_NO_PROPAGATE_INHERIT_ACE 
#	expect ATTRNOTSUPP for UFS
#	expect OK for ZFS

if $IsZFS {
	set expcode "INVAL"
} else {
	set expcode "ATTRNOTSUPP"
}
set tag "$TNAME{a}"
set ASSERTION "Test set ACL flag attr ACE4_NO_PROPAGATE_INHERIT_ACE, expect $expcode"
putmsg stdout 0 "$tag: $ASSERTION"

set ACE4_NO_PROPAGATE_INHERIT_ACE 4
set sid {0 0}

# get the initial ACL settings.
set initial_acl [compound {Putfh $tfh; \
        Getattr acl }]

ckres "Getattr acl" $status "OK" $initial_acl $FAIL

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
# The <OWNER> block is itself composed of 4 fields <type><flag><mask><who>
# so we need to extract the <type> field and replace it with the TYPE we
# are testing.
#
set owner [lindex $acl_list 0]
set new_owner [lreplace [split $owner] 1 1 "$ACE4_NO_PROPAGATE_INHERIT_ACE"]

# Replace the original OWNER block with the one we have modified.
set acl_list [lreplace $acl_list 0 0 $new_owner]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode $res $PASS

puts ""

# ---------------------------------------------------------------
#b: Test set ACL flag attr ACE4_SUCCESSFUL_ACCESS_ACE_FLAG expect ATTRNOTSUPP

set tag "$TNAME{b}"
set ASSERTION "Test set ACL flag attr ACE4_SUCCESSFUL_ACCESS_ACE_FLAG, expect ATTRNOTSUPP"
putmsg stdout 0 "$tag: $ASSERTION"

set ACE4_SUCCESSFUL_ACCESS_ACE_FLAG 10
set sid {0 0}

# get the initial ACL settings.
set expcode "OK"
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
# The <OWNER> block is itself composed of 4 fields <type><flag><mask><who>
# so we ned to extract the <type> field and replace it with the TYPE we
# are testing.
#
set owner [lindex $acl_list 0]
set new_owner [lreplace [split $owner] 1 1 "$ACE4_SUCCESSFUL_ACCESS_ACE_FLAG"]

# Replace the original OWNER block with the one we have modified.
set acl_list [lreplace $acl_list 0 0 $new_owner]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set expcode "ATTRNOTSUPP"
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode $res $PASS

puts ""

# ---------------------------------------------------------------
#c: Test set ACL flag attr ACE4_FAILED_ACCESS_ACE_FLAG expect ATTRNOTSUPP

set tag "$TNAME{c}"
set ASSERTION "Test set ACL flag attr ACE4_FAILED_ACCESS_ACE_FLAG, expect ATTRNOTSUPP"
putmsg stdout 0 "$tag: $ASSERTION"

set ACE4_FAILED_ACCESS_ACE_FLAG 20
set sid {0 0}

# get the initial ACL settings.
set expcode "OK"
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
# The <OWNER> block is itself composed of 4 fields <type><flag><mask><who>
# so we ned to extract the <type> field and replace it with the TYPE we
# are testing.
#
set owner [lindex $acl_list 0]
set new_owner [lreplace [split $owner] 1 1 "$ACE4_FAILED_ACCESS_ACE_FLAG"]

# Replace the original OWNER block with the one we have modified.
set acl_list [lreplace $acl_list 0 0 $new_owner]
putmsg stderr 1 "$tag: new ACL : $acl_list"

# Attempt to set the new ACL values, expect this to fail.
set expcode "ATTRNOTSUPP"
set res [compound {Putfh $tfh; \
        Setattr $sid { {acl \
        { $acl_list } } } } ]

ckres "Setattr" $status $expcode $res $PASS 

puts ""

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
