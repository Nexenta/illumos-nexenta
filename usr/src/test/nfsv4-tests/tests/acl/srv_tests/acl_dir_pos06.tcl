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
# NFSv4 ACL attributes:
#
# a: Test adding a default ACL of (rwxrwxrwx) to an existing directory
# b: Test the default ACL settings of (rwxrwxrwx) are inherited by sub-dir
# c: Test the default ACL settings of (rwxrwxrwx) are inherited by sub-file
# d: Test adding a default ACL of (-wxrwxrwx) to an existing directory
# e: Test the default ACL settings of (-wxrwxrwx) are inherited by sub-dir
# f: Test the default ACL settings of (-wxrwxrwx) are inherited by sub-dir
# g: Test adding a default ACL of (r-xrwxrwx) to an existing directory
# h: Test the default ACL settings of (r-xrwxrwx) are inherited by sub-dir
# i: Test the default ACL settings of (r-xrwxrwx) are inherited by sub-dir
# j: Test adding a default ACL of (rw-rwxrwx) to an existing directory
# k: Test the default ACL settings of (rw-rwxrwx) are inherited by sub-dir
# l: Test the default ACL settings of (rw-rwxrwx) are inherited by sub-dir

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
set dir_cont_list ""

set POSIX_READ_ACL $env(POSIX_READ_ACL)
set POSIX_WRITE_ACL $env(POSIX_WRITE_ACL)
set POSIX_WRITE_DIR_ACL $env(POSIX_WRITE_DIR_ACL)
set POSIX_EXECUTE_ACL $env(POSIX_EXECUTE_ACL)
set GENERIC_ALLOW_ACL $env(GENERIC_ALLOW_ACL)
set OWNER_ALLOW_ACL $env(OWNER_ALLOW_ACL)
set GENERIC_DENY_ACL $env(GENERIC_DENY_ACL)

# Get handle for base directory
set bfh [get_fh "$BASEDIRS"]

# Set params relating to test file
set dirname "newdir.[pid]"
set dpath  [file join ${BASEDIR} ${dirname}]

# Create the test parent dir with all perms set (-rwxrwxrwx) and get its handle.
set dfh "[creatv4_dir $dpath 777]"
if {$dfh == $NULL} {
        putmsg stdout 0 "$TNAME: test setup"
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp dir=($dirname)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
}

# get the initial non-default ACL settings.
set initial_acl [compound {Putfh $dfh; \
        Getattr acl }]

if {$status != "OK"} {
        putmsg stdout 0 "$TNAME: test setup"
        putmsg stderr 0 "\t Test UNRESOLVED: failed to get ACL for dir=($dirname)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
}

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set initial_acl_list [extract_acl_list $initial_acl]
putmsg stderr 1 "$TNAME: initial ACL : $initial_acl_list"

# Start testing
# --------------------------------------------------------------------------------
# a: Test adding a default ACL of (rwxrwxrwx) to an existing directory 

set tag "$TNAME{a}"
set ASSERTION "Test adding a default ACL of (rwxrwxrwx) to an existing directory"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

# Default Dir ACL settings
#
# Owner - allow rwx
set dir_owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_READ_ACL \
$POSIX_WRITE_DIR_ACL $POSIX_EXECUTE_ACL ] ]

set dir_owner_deny_mask 0

# Group - allow rwx
set dir_group_allow_mask [ aclmask [ concat $GENERIC_ALLOW_ACL $POSIX_READ_ACL \
$POSIX_WRITE_DIR_ACL $POSIX_EXECUTE_ACL ] ]

set dir_group_deny_mask [  aclmask $GENERIC_DENY_ACL ]

# Other - allow rwx
set dir_other_allow_mask [ aclmask [ concat $GENERIC_ALLOW_ACL $POSIX_READ_ACL \
$POSIX_WRITE_DIR_ACL $POSIX_EXECUTE_ACL ] ]

set dir_other_deny_mask [  aclmask $GENERIC_DENY_ACL ]

if $IsZFS {
	set inherited_owner_allow_mask $dir_owner_allow_mask
	set inherited_owner_deny_mask $dir_owner_deny_mask

	# For case b, ONE ACE on parent directory can create TWO ACEs on sub-dirs
	# As we only concern the mask which will be compared, here we just set
	# both TYPE and FLAG fields with 0.
	lappend inherited_acl_dir_owner_list_b	\
		"0 0 $dir_owner_allow_mask OWNER@"	\
		"0 0 $inherited_owner_allow_mask OWNER@"	\
		"0 0 $dir_owner_deny_mask OWNER@"	\
		"0 0 $inherited_owner_deny_mask OWNER@"

	# For case c, ONE ACE on parent directory can create ONE ACE on sub-file	
	lappend inherited_acl_file_owner_list_c	\
		"0 0 $inherited_owner_allow_mask OWNER@"   \
		"0 0 $inherited_owner_deny_mask OWNER@"

	set inherited_group_allow_mask $dir_group_allow_mask
	set inherited_group_deny_mask $dir_group_deny_mask
	set inherited_other_allow_mask $dir_other_allow_mask
	set inherited_other_deny_mask $dir_other_deny_mask

	# in all sub-assertions, we only change "OWNER@" ACEs
	# so other ACEs (GROUP and EVERYONE) are the same.
	lappend inherited_dir_common_list	\
		"0 0 $dir_group_deny_mask GROUP@"	\
		"0 0 $inherited_group_deny_mask GROUP@"	\
		"0 0 $dir_group_allow_mask GROUP@"	\
		"0 0 $inherited_group_allow_mask GROUP@"	\
		"0 0 $dir_group_deny_mask GROUP@"	\
		"0 0 $inherited_group_deny_mask GROUP@"	\
		"0 0 $dir_other_allow_mask EVERYONE@"	\
		"0 0 $inherited_other_allow_mask EVERYONE@"	\
		"0 0 $dir_other_deny_mask EVERYONE@"	\
		"0 0 $inherited_other_deny_mask EVERYONE@"

	set expected_dir_common_list [ concat $inherited_dir_common_list	\
		$initial_acl_list ]

	lappend inherited_file_common_list	\
		"0 0 $inherited_group_deny_mask GROUP@"	\
		"0 0 $inherited_group_allow_mask GROUP@"	\
		"0 0 $inherited_group_deny_mask GROUP@"	\
		"0 0 $inherited_other_allow_mask EVERYONE@"	\
		"0 0 $inherited_other_deny_mask EVERYONE@"	
	
	set expected_file_common_list [ concat $inherited_file_common_list  	\
		$initial_acl_list ]
}

# Create the new ACL settings by appending the appropriate default
# ACL entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
# Set the default ACL's 

set acl_list $initial_acl_list
lappend default_acl_list  "0 b $dir_owner_allow_mask OWNER\@"
lappend default_acl_list  "1 b $dir_owner_deny_mask OWNER\@"
lappend default_acl_list  "1 4b $dir_group_deny_mask GROUP\@"
lappend default_acl_list  "0 4b $dir_group_allow_mask GROUP\@"
lappend default_acl_list  "1 4b $dir_group_deny_mask GROUP\@"
lappend default_acl_list  "0 b $dir_other_allow_mask EVERYONE\@"
lappend default_acl_list  "1 b $dir_other_deny_mask EVERYONE\@"

set dir_acl_list [concat $initial_acl_list $default_acl_list]
putmsg stderr 1 "$tag: new dir ACL : $dir_acl_list"

# Set the new ACL values.
set res [compound {Putfh $dfh; \
        Setattr $sid { {acl \
        { $dir_acl_list } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $dfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $dir_acl_list MASK] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# b: Test the default ACL settings of (rwxrwxrwx) are inherited by sub-dir

set tag "$TNAME{b}"
set ASSERTION "Test the default ACL settings of (rwxrwxrwx) are inherited by sub-dir"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

# Set params relating to test file
set subdir "subdirB.[pid]"
set sdpath $BASEDIR/$dirname/$subdir

# Attempt to create the sub-dir and get its handle
set sdfh "[creatv4_dir $sdpath 777]"
if {$sdfh == $NULL} {
        putmsg stderr 0 "\t Test FAIL: failed to create tmp subdir=($subdir)"
        putmsg stderr 0 "\t\t status=($status)."
} else {
	# Add the sub-dir name to a list for easy removal later.
	lappend dir_cont_list $subdir

	# Read subdir ACL values
	set res2 [compound {Putfh $sdfh; \
        	Getattr acl }]

	ckres "Getattr acl again" $status $expcode $res2 $FAIL

	set new_acl_list [extract_acl_list $res2]
	if $IsZFS {
		set expected_acl [ concat $inherited_acl_dir_owner_list_b	\
			 $expected_dir_common_list ]
	} else {
		set expected_acl [concat $default_acl_list $default_acl_list]
	}
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"
	putmsg stderr 1 "$tag: expected ACL: $expected_acl"

	if { [compare_acl_lists $new_acl_list $expected_acl MASK] != 0} {
        	putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}

	puts ""
}

# ------------------------------------------------------------------------
# c: Test the default ACL settings of (rwxrwxrwx) are inherited by sub-file

set tag "$TNAME{c}"
set ASSERTION "Test the default ACL settings of (rwxrwxrwx) are inherited by sub-file"
putmsg stdout 0 "$tag: $ASSERTION"

set sid { 0 0}

# Set params relating to test sub-file
set subfile "subfileC.[pid]"
set sfpath $BASEDIR/$dirname/$subfile

# Attempt to create the sub-file with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sffh "[creatv4_file $sfpath 777]"
if {$sffh == $NULL } {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subfile=($subfile)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {

        lappend dir_cont_list $subfile

	# Read file ACL values
        set res2 [compound {Putfh $sffh; \
                Getattr acl }]

        ckres "Getattr acl again" $status $expcode $res2 $FAIL

        set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if $IsZFS {
		# The file should have inherited the parent directorys acl
		set exp_acl [ concat $inherited_acl_file_owner_list_c	\
			$expected_file_common_list ]
        } else {
        	# The file should have inherited the parent directorys default
        	# ACL settings except for the DELETE_CHILD bitmask.
        	set exp_acl [dir2file_aclmask $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

        if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
                putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
        } else {
                putmsg stdout 0 "\t Test PASS"
        }
}

puts ""

# ------------------------------------------------------------------------
# d: Test adding a default ACL of (-wxrwxrwx) to an existing directory

set tag "$TNAME{d}"
set ASSERTION "Test adding a default ACL of (-wxrwxrwx) to an existing directory"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_WRITE_DIR_ACL \
$POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask $POSIX_READ_ACL ]

if $IsZFS {
	set inherited_owner_allow_mask $owner_allow_mask
	set inherited_owner_deny_mask $owner_deny_mask

	# For case e, ONE ACE on parent directory can create TWO ACEs on sub-dirs.
        # As we only concern the mask which will be compared, here we just set
        # both TYPE and FLAG fields with 0.	
	lappend inherited_acl_dir_owner_list_e	\
		"0 0 $owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $owner_deny_mask OWNER\@"	\
		"0 0 $inherited_owner_deny_mask  OWNER\@"

	# For case f, ONE ACE on parent directory can create ONE ACE on sub-file
	lappend inherited_acl_file_owner_list_f	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_deny_mask  OWNER\@"
}

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list $default_acl_list
set acl_list [lreplace $acl_list 0 0 "0 b $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 b $owner_deny_mask OWNER\@"]

set new_dir_acl [concat $initial_acl_list $acl_list]
putmsg stderr 1 "$tag: new ACL : $new_dir_acl"

# Set the new ACL values.
set res [compound {Putfh $dfh; \
        Setattr $sid { {acl \
        { $new_dir_acl } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $dfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $new_dir_acl] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# e: Test the default ACL settings are inherited by sub-dir (-wxrwxrwx)

set tag "$TNAME{e}"
set ASSERTION "Test the default ACL settings of (-wxrwxrwx) are inherited by sub-dir"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

# Set params relating to test sub-dir
set subdir "subdirE.[pid]"
set sdpath $BASEDIR/$dirname/$subdir

# Attempt to create the sub-dir with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sdfh "[creatv4_dir $sdpath 777]"
if {$sdfh == $NULL} {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subdir=($subdir)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {
        lappend dir_cont_list $subdir

	# Read dir ACL values
	set res2 [compound {Putfh $sdfh; \
        	Getattr acl }]

	ckres "Getattr acl again" $status $expcode $res2 $FAIL

	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	# The sub directory should have inherited the parents default
	# ACL settings, as both its default and non-default settings.
	if $IsZFS {
		set exp_acl [ concat $inherited_acl_dir_owner_list_e	\
			$expected_dir_common_list ]
	} else {
		set exp_acl [concat $acl_list $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

	if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
        	putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# f: Test the default ACL settings of (-wxrwxrwx) are inherited by sub-file

set tag "$TNAME{f}"
set ASSERTION "Test the default ACL settings of (-wxrwxrwx) are inherited by sub-file"
putmsg stdout 0 "$tag: $ASSERTION"

set sid { 0 0}

# Set params relating to test sub-file
set subfile "subfileF.[pid]"
set sfpath $BASEDIR/$dirname/$subfile

# Attempt to create the sub-file with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sffh "[creatv4_file $sfpath 777]"
if {$sffh == $NULL } {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subfile=($subfile)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {

        lappend dir_cont_list $subfile

	# Read file ACL values
        set res2 [compound {Putfh $sffh; \
                Getattr acl }]

        ckres "Getattr acl again" $status $expcode $res2 $FAIL

        set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if $IsZFS {
        	# The file should have inherited the parent directorys acl
		set exp_acl [ concat $inherited_acl_file_owner_list_f	\
			$expected_file_common_list ]
	} else {
        	# The file should have inherited the parent directorys default
		# ACL settings except for the DELETE_CHILD bitmask.
		set exp_acl [dir2file_aclmask $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

        if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
                putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
        } else {
                putmsg stdout 0 "\t Test PASS"
        }
}

puts ""

# ------------------------------------------------------------------------
# g: Test adding a default ACL of (r-xrwxrwx) to an existing directory

set tag "$TNAME{g}"
set ASSERTION "Test adding a default ACL of (r-xrwxrwx) to an existing directory"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_READ_ACL \
$POSIX_EXECUTE_ACL ] ]

set owner_deny_mask [ aclmask $POSIX_WRITE_DIR_ACL ]

if $IsZFS {
	set inherited_owner_allow_mask $owner_allow_mask
	set inherited_owner_deny_mask $owner_deny_mask

	# For case h, ONE ACE on parent directory can create TWO ACEs on sub-dirs.
        # As we only concern the mask which will be compared, here we just set
        # both TYPE and FLAG fields with 0.
	lappend inherited_acl_dir_owner_list_h	\
		"0 0 $owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $owner_deny_mask OWNER\@"		\
		"0 0 $inherited_owner_deny_mask  OWNER\@"

	# For case i, ONE ACE on parent directory can create ONE ACE on sub-file
	lappend inherited_acl_file_owner_list_i	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_deny_mask  OWNER\@"
}

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set acl_list [extract_acl_list $initial_acl]

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list $default_acl_list
set acl_list [lreplace $acl_list 0 0 "0 b $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 b $owner_deny_mask OWNER\@"]

set new_dir_acl [concat $initial_acl_list $acl_list]
putmsg stderr 1 "$tag: new dir ACL : $new_dir_acl"

# Set the new ACL values.
set res [compound {Putfh $dfh; \
        Setattr $sid { {acl \
        { $new_dir_acl } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $dfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $new_dir_acl] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# h: Test the default ACL settings of (r-xrwxrwx) are inherited by sub-dir

set tag "$TNAME{h}"
set ASSERTION "Test the default ACL settings of (r-xrwxrwx) are inherited by sub-dir"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

# Set params relating to test file
set subdir "subdirH.[pid]"
set sdpath $BASEDIR/$dirname/$subdir

# Attempt to create the sub-dir with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sdfh "[creatv4_dir $sdpath 777]"
if {$sdfh == $NULL} {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subdir=($subdir)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {
        lappend dir_cont_list $subdir

	# Read dir ACL values
	set res2 [compound {Putfh $sdfh; \
        	Getattr acl }]

	ckres "Getattr acl again" $status $expcode $res2 $FAIL

	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	# The sub directory should have inherited the parents default
	# ACL settings, as both its default and non-default settings.
	if $IsZFS {
		set exp_acl [ concat $inherited_acl_dir_owner_list_h	\
			$expected_dir_common_list ]
	} else {
		set exp_acl [concat $acl_list $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

	if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
        	putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# i: Test the default ACL settings of (r-xrwxrwx) are inherited by sub-file

set tag "$TNAME{i}"
set ASSERTION "Test the default ACL settings of (r-xrwxrwx) are inherited by sub-file"
putmsg stdout 0 "$tag: $ASSERTION"

set sid { 0 0}

# Set params relating to test sub-file
set subfile "subfileI.[pid]"
set sfpath $BASEDIR/$dirname/$subfile

# Attempt to create the sub-file with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sffh "[creatv4_file $sfpath 777]"
if {$sffh == $NULL } {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subfile=($subfile)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {

        lappend dir_cont_list $subfile

	# Read file ACL values
        set res2 [compound {Putfh $sffh; \
                Getattr acl }]

        ckres "Getattr acl again" $status $expcode $res2 $FAIL

        set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if $IsZFS {
		# The file should have inherited the parent directorys acl
		set exp_acl [ concat $inherited_acl_file_owner_list_i	\
			$expected_file_common_list ]
	} else {
		# The file should have inherited the parent directorys default
		# ACL settings except for the DELETE_CHILD bitmask.
		set exp_acl [dir2file_aclmask $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

        if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
                putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
        } else {
                putmsg stdout 0 "\t Test PASS"
        }
}

puts ""

# ------------------------------------------------------------------------
# j: Test adding a default ACL of (rw-rwxrwx) to an existing directory

set tag "$TNAME{j}"
set ASSERTION "Test adding a default ACL of (rw-rwxrwx) to an existing directory"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

set owner_allow_mask [ aclmask [ concat $OWNER_ALLOW_ACL $POSIX_READ_ACL $POSIX_WRITE_DIR_ACL ] ]

set owner_deny_mask [ aclmask $POSIX_EXECUTE_ACL ]

if $IsZFS {
	set inherited_owner_allow_mask $owner_allow_mask
	set inherited_owner_deny_mask $owner_deny_mask

	# For case k, ONE ACE on parent directory can create TWO ACEs on sub-dirs
        # As we only concern the mask which will be compared, here we just set
        # both TYPE and FLAG fields with 0.	
	lappend inherited_acl_dir_owner_list_k	\
		"0 0 $owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $owner_deny_mask OWNER\@"		\
		"0 0 $inherited_owner_deny_mask  OWNER\@"

	# For case l, ONE ACE on parent directory can create ONE ACE on sub-file
	lappend inherited_acl_file_owner_list_l	\
		"0 0 $inherited_owner_allow_mask OWNER\@"	\
		"0 0 $inherited_owner_deny_mask  OWNER\@"
}

#
# Break the string returned from the Geattr acl command into
# a list and then extract the actual ACL settings.
#
set acl_list [extract_acl_list $initial_acl]

# Create the new ACL settings by replacing the appropriate entries.
#
# Order of entries in the list is as follows:
# <OWNER><OWNER><GROUP><GROUP><GROUP><EVERYONE><EVERYONE>
#
set acl_list $default_acl_list
set acl_list [lreplace $acl_list 0 0 "0 b $owner_allow_mask OWNER\@"]
set acl_list [lreplace $acl_list 1 1 "1 b $owner_deny_mask OWNER\@"]

set new_dir_acl [concat $initial_acl_list $acl_list]
putmsg stderr 1 "$tag: new dir ACL : $new_dir_acl"

# Set the new ACL values.
set res [compound {Putfh $dfh; \
        Setattr $sid { {acl \
        { $new_dir_acl } } } } ]

ckres "Setattr acl" $status $expcode $res $FAIL

# Re-read ACL values
set res2 [compound {Putfh $dfh; \
        Getattr acl }]

ckres "Getattr acl again" $status $expcode $res2 $FAIL

if { $status == "OK" } {
	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if { [compare_acl_lists $new_acl_list $new_dir_acl] != 0} {
        	putmsg stderr 0 \
                	"\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
}

puts ""

# ------------------------------------------------------------------------
# k: Test the default ACL settings of (rw-rwxrwx) are inherited by sub-dir

set tag "$TNAME{k}"
set ASSERTION "Test the default ACL settings of (rw-rwxrwx) are inherited by sub-dir"
putmsg stdout 0 "$tag: $ASSERTION"

set sid {0 0}

# Set params relating to test file
set subdir "subdirK.[pid]"
set sdpath $BASEDIR/$dirname/$subdir

# Attempt to create the sub-dir with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sdfh "[creatv4_dir $sdpath 777]"
if {$sdfh == $NULL} {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subdir=($subdir)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {
        lappend dir_cont_list $subdir

	# Read dir ACL values
	set res2 [compound {Putfh $sdfh; \
        	Getattr acl }]

	ckres "Getattr acl again" $status $expcode $res2 $FAIL

	set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	# The sub directory should have inherited the parents default
	# ACL settings, as both its default and non-default settings.
	if $IsZFS {
		set exp_acl [ concat $inherited_acl_dir_owner_list_k	\
			$expected_dir_common_list ]
	} else {
		set exp_acl [concat $acl_list $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

	if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
        	putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
	} else {
        	putmsg stdout 0 "\t Test PASS"
	}
	
	puts ""
}

# ------------------------------------------------------------------------
# l: Test the default ACL settings of (rw-rwxrwx) are inherited by sub-file

set tag "$TNAME{l}"
set ASSERTION "Test the default ACL settings of (rw-rwxrwx) are inherited by sub-file"
putmsg stdout 0 "$tag: $ASSERTION"

set sid { 0 0}

# Set params relating to test sub-file
set subfile "subfileL.[pid]"
set sfpath $BASEDIR/$dirname/$subfile

# Attempt to create the sub-file with all perms set (-rwxrwxrwx) which should be
# over-ridden by the parent dir's default ACL settings, and get its handle.
set sffh "[creatv4_file $sfpath 777]"
if {$sffh == $NULL } {
        putmsg stderr 0 "\t Test UNRESOLVED: failed to create tmp subfile=($subfile)"
        putmsg stderr 0 "\t\t status=($status)."
        Disconnect
        exit $UNRESOLVED
} else {

        lappend dir_cont_list $subfile

	# Read file ACL values
        set res2 [compound {Putfh $sffh; \
                Getattr acl }]

        ckres "Getattr acl again" $status $expcode $res2 $FAIL

        set new_acl_list [extract_acl_list $res2]
	putmsg stderr 1 "$tag: re-read ACL : $new_acl_list"

	if $IsZFS {
		# The file should have inherited the parent directorys acl
		set exp_acl [ concat $inherited_acl_file_owner_list_l	\
			$expected_file_common_list ]
	} else {
		# The file should have inherited the parent directorys default
		# ACL settings except for the DELETE_CHILD bitmask.
		set exp_acl [dir2file_aclmask $acl_list]
	}
	putmsg stderr 1 "$tag: expected ACL: $exp_acl"

        if { [compare_acl_lists $new_acl_list $exp_acl MASK] != 0} {
                putmsg stderr 0 \
                "\t Test FAIL: lists do not match."
        } else {
                putmsg stdout 0 "\t Test PASS"
        }
}

puts ""

#
# Final Cleanup - remove all the sub-files and sub-dirs first
# then the parent directory.
#
set tag "$TNAME-sub-cleanup"
remove_dir_entries $dfh $dir_cont_list

set tag "$TNAME-cleanup"
set res3 [compound {Putfh $bfh; Remove $dirname}]
if {$status != "OK"} {
        putmsg stderr 0 "\t WARNING: cleanup to remove tmp parent dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
        putmsg stderr 1 "\t   res=($res3)"
        putmsg stderr 1 "  "
}

Disconnect 
exit $PASS
