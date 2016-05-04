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
# TCL procedure for CREATE operation testing

#--------------------------------------------------------------------
# uid_creat()
#       Wrap for testing Create (type fifo) assertions for BADOWNER and
#		verifying with getattr op.
#       Returns  OK if success, else the status code of the operation.
#		parameters Aown Aowngrp are set to final attrs of file
#

proc uid_creat {dfh name Aown Aowngrp Ares {Eown ""} {Egrp ""} {type f}} {
	# initialize attributes parameter
	upvar 1 $Aown own
	upvar 1 $Aowngrp owngrp
	upvar 1 $Ares res
	set status "UNRESOLVED"
	putmsg stdout 1 "\n"
	putmsg stdout 1 \
"uid_creat $dfh $name $Aown $Aowngrp $Ares \"$Eown\" \"$Egrp\" \"$type\""
	putmsg stdout 1 "status = $status"

	global PASS FAIL OTHER
	set attrib {}
	set attrs {}
	set O 0
	set G 0

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	if {[string length $own] > 0}  {
		lappend attrib "owner $own"
		lappend attrs "owner"
		set O 1
	}
	if {[string length $owngrp] > 0} {
		lappend attrib "owner_group $owngrp"
		lappend attrs "owner_group"
		set G 1
	}
	putmsg stdout 1 "attrib = <$attrib>"
	putmsg stdout 1 "attrs = <$attrs>"

	set orig_owner ""
	set orig_owner_group ""
	set Sstatus "OK"
	# Generate a compound request to test the attributes
	set st [catch {compound {Putfh $dfh; Create $name {$attrib} $type; \
		Getfh}} res]
	putmsg stdout 1 "compound{Putfh $dfh;"
	putmsg stdout 1 "\tCreate $name {$attrib} $type; Getfh}"
	putmsg stdout 1 "res: <$res>"
	if {$status != "OK"} {
		putmsg stdout 1 "Create return status=$status"
		putmsg stdout 1 "catch result = $st"
		return $status
	}
	set ufh [lindex [lindex $res 2] 2]
	putmsg stdout 1 "new filehandle = $ufh"

	#verify the change in attribute
	set st2 [catch {compound {Putfh $ufh; Getattr $attrs}} res2]
	putmsg stdout 1 "compound{Putfh $ufh;\n\tGetattr $attrs}"
	putmsg stdout 1 "res: <$res2>"
	if {$status != "OK"} {
		putmsg stdout 0 "\twarning: Getattr failed ($status)."
		putmsg stdout 1 "return status=$status"
		putmsg stdout 1 "catch result = $st2"
		return $status
	} else {
		set rattrs [lindex [lindex $res2 1] 2]
		set owner ""
		set owner_group ""
		putmsg stdout 1 "returned attrs = $rattrs"
		foreach attr $rattrs {
			set name [ lindex $attr 0]
			set val  [ lindex $attr 1]

			switch $name {
				owner	{ 
					set owner $val
				}
				owner_group	{
					set owner_group $val
				}
				default	{}
			}
		}
		putmsg stdout 1 "owner = $owner\nowner_group = $owner_group"
	}

	set Cstatus ""
	# if expected value different than value used
	if {$Eown != ""} {
		set own $Eown
	}
	if {$Egrp != ""} {
		set owngrp $Egrp
	}
	# compare to requested values
	# XXX should we enhance to ignore the case of the domain?
	if {$O == 1 && [string equal $own $owner] != 1} {
		putmsg stdout 1 "owner set to $own, but is $owner"
		set own $owner
		set Cstatus "${Cstatus}OwnerMismatch"
	}
	if {$G == 1 && [string equal $owngrp $owner_group] != 1} {
		putmsg stdout 1\
			"group set to $owngrp, but is $owner_group"
		set Cstatus "${Cstatus}GroupMismatch"
	}

	if {$Cstatus != ""} {
		set status $Cstatus
	}

	putmsg stdout 1 "return $status"
	return $status
}
