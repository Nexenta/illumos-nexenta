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
# TCL procedure for WRITE operation testing

#---------------------------------------------------------
# Test procedure to Open and Write a file and check for wct and EOF flag.
#  Usage: ckwrite dfh fname off wct expcode expwct prn
# 	dfh:	 the directory filehandle where $fname located
# 	fname:	 the filename of the file to be Opened/Write
#	off:	 the offset to Write
#	wct:	 the count of bytes to Write
#	expcode: the expected status code from the Write op
#	expwct:  the expected length Write
#	prn:  	 the flag to print PASS/FAIL message
#
#  Return: 
#	0:  	Write success
#	-1: 	things failed during the process
#
proc ckwrite {dfh fname off wct expcode expwct {prn 0}} {
    global DEBUG OPEN4_RESULT_CONFIRM

    # Create the file for write
    set owner "[pid]-[expr int([expr [expr rand()] * 100000000])]"
    set clientid [getclientid $owner]
      putmsg stdout 2 "\ngetclientid $owner ..."
    set oseqid 1
    set otype 1
    if {$wct == 0} {set otype 0}
    set mode 0664
    set oclaim 0
    set res [compound {Putfh $dfh; 
        Open $oseqid 3 0 {$clientid $owner} \
        {$otype 0 {{mode $mode}}} {$oclaim $fname};
	Getfh; Getattr {mode}}]
      putmsg stdout 2 "\nOpen $fname ..."
      putmsg stdout 2 "Res: $res"
      if {$status != "OK"} {
	putmsg stderr 0 "\t Test UNRESOLVED: Open failed"
	putmsg stdout 0 "\t   Open ($fname) returned $status"
	putmsg stderr 0 "\t Res=($res)\n"
	return -1
      }
    set open_sid [lindex [lindex $res 1] 2]
    set rflags [lindex [lindex $res 1] 4] 
    set nfh [lindex [lindex $res 2] 2]
    set attr [lindex [lindex $res 3] 2]
    incr oseqid
    if {[expr $rflags & $OPEN4_RESULT_CONFIRM] == $OPEN4_RESULT_CONFIRM} {
	set res [compound {Putfh $nfh; Open_confirm "$open_sid" $oseqid}]
	  putmsg stdout 2 "\nOpen_confirm {$open_sid} $oseqid ..."
	  putmsg stdout 2 "Res: $res"
	if {$status != "OK"} {
	    putmsg stderr 0 "\t Test UNRESOLVED: Open_confirm failed"
	    putmsg stdout 0 "\t   Open_confirm returned $status"
	    putmsg stderr 0 "\t Res=($res)\n"
	    return -1
	}
	set open_sid [lindex [lindex $res 1] 2]
	incr oseqid
    }
    # Now write data to the file
    set data [string repeat "*" $wct]
    if {($wct == 0) || (($wct > 1) && ($wct < 32768))} {
        set wres [compound {Putfh $nfh; Write "$open_sid" $off f a $data}]
	set wstatus $status
      	  putmsg stdout 2 "\nWrite {$open_sid} $off $wct ..."
      	  putmsg stdout 2 "Res: $wres"
	# try to read back some data
        set rres [compound {Putfh $nfh; Read "$open_sid" $off $wct}]
	if {$status != "OK"} {
	    putmsg stderr 0 "\t Test FAIL: Read failed"
	    putmsg stdout 0 "\t   Read returned $status\n"
	    putmsg stderr 0 "\t Res=($res)\n"
	    return -1
	}
    } else {
        while {$off <= 1026 } {
            set wres [compound {Putfh $nfh; 
		Write "$open_sid" $off d a "B"}]
	    set wstatus $status
      	      putmsg stdout 2 "\nWrite {$open_sid} $off 1B ..."
      	      putmsg stdout 2 "Res: $wres"
	    set off [expr $off + $wct + 1] 
	}
    }
    set res [compound {Putfh $nfh; Commit 0 0; Close $oseqid $open_sid}]
      putmsg stdout 2 "\nClose $oseqid $open_sid ... "
      putmsg stdout 2 "Res: $res"

    # Now check for expected results
    if {$wstatus != $expcode} {
	putmsg stderr 0 \
		"\t Test FAIL: Write returned ($status), expected ($expcode)"
	putmsg stderr 1 "\t   res=($wres)"
	putmsg stderr 1 "  "
	return -1
    } else {
	set nwct [lindex [lindex [lindex $wres 1] 2] 0]
        if {($expwct != -1) && ($nwct != $expwct)} {
            putmsg stderr 0 \
	    "\t Test FAIL: Write returned wct=($nwct), expected=($expwct)"
	    putmsg stderr 1 "  "
            return -1
        } 
	if {$prn == 0} {
            putmsg stdout 0 "\t Test PASS"
	}
	return 0
    }
}
