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
# lcltools.tcl - procedures used for some tests (less general than
#			those in tclproc.tcl)


#--------------------------------------------------------------------
# ownid()
#	Create string for owner id information.
#	Returns the string with owner id, the tag send and last 5 digits
#		of the internal clock in seconds.
#

proc ownid {{tag ""}} {
	putmsg stdout 1 "\n"
	putmsg stdout 1 "ownid $tag"
	set ret "owner$tag[string range [clock clicks] end-5 end]"
	putmsg stdout 1 "returned $ret"
	return $ret
}

#--------------------------------------------------------------------
# grpid()
#	Create string for owner id information.
#	Returns the string with group id, the tag send and last 5 digits
#		of the internal clock in seconds.
#

proc grpid {{tag ""}} {
	putmsg stdout 1 "\n"
	putmsg stdout 1 "grpid $tag"
	set ret "group$tag[string range [clock clicks] end-5 end]"
	putmsg stdout 1 "returned $ret"
	return $ret
}

#--------------------------------------------------------------------
# openv4()
#	Wrap for open and open_confirm ops.
#	Returns the new filehandle if success, else NULL.
#

proc openv4 {filename Aclientid Astateid Aseqid {owner "one"}\
	{opentype 1} {Ares "DEADBEEF"}} {
	global NULL OPEN4_RESULT_CONFIRM DELM
	upvar 1 $Aclientid clientid
	upvar 1 $Astateid stateid
	upvar 1 $Aseqid oseqid
	set clientid ""
	if {$Ares != "DEADBEEF"} {
		upvar 1 $Ares res
	}
	append owner [clock clicks]
	putmsg stdout 1 "\n"
	putmsg stdout 1 "openv4 $filename $Aclientid $Astateid $Aseqid"
	putmsg stdout 1 "\t$owner $opentype $Ares"

	# pass status if exists as global
	if {[info vars ::status] != ""} {
		upvar 1 status status
	}

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	# convert pathname to list, store filename and path separated;
	set path [ path2comp $filename $DELM ]
	set filename [lindex $path end]
	set pathdir [lrange $path 0 end-1]
                                                                          
	putmsg stdout 1 "filename=$filename"
	putmsg stdout 1 "pathdir=$pathdir"

	# set clientid with server
	set verifier ""
	if {[setclient [clock clicks] $owner clientid verifier res] == "OK"} {
		if {[setclientconf $clientid $verifier res] != "OK"} {
			putmsg stdout 1 "cannot open temp file"
			return $NULL
		}
	}

        # XXX add catch here later
        set dfh [get_fh $pathdir]

	# create a seqid var if not exists to avoid test brakes
	if {[info vars oseqid] != ""} {
		set oseqid ""
		putmsg stdout 1 "WARNING: $Aseqid in caller did not exist."
		putmsg stdout 1 "\t$Aseqid created and initialized to 1"
	}
	# if oseqid uninitialized
	if {$oseqid == ""} {
		set oseqid 1
	}

	set oclaim 0
	set creat 0
	set res [compound {Putfh $dfh; Open $oseqid 3 0 {$clientid $owner} \
		{$opentype $creat {{mode 0777}}} {$oclaim $filename}; Getfh}]
	putmsg stdout 1 "compound {Putfh $dfh;"
	putmsg stdout 1 "\tOpen $oseqid 3 0 {$clientid $owner}{$opentype $creat"
	putmsg stdout 1 "\t{{mode 0777}}} {$oclaim $filename}; Getfh}"
	putmsg stdout 1 "Res: $res"
	if {$status != "OK"} {
		putmsg stdout 1 "Cannot open ($filename)."
		return $NULL
	}

	set stateid [lindex [lindex $res 1] 2]
	set rflags [lindex [lindex $res 1] 4] 
	set nfh [lindex [lindex $res 2] 2]
	putmsg stdout 1 "stateid = $stateid\nrflags = $rflags\nnfh = $nfh"

	# do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
		incr oseqid
		set res [compound {Putfh $nfh; Open_confirm $stateid $oseqid}]
		putmsg stdout 1 "compound {Putfh $nfh;"
		putmsg stdout 1 "Open_confirm $stateid $oseqid}"
		putmsg stdout 1 "Res: $res"
		if {$status != "OK"} {
			putmsg stdout 1 \
				"unable to open confirm file $filename."
			return $NULL
		}
		set stateid [lindex [lindex $res 1] 2]
	}
	incr oseqid
	putmsg stdout 1 "stateid = $stateid\nseqid = $oseqid"

	putmsg stdout 1 "return nfh = $nfh"
	return $nfh
}

#--------------------------------------------------------------------
# opencnftst()
#       Wrap for open op.
#       Returns the new filehandle if success, else NULL.
#

proc opencnftst {dfh filename clientid Astateid Aseqid Arflags {owner "SeT"}} {
	global NULL env
	upvar 1 $Astateid stateid
	upvar 1 $Aseqid oseqid
	upvar 1 $Arflags rflags
	if {$owner == "SeT"} {
		set owner "$env(USER)[clock clicks]"
	}
	putmsg stdout 1 "\n"
	putmsg stdout 1 "opencnftst $dfh $filename $clientid $Astateid"
	putmsg stdout 1 "\t$Aseqid $Arflags $owner"

	# pass status if exists as global
	if {[info vars ::status] != ""} {
		upvar 1 status status
	}

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	if {$oseqid == ""} {
		set oseqid 1
	}

	set oclaim 0
	set creat 0
	set opentype 1
	set res [compound {Putfh $dfh; Open $oseqid 3 0 {$clientid $owner} \
		{$opentype $creat {{mode 0777}}} {$oclaim $filename}; Getfh}]
	putmsg stdout 1 "compound {Putfh $dfh;"
	putmsg stdout 1 "\tOpen $oseqid 3 0 {$clientid $owner}"
	putmsg stdout 1 "\t{$opentype $creat {{mode 0777}}}"
	putmsg stdout 1 "\t{$oclaim $filename}; Getfh}"
	if {$status != "OK"} {
		putmsg stdout 1 "Cannot open ($filename)."
		putmsg stdout 1 "Res: $res"
		return $NULL
	}

	incr oseqid
	set stateid [lindex [lindex $res 1] 2]
	set rflags [lindex [lindex $res 1] 4] 
	set nfh [lindex [lindex $res 2] 2]
	putmsg stdout 1 "stateid = $stateid\nrflags = $rflags\nseqid = $oseqid"

	putmsg stdout 1 "return nfh = $nfh"
	return $nfh
}

#--------------------------------------------------------------------
# openconf4()
#       Wrap for open_confirm op.
#       Returns the status of the operation.
#

proc openconf4 {nfh rflags Astateid Aseqid {Ares "DEADBEEF"}} {
	global OPEN4_RESULT_CONFIRM
	upvar 1 $Astateid stateid
	upvar 1 $Aseqid oseqid
	if {$Ares != "DEADBEEF"} {
		upvar 1 $Ares res
	}
	set status "UNCONFIRMED"
	putmsg stdout 1 "\n"
	putmsg stdout 1 "openconf4 $nfh $rflags $Astateid $Aseqid $Ares"
	putmsg stdout 1 "status = $status"

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	# do open_confirm if needed, e.g. rflags has OPEN4_RESULT_CONFIRM set
#XXX check if this is what we want
#	if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
		if {$nfh == ""} {
			set res [compound {Open_confirm $stateid $oseqid}]
			putmsg stdout 1 \
				"compound {Open_confirm $stateid $oseqid}"
		} else {
			set res [compound {Putfh $nfh; \
				Open_confirm $stateid $oseqid}]
			putmsg stdout 1 "compound {Putfh $nfh;"
			putmsg stdout 1 "\tOpen_confirm $stateid $oseqid}"
		}
		if {$status != "OK"} {
			putmsg stdout 1 \
				"unable to open confirm file."
			putmsg stdout 1 "Res: $res"
			return $status
		} else {
			if {$nfh == ""} {
				set stateid [lindex 2]
			} else {
				set stateid [lindex [lindex $res 1] 2]
			}
		catch {incr oseqid}
		}
#	}
	putmsg stdout 1 "stateid = $stateid\nseqid = $oseqid"

	putmsg stdout 1 "return $status"
	return $status
}

#--------------------------------------------------------------------
# closev4()
#       Wrap for close op and removal of the file just closed.
#       Returns OK if success, else NULL.
#

proc closev4 {filename fh stateid seqid } {
	global NULL DELM
	putmsg stdout 1 "\n"
	putmsg stdout 1 "closev4 $filename $fh $stateid $seqid"

	# pass status if exists as global
	if {[info vars ::status] != ""} {
		upvar 1 status status
	}

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

        # convert pathname to list, store filename and path separated;
        set path [ path2comp $filename $DELM ]
        set filename [lindex $path end]
        set pathdir [lrange $path 0 end-1]
                                                                          
        putmsg stdout 1 "filename=$filename"
        putmsg stdout 1 "pathdir=$pathdir"

	set result "OK"

       # XXX add catch here later
        set dfh [get_fh $pathdir]
        set fh [get_fh "$pathdir $filename"]

	# close file
	set res [compound {Putfh $fh; Close $seqid $stateid}]
	putmsg stdout 1 "compound {Putfh $fh;\n\tClose $seqid $stateid}"
	putmsg stdout 1 "Res: $res"
	if {$status != "OK"} {
		putmsg stdout 1 "Can not close file $filename"
		putmsg stdout 1 "Status = $status"
		set result $NULL
	}

	# remove file
	set res [compound {Putfh $dfh; Remove $filename}]
	putmsg stdout 1 "compound {Putfh $dfh;\n\tRemove $filename}"
	putmsg stdout 1 "Res: $res"
	if {$status != "OK"} {
		putmsg stdout 1 "Can not remove file $filename"
		putmsg stdout 1 "Status = $status"
		set result  $NULL
	}

	putmsg stdout 1 "return $result"
	return $result
}

#--------------------------------------------------------------------
# closetst()
#       Wrap for close op.
#       Returns the status of the operation.
#

proc closetst {fh stateid seqid Ares} {
	global NULL DELM

	upvar 1 $Ares res
	putmsg stdout 1 "\n"
	putmsg stdout 1 "closetst $fh $stateid $seqid $Ares"

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

	# close file
	if {$fh == ""} {
		set res [compound {Close $seqid $stateid}]
		putmsg stdout 1 "compound{Close $seqid $stateid}"
	} else {
		set res [compound {Putfh $fh; Close $seqid $stateid}]
		putmsg stdout 1 "compound{Putfh $fh;\n\tClose $seqid $stateid}"
	}
	putmsg stdout 1 "Res: $res"
	if {$status != "OK"} {
		putmsg stdout 1 "Can not close file"
		return $status
	}

	putmsg stdout 1 "return $status"
	return $status
}

#--------------------------------------------------------------------
# removev4()
#       Wrap for remove op.
#       Returns OK if success, else NULL.
#

proc removev4 {filename} {
	global NULL DELM
	putmsg stdout 1 "\n"
	putmsg stdout 1 "removev4 $filename"

	# pass status if exists as global
	if {[info vars ::status] != ""} {
		upvar 1 status status
	}

	# pass tag if exists as global
	if {[info vars ::tag] != ""} {
		upvar 1 tag tag
	}

        # convert pathname to list, store filename and path separated;
        set path [ path2comp $filename $DELM ]
        set filename [lindex $path end]
        set pathdir [lrange $path 0 end-1]
	putmsg stdout 1 "filename = $filename"
	putmsg stdout 1 "pathdir = $pathdir"

        # XXX add catch here later
        set dfh [get_fh $pathdir]

	# remove file
	set res [compound {Putfh $dfh; Remove $filename}]
	putmsg stdout 1 "compound {Putfh $dfh;\n\tRemove $filename}"
	putmsg stdout 1 "Res: $res"
	if {$status != "OK"} {
		putmsg stdout 1 "Can not remove file $filename"
		return $NULL
	}

	putmsg stdout 1 "return $status"
	return $status
}

#--------------------------------------------------------------------
# uid_map()
#       Wrap for testing uid mapping assertions via setattr and
#		verifying with getattr op.
#       Returns PASS if success, else either FAIL or OTHER problem.
#		parameters Aown Aowngrp are set to final attrs of file
#

proc uid_map {ufh sid Aown Aowngrp Ares {Eown ""} {Egrp ""}} {
	# initialize attributes parameter
	upvar 1 $Aown own
	upvar 1 $Aowngrp owngrp
	upvar 1 $Ares res
	set status "UNRESOLVED"
	putmsg stdout 1 "\n"
	putmsg stdout 1 "uid_map $ufh $sid $Aown $Aowngrp $Ares $Eown $Egrp"
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
	# get original values to verify on Setattr failure
	set sto [catch {compound {Putfh $ufh; Getattr $attrs}} reso]
	putmsg stdout 1 "compound{Putfh $ufh;\n\tGetattr $attrs}"
	putmsg stdout 1 "res: <$reso>"
	if {$status != "OK"} {
		putmsg stdout 0 "\twarning: first Getattr failed ($status)."
		putmsg stdout 1 "return status=$status"
		putmsg stdout 1 "catch result = $sto"
	} else {
		set rattrs [lindex [lindex $reso 1] 2]
		putmsg stdout 1 "returned attrs = $rattrs"
		foreach attr $rattrs {
			set name [ lindex $attr 0]
			set val  [ lindex $attr 1]
	
			switch $name {
				owner	{ 
					set orig_owner $val
				}
				owner_group	{
					set orig_owner_group $val
				}
				default	{}
			}
		}
	putmsg stdout 1 "owner = $orig_owner\nowner_group = $orig_owner_group"
	}

	set Sstatus "OK"
	# Generate a compound request to change the attributes
	set st [catch {compound {Putfh $ufh; Setattr $sid {$attrib}}} res]
	#set res [compound {Putfh $ufh; Setattr $sid {$attrib}}]
	putmsg stdout 1 "compound{Putfh $ufh;\n\tSetattr $sid $attrib}"
	putmsg stdout 1 "res: <$res>"
	if {$status != "OK"} {
		putmsg stdout 1 "setattr return status=$status"
		putmsg stdout 1 "catch result = $st"
		set Sstatus $status
		# now expected values are original values for the file
		set Eown $orig_owner
		set Egrp $orig_owner_group
	}

	#verify the change in attribute
	set st2 [catch {compound {Putfh $ufh; Getattr $attrs}} res2]
	putmsg stdout 1 "compound{Putfh $ufh;\n\tGetattr $attrs}"
	putmsg stdout 1 "res: <$res2>"
	if {$status != "OK"} {
		putmsg stdout 0 "\twarning: second Getattr failed ($status)."
		putmsg stdout 1 "return status=$status"
		putmsg stdout 1 "catch result = $st2"
		return $Sstatus
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
		set owngrp $owner_group
		set Cstatus "${Cstatus}GroupMismatch"
	}

	# Setattr status (failure condition) has highest priority
	set status $Sstatus
	# comparisons second
	if {$status == "OK" && $Cstatus != ""} {
		set status $Cstatus
	}

	putmsg stdout 1 "return $status"
	return $status
}

#--------------------------------------------------------------------
# ckfilev4()
#       Wrap for testing results of assertions and handling logs.
#       Returns true or false.
#

proc ckfilev4 {op status {prn 0}} {
	global DEBUG NULL
	putmsg stdout 1 "\n"
	putmsg stderr 1 "ckfilev4 $op $status $prn"

	if {$status == $NULL} {
		putmsg stdout 0 "\t Test FAIL: $op"
		return false
	} else {
		if {$prn == 0} {
 			putmsg stdout 0 "\t Test PASS"
		}
		return true
	}
}

#--------------------------------------------------------------------
# env2path()
#       Build complete file name based on env var and optional path.
#	Default path is $BASEDIR.
#       Returns true or false.
#

proc env2path {envvar {path "default"}} {
	global env BASEDIR DELM

	if {$path == "default"} {
		set path $BASEDIR
	}
	putmsg stdout 1 "\n"
	putmsg stdout 1 "env2path $envvar $path"

	set name [file join $path $env($envvar)]
	set path [ path2comp $name $DELM ]

	putmsg stdout 1 "return $path"
	return $path
}

#--------------------------------------------------------------------
# getfileowner()
#       Get owner and owner_group attributes for a file
#       Returns the file's owner and owner_group on success, otherwise
#	it returns null.

proc getfileowner {fh} {
	set attrs "owner owner_group"
	set status "UNRESOLVED"
	
	set st [catch {compound {Putfh $fh; Getattr $attrs}} res] 
	if {$st != 0} {
		# syntax error
		putmsg stderr 0 "\terror: compound proc failed"
		putmsg stderr 0 "error code: $st"
		putmsg stderr 0 "error message: $res"
	} elseif {$status != "OK"} {
		# request failed
		putmsg stderr 0 "\twarning: Getattr failed($status)."
	} else {
		# parse the result
		set rattrs [lindex [lindex $res 1] 2]
		putmsg stdout 1 "returned attrs = $rattrs"
		foreach attr $rattrs {
			set name [lindex $attr 0]
			set val [lindex $attr 1]
			switch $name {
				owner {
					set owner $val
				}
				owner_group {
					set owner_group $val
				}
				default {}
			}
		}
		return "$owner $owner_group"
	}
}
