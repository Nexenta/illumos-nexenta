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
# acltools.tcl - utility procedures used for NFSv4 ACL tests
#

#--------------------------------------------------------------------
# aclmask()
# 
# 	Convert an ACL access_mask defined by strings into numeric form.
#	Returns the numeric value of the access_mask.
#
proc aclmask { mask_list } {
	set mask_val 0
	foreach entry $mask_list {
		switch -exact -- $entry {
			ACE4_READ_DATA { set mask_val [expr $mask_val | 0x00000001] }
			ACE4_LIST_DIRECTORY { set mask_val [expr $mask_val | 0x00000001] }
			ACE4_WRITE_DATA {set mask_val [expr $mask_val | 0x00000002] }
			ACE4_ADD_FILE {set mask_val [expr $mask_val | 0x00000002] }
			ACE4_APPEND_DATA {set mask_val [expr $mask_val | 0x00000004] }
			ACE4_ADD_SUBDIRECTORY {set mask_val [expr $mask_val | 0x00000004] }
			ACE4_READ_NAMED_ATTRS {set mask_val [expr $mask_val | 0x00000008] }
			ACE4_WRITE_NAMED_ATTRS {set mask_val [expr $mask_val | 0x00000010] }
			ACE4_EXECUTE {set mask_val [expr $mask_val | 0x00000020] }
			ACE4_DELETE_CHILD {set mask_val [expr $mask_val | 0x00000040] }
			ACE4_READ_ATTRIBUTES {set mask_val [expr $mask_val | 0x00000080] }
			ACE4_WRITE_ATTRIBUTES {set mask_val [expr $mask_val | 0x00000100] }
			ACE4_DELETE {set mask_val [expr $mask_val | 0x00010000] }
			ACE4_READ_ACL {set mask_val [expr $mask_val | 0x00020000] }
			ACE4_WRITE_ACL {set mask_val [expr $mask_val | 0x00040000] }
			ACE4_WRITE_OWNER {set mask_val [expr $mask_val | 0x00080000] }
			ACE4_SYNCHRONIZE {set mask_val [expr $mask_val | 0x00100000] }
			ACE4_GENERIC_READ {set mask_val [expr $mask_val | 0x00120081] }
			ACE4_GENERIC_WRITE {set mask_val [expr $mask_val | 0x00160106] }
			ACE4_GENERIC_EXECUTE {set mask_val [expr $mask_val | 0x001200A0] }
			ACE4_MASK_UNDEFINED {set mask_val [expr $mask_val | 0x80000000] }
			
			default { puts $entry }
		}
	}
	return [format "%x" $mask_val]
}


#--------------------------------------------------------------------
# de_aclmask()
# 	decode an ACL access_mask from numeric into human readable form.
#
proc de_aclmask { mask_val } {
	
	set num [format "0x%s" $mask_val]

	if { [expr $num & 0x00000001] == 1} {
		append mask_str "ACE4_READ_DATA "
	}
	if { [expr $num & 0x00000002] } {
		append mask_str "ACE4_WRITE_DATA "
	}
	if { [expr $num & 0x00000004] } {
		append mask_str "ACE4_APPEND_DATA "
	}
	if { [expr $num & 0x00000008] } {
		append mask_str "ACE4_READ_NAMED_ATTRS "
	}
	if { [expr $num & 0x00000010] } {
		append mask_str "ACE4_WRITE_NAMED_ATTRS "
	}
	if { [expr $num & 0x00000020] } {
		append mask_str "ACE4_EXECUTE "
	}
	if { [expr $num & 0x00000040] } {
		append mask_str "ACE4_DELETE_CHILD "
	}
	if { [expr $num & 0x00000080] } {
		append mask_str "ACE4_READ_ATTRIBUTES "
	}
	if { [expr $num & 0x00000100] } {
		append mask_str "ACE4_WRITE_ATTRIBUTES "
	}
	if { [expr $num & 0x00010000] } {
		append mask_str "ACE4_DELETE "
	}
	if { [expr $num & 0x00020000] } {
		append mask_str "ACE4_READ_ACL "
	}
	if { [expr $num & 0x00040000] } {
		append mask_str "ACE4_WRITE_ACL "
	}
	if { [expr $num & 0x00080000] } {
		append mask_str "ACE4_WRITE_OWNER "
	}
	if { [expr $num & 0x00100000] } {
		append mask_str "ACE4_SYNCHRONIZE "
	}
	if { [expr $num & 0x00120081] } {
		append mask_str "ACE4_GENERIC_READ "
	}
	if { [expr $num & 0x00160106] } {
		append mask_str "ACE4_GENERIC_WRITE "
	}
	if { [expr $num & 0x001200A0] } {
		append mask_str "ACE4_GENERIC_EXECUTE "
	}
	if { [expr $num & 0x80000000] } {
		append mask_str "ACE4_MASK_UNDEFINED "
	}

	return $mask_str
}


#--------------------------------------------------------------------
# de_acltype()
# 	Decode ACL type numeric value to string.
#
proc de_acltype { type_val } {

	set num [format "0x%s" $type_val]

	if { [expr $num & 0x00000000] == 1} {
		set type_str "ACE4_ACCESS_ALLOWED_ACE_TYPE"
	}
	if { [expr $num & 0x00000001] == 1} {
		set type_str "ACE4_ACCESS_DENIED_ACE_TYPE"
	}
	if { [expr $num & 0x00000002] == 1} {
		set type_str "ACE4_SYSTEM_AUDIT_ACE_TYPE"
	}
	if { [expr $num & 0x00000003] == 1} {
		set type_str "ACE4_SYSTEM_ALARM_ACE_TYPE"
	}

	return $type_str
}

#--------------------------------------------------------------------
# de_aclflg()
#	Decode ACL flag numeric value to string.
#
proc de_aclflag { flag_val } {
	set num [format "0x%s" $type_val]

	if { [expr $num & 0x00000001] == 1} {
		append flag_str "ACE4_FILE_INHERIT_ACE "
	}
	if { [expr $num & 0x00000002] == 1} {
		append flag_str "ACE4_DIRECTORY_INHERIT_ACE "
	}
	if { [expr $num & 0x00000004] == 1} {
		append flag_str "ACE4_NO_PROPAGATE_INHERIT_ACE "
	}
	if { [expr $num & 0x00000008] == 1} {
		append flag_str "ACE4_INHERIT_ONLY_ACE "
	}
	if { [expr $num & 0x00000010] == 1} {
		append flag_str "ACE4_SUCCESSFUL_ACCESS_ACE_FLAG "
	}
	if { [expr $num & 0x00000020] == 1} {
		append flag_str "ACE4_FAILED_ACCESS_ACE_FLAG "
	}
	if { [expr $num & 0x00000040] == 1} {
		append flag_str "ACE4_IDENTIFIER_GROUP "
	}

	return $flag_str
}

#--------------------------------------------------------------------
# extract_acl_list()
#	Given a string from a Getattr acl command (which contains the
#	ACL entries and extraneous text), extract the actual
#	ACL entries and return in list form.
#
proc extract_acl_list { acl_str } {
        set acl_tmp_list [split $acl_str "\{\}"]
        set acl_tmp_list_ln [ expr [llength $acl_tmp_list] - 4]

        for { set i 7} {$i < $acl_tmp_list_ln} { incr i 2} {
                set acl_elm [lindex $acl_tmp_list $i]
                lappend acl_list $acl_elm
        }

        return $acl_list
}

#--------------------------------------------------------------------
# compare_acl_lists()
#	Compare either two full lists of ACL's or sub-fields within the
#	ACL list. Return 0 if they are identical, otherwise return non-zero.
#
proc compare_acl_lists {list1 list2 {field ALL } } {
	set list1_ln [ llength $list1]
	set list2_ln [ llength $list1]

	# Determine are we to match on sub-field or on entire
	# list.
	# ACL sub-fields are always in the following order:
	#	<type><flag><access mask><who>
	#
	switch -exact $field {
		TYPE { set pos 0; set field_match TRUE}
		FLAG { set pos 1; set field_match TRUE}
		MASK { set pos 2; set field_match TRUE}
		WHO { set pos 3; set field_match TRUE}
		default { set pos 0; set field_match FALSE}
	}

	# Sanity check - both lists should have the same number of elements.
	if { $list1_ln != $list2_ln} {
		putmsg stderr 0 "lists have different number of elements"
		return 1
	}

	# If we are just comparing one sub-field then we extract
	# that, otherwise we just compare the entire block.
	if { $field_match == "TRUE"} {
		for { set i 0} {$i < $list1_ln} { incr i 1} {
			if { [lindex [lindex $list1 $i] $pos] != 
				[lindex [lindex $list2 $i] $pos] } {
				putmsg stderr 0 "element $i doesn't match !"
				putmsg stderr 0 "[lindex [lindex $list1 $i] $pos]"
				putmsg stderr 0 "[lindex [lindex $list2 $i] $pos]"
				return 2
			}
		}
	} else {
		for { set i 0} {$i < $list1_ln} { incr i 1} {
        		if { [lindex $list1 $i] != [lindex $list2 $i] } {
				putmsg stderr 0 "element $i doesn't match !"
                		putmsg stderr 0 "[lindex $list1 $i] : [lindex $list2 $i]"
				return 2
			}
        	}
	}

	return 0
}

#--------------------------------------------------------------------
# Convert a Dir ACL list to a File one by removing the DELETE_CHILD
# entry from the ACL mask if it exists.
#
proc dir2file_aclmask { dir_acl } {
	set list1_ln [ llength $dir_acl]
	set pos 2

	set new_list $dir_acl

	for { set i 0} {$i < $list1_ln} { incr i 1} {
		set block [lindex $new_list $i]
		set el [lindex $block $pos]
		set elm [format "0x%s" $el]

		if { [expr $elm & 0x00000040] } {
			set new_el [format "%x" [expr $elm ^ 0x00000040]]
			set new_block [lreplace $block $pos $pos $new_el]
			set new_list [lreplace $new_list $i $i $new_block]
		}
	}

	return $new_list
}


#--------------------------------------------------------------------
# restore_perms()
#	Restore all the permissions on a file or directory. Usually 
#	called after a test has removed one of the perms.
#
proc restore_perms { test_fh field target} {

        set expcode "OK"
        set sid {0 0}

        # get the initial ACL settings.
        set initial_acl [compound {Putfh $test_fh; \
                Getattr acl }]

        ckres "Getattr acl" $status $expcode $initial_acl 1

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

	# Determine which fields to replace.
	switch -exact $field {
		OWNER { 
			if { $target == "FILE" } {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_WRITE_ATTRIBUTES ACE4_READ_ACL ACE4_WRITE_ACL \
				ACE4_READ_DATA ACE4_APPEND_DATA \
				ACE4_WRITE_DATA ACE4_EXECUTE \
				ACE4_SYNCHRONIZE } ] 
			} else {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_READ_ACL ACE4_WRITE_ACL \
				ACE4_WRITE_ATTRIBUTES ACE4_LIST_DIRECTORY \
				ACE4_ADD_SUBDIRECTORY ACE4_ADD_FILE \
				ACE4_EXECUTE \
				ACE4_DELETE_CHILD ACE4_SYNCHRONIZE } ]
			}

			set deny_mask 0

        		set acl_list [lreplace $acl_list 0 0 "0 0 $allow_mask OWNER\@"]
        		set acl_list [lreplace $acl_list 1 1 "1 0 $deny_mask OWNER\@"]
		}
		GROUP {
			if { $target == "FILE" } {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_READ_ACL ACE4_READ_DATA ACE4_APPEND_DATA \
				ACE4_WRITE_DATA ACE4_EXECUTE ACE4_SYNCHRONIZE } ]
			} else {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_LIST_DIRECTORY ACE4_ADD_SUBDIRECTORY ACE4_ADD_FILE \
				ACE4_READ_ACL ACE4_EXECUTE ACE4_DELETE_CHILD ACE4_SYNCHRONIZE } ]
			}
			set deny_mask [ aclmask { ACE4_WRITE_ATTRIBUTES ACE4_WRITE_ACL} ]

			set acl_list [lreplace $acl_list 2 2 "1 40 $deny_mask GROUP\@"]
			set acl_list [lreplace $acl_list 3 3 "0 40 $allow_mask GROUP\@"]
			set acl_list [lreplace $acl_list 4 4 "1 40 $deny_mask GROUP\@"]
		}
		OTHER {
			if { $target == "FILE" } {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_READ_ACL ACE4_READ_DATA ACE4_APPEND_DATA \
				ACE4_WRITE_DATA ACE4_EXECUTE ACE4_SYNCHRONIZE } ]
			} else {
				set allow_mask [ aclmask { ACE4_READ_ATTRIBUTES \
				ACE4_LIST_DIRECTORY ACE4_ADD_SUBDIRECTORY ACE4_ADD_FILE \
				ACE4_READ_ACL ACE4_EXECUTE ACE4_DELETE_CHILD ACE4_SYNCHRONIZE } ]
			}

			set deny_mask [ aclmask { ACE4_WRITE_ATTRIBUTES ACE4_WRITE_ACL} ]
	
			global IsZFS	
			if $IsZFS {
				set acl_list [lreplace $acl_list 4 4 "0 0 $allow_mask EVERYONE\@"]
				set acl_list [lreplace $acl_list 5 5 "1 0 $deny_mask EVERYONE\@"]
			} else {
				set acl_list [lreplace $acl_list 5 5 "0 0 $allow_mask EVERYONE\@"]
				set acl_list [lreplace $acl_list 6 6 "1 0 $deny_mask EVERYONE\@"]
			}
		}
	}

        # Set the new ACL values.
        set res [compound {Putfh $test_fh; \
                Setattr $sid { {acl \
                { $acl_list } } } } ]

        ckres "Setattr acl" $status $expcode $res 1

        # Re-read ACL values
        set res2 [compound {Putfh $test_fh; \
                Getattr acl }]

        ckres "Getattr acl again" $status $expcode $res2 1

        set new_acl_list [extract_acl_list $res2]

        if { [compare_acl_lists $new_acl_list $acl_list] != 0} {
                putmsg stderr 0 \
                        "\t Test FAIL: lists do not match."
        } else {
                putmsg stdout 0 "\t Test PASS"
        }

        puts ""
}


#--------------------------------------------------------------------
# remove_dir_entries()
#	Given directory handled and list of contents (files and
#	sub-dirs) remove the contents so the parent directory can
#	itself be removed.
#
#	This can be used as a building block in the future for a generic 
#	'rm -rf' type routine which just removes a directory even when it 
#	is not empty.
#
proc remove_dir_entries { handle contents_list } {
	foreach entry $contents_list {
        	set result [compound {Putfh $handle; Remove $entry}]

        	if {$status != "OK"} {
                	putmsg stderr 0 "\t WARNING: cleanup to remove tmp entry ($entry)"
			putmsg stderr 0 "\t	failed : status=$status; please cleanup "
			putmsg stderr 0 "\t	manually."
                	putmsg stderr 1 "\t   res=($result)"
                	putmsg stderr 1 "  "
        	}
	}
}
