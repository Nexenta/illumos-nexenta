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
# NFSv4 SETATTR operation test - positive tests
#	verify setattr to with different attrs and file types

# include all test enironment
source SETATTR.env

# connect to the test server
Connect

# setting local variables
set TNAME $argv0
set bfh [get_fh "$BASEDIRS"]

# Start testing
# --------------------------------------------------------------
# a: Setattr of a file w/supported-set'ble attrs, expect OK
set expcode "OK"
set ASSERTION "Setattr of a file w/none-size attrs, expect $expcode"
set tag "$TNAME{a}"
putmsg stdout 0 "$tag: $ASSERTION"
set newf "Sattr_Fa.[pid]"
set ffh [creatv4_file [file join $BASEDIR $newf]]
if { $ffh != $NULL } {
    # now the Setattr test, no change in size w/stateid=0:
    set stateid {0 0}
    set ntime "[clock seconds] 0"
    set attrl "{mode 123} {time_access_set {$ntime}} {time_modify_set 0}"
    set res [compound {Putfh $ffh; Setattr $stateid {$attrl}; 
	Getfh; Getattr {mode time_access type}}]
    set cont [ckres "Setattr" $status $expcode $res $FAIL]
    if {$cont == "true"} {
	set nattrs [lindex [lindex $res 3] 2]
	foreach al $nattrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      mode { if {"$val" != "123"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		putmsg stderr 0 "\t            expected=(mode=123)"
		set cont false
		break
	      } }
	      time_access { if {"$val" != "$ntime"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		putmsg stderr 0 "\t            expected=(time_access=$ntime)"
		set cont false
		break
	      } }
	      type { if {"$val" != "reg"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		putmsg stderr 0 "\t            expected=(type=reg)"
		set cont false
		break
	      } }
	      default {
		break
	      }
	    }
	}
    }
} else {
    putmsg stderr 0 "\t Test UNINITIATED: unable to create temp file."
    putmsg stderr 1 "\t   res=($res)"
    set cont "false"
}
# verify FH is not changed after successful Setattr op
  set fh1 [lindex [lindex $res 2] 2]
  fh_equal $fh1 $ffh $cont $PASS


# b: Setattr on a dir w/none-size attrs, expect OK
set expcode "OK"
set ASSERTION "Setattr of a dir w/none-size attrs, expect $expcode"
set tag "$TNAME{b}"
putmsg stdout 0 "$tag: $ASSERTION"
set newd "Sattr_Db.[pid]"
set stateid {0 0}
set ntime "[clock seconds] 0"
set ntime "[string replace $ntime 4 4 8]"
set attrl "{mode 751} {time_access_set {$ntime}}"
set res [compound {Putfh $bfh; Create $newd {{mode 0751}} d; Getfh;
	Setattr $stateid {$attrl}; Getfh; Getattr {mode time_access}}]
set cont [ckres "Setattr" $status $expcode $res $FAIL]
# verify attr returned have good value
  if {! [string equal $cont "false"]} {
  	set attrs [lindex [lindex $res 5] 2]
	foreach al $attrs {
	    set name [lindex $al 0]
	    set val [lindex $al 1]
	    switch -exact -- $name {
	      mode { if {"$val" != "751"} {
		putmsg stderr 0 "\t Test FAIL: attr($al) returned unexpected."
		putmsg stderr 0 "\t            expected=(mode=751)"
		set cont false
		break
	      } }
	      default {
		break
	      }
	    }
	}
  }
# verify FH is not changed after successful Setattr op
  set fh1 [lindex [lindex $res 2] 2]
  set fh2 [lindex [lindex $res 4] 2]
  fh_equal $fh1 $fh2 $cont $PASS


# c: Setattr on a symlink w/no changes in attrs, expect OK
set expcode "OK"
set ASSERTION "Setattr of a symlink w/no changes in attrs, expect $expcode"
set tag "$TNAME{c}"
putmsg stdout 0 "$tag: $ASSERTION"
set newl "Sattr_Lc.[pid]"
set res [compound {Putfh $bfh; Create $newl {{mode 0666}} l $newd; 
	Getfh; Getattr {mode time_modify}}]
set cont [ckres "Getattr" $status $expcode $res $FAIL]
# verify attr returned have good value
  if {! [string equal $cont "false"]} {
	set lfh [lindex [lindex $res 2] 2]
	set attrs [lindex [lindex $res 3] 2]
	# now set the same attributes, but change "time_modify" to set
	set md [lindex [lindex $attrs 0] 1]
	set nt [lindex [lindex $attrs 1] 1]
	set nat "{mode $md} {time_modify_set {$nt}}"
	set stateid {0 0}
	set res [compound {Putfh $lfh; Setattr $stateid {$nat};
		Getfh; Getattr {mode time_modify}}]
	set cont [ckres "Setattr" $status $expcode $res $FAIL]
  	if {! [string equal $cont "false"]} {
  	    set attrl [lindex [lindex $res 3] 2]
	    if {"$attrs" != "$attrl"} {
		putmsg stderr 0 "\t Test FAIL: attrs != attrl."
	    }
	}
  } else {
	set lfh ""
  }
# verify FH is not changed after successful Setattr op
  set fh2 [lindex [lindex $res 2] 2]
  fh_equal $lfh $fh2 $cont $PASS



# --------------------------------------------------------------
# Final cleanup
# cleanup remove the created file/dir
set res [compound {Putfh $bfh; Remove $newf; Remove $newd; Remove $newl}]
if { "$status" != "OK" } {
        putmsg stderr 0 "\t WARNING: cleanup to remove created dir failed"
        putmsg stderr 0 "\t          status=$status; please cleanup manually."
	putmsg stderr 1 "\t   res=($res)"
	putmsg stderr 1 "  "
	exit $WARNING
}

# disconnect and exit
Disconnect
exit $PASS
