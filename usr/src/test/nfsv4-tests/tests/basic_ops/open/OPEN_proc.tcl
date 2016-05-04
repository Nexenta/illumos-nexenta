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
# TCL procedures for OPEN operation testing

# NFSv4 constant:
set OPEN4_RESULT_CONFIRM        2


#---------------------------------------------------------
# Test procedure to close the file; but also Open_confirm (if needed).
#  Usage: ckclose nfh rflags seqid sid
# 	nfh:	 the filehandle to be closed
#	rflags:  the rflags for OPEN_CONFIRM
#	seqid:   the sequence id
#	sid:     the state id 
#
#  Return: 
#	true:  	Close succeed
#	false: 	things failed during the process
#
proc ckclose {nfh rflags seqid sid} {
    global DEBUG OPEN4_RESULT_CONFIRM

    set cont true
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	putmsg stderr 1 "  Open_confirm $sid $seqid"
	set res [compound {Putfh $nfh; Open_confirm $sid $seqid}]
	if {$status != "OK"} {
            putmsg stderr 0 \
		"\t Test FAIL: Open_confirm failed, status=($status)."
            putmsg stderr 1 "\t   res=($res)"
	    set cont false
	}
        set sid [lindex [lindex $res 1] 2]
	incr seqid
    }
    # verify the filehandle of OPEN is good to close) and same as LOOKUP
    if {! [string equal $cont "false"]} {
	# Close the file
	putmsg stderr 1 "  Close $seqid $sid"
	set res [compound {Putfh $nfh; Close $seqid $sid}]
	if {$status != "OK"} {
            putmsg stderr 0 \
		"\t Test FAIL: Close failed, status=($status)."
            putmsg stderr 1 "\t   res=($res)"
	    set cont false
	}
    }
    return $cont
}


#--------------------------------------------------------------------
# uid_open()
#       Wrap for testing Open assertions for BADOWNER and
#		verifying with getattr op.
#       Returns OK if success, else the status code of the operation.
#		parameters Aown Aowngrp are set to final attrs of file
#

proc uid_open {dfh fname clientid Aown Aowngrp Ares {Eown ""} \
	{Egrp ""}} {
	global DEBUG OPEN4_RESULT_CONFIRM

	# initialize attributes parameter
	upvar 1 $Aown own
	upvar 1 $Aowngrp owngrp
	upvar 1 $Ares res

	set status "UNRESOLVED"
	putmsg stdout 1 "\n"
	putmsg stdout 1 "uid_open $dfh $fname $clientid"
	putmsg stdout 1 "\t$Aown $Aowngrp $Ares \"$Eown\" \"$Egrp\""
	putmsg stdout 1 "status = $status"

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

	lappend attrib "mode 0777"
	set seqid 1
	set rem_flag 0
	# Generate a compound request to test the attributes
	set st [catch {compound {Putfh $dfh; Open $seqid 3 0 {$clientid $fname}\
		{1 0 {$attrib}} {0  $fname}; Getfh}} res]
	putmsg stdout 1 "compound{Putfh $dfh;"
	putmsg stdout 1 "\tOpen $seqid 3 0 {$clientid $fname}"
	putmsg stdout 1 "\t{1 0 {$attrib}}"
	putmsg stdout 1 "\t{0 $fname}; Getfh}"
	putmsg stdout 1 "res: <$res>"
	if {$status != "OK"} {
		putmsg stdout 1 "Open return status=$status"
		putmsg stdout 1 "catch result = $st"
		return $status
	}
	set stateid [lindex [lindex $res 1] 2]
	set rflags [lindex [lindex $res 1] 4] 
	set ufh [lindex [lindex $res 2] 2]
	putmsg stdout 1 "stateid = $stateid\nrflags = $rflags\nufh = $ufh"

	# do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
		incr seqid
		set res [compound {Putfh $ufh; Open_confirm $stateid $seqid}]
		putmsg stdout 1 "compound {Putfh $ufh;"
		putmsg stdout 1 "Open_confirm $stateid $seqid}"
		putmsg stdout 1 "Res: $res"
		if {$status != "OK"} {
			putmsg stdout 1 \
				"unable to openconfirm $fname ($status)."
			return $status
		}
		set rem_flag 1
		set stateid [lindex [lindex $res 1] 2]
	}
	incr seqid
	putmsg stdout 1 "stateid = $stateid\nseqid = $seqid"

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
	if {$rem_flag != 0} {
		set res [compound {Putfh $ufh; Close $seqid $stateid; \
			Putfh $dfh; Remove $fname}]
                putmsg stdout 1 "compound {Putfh $ufh;"
                putmsg stdout 1 "\tClose $seqid $stateid;"
                putmsg stdout 1 "\tPutfh $dfh; Remove $fname}"
                putmsg stdout 1 "Res: $res"
                if {$status != "OK"} {
                        putmsg stdout 1 \
                                "unable to close/remove $fname ($status)."
                }
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
